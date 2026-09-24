package org.sableos.camera;

import android.app.Activity;
import android.graphics.ImageFormat;
import android.graphics.Matrix;
import android.graphics.RectF;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.net.Uri;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Size;
import android.view.Surface;
import android.view.TextureView;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;

final class CameraController implements TextureView.SurfaceTextureListener {
    interface Listener {
        void onStatus(String message);
        void onState(UiState state);
        void onSaved(Uri uri, String description);
    }

    record UiState(
            String cameraId,
            String facing,
            String format,
            String resolution,
            boolean highResolution,
            boolean rawMode,
            boolean rawAvailable
    ) {}

    private final Activity activity;
    private final TextureView textureView;
    private final Listener listener;
    private final CameraManager manager;

    private HandlerThread cameraThread;
    private Handler cameraHandler;

    private CameraDevice cameraDevice;
    private CameraCaptureSession captureSession;
    private ImageReader imageReader;
    private Surface previewSurface;

    private CameraCharacteristics characteristics;
    private Size previewSize;
    private Size captureSize;
    private String cameraId;

    private boolean front;
    private boolean highResolution;
    private boolean rawMode;
    private boolean rawAvailable;

    private Image pendingRawImage;
    private TotalCaptureResult pendingRawResult;

    CameraController(
            Activity activity,
            TextureView textureView,
            Listener listener
    ) {
        this.activity = activity;
        this.textureView = textureView;
        this.listener = listener;
        this.manager = activity.getSystemService(CameraManager.class);
        if (manager == null) {
            throw new IllegalStateException("CameraManager unavailable");
        }
        textureView.setSurfaceTextureListener(this);
    }

    void start() {
        if (cameraThread != null) {
            return;
        }

        cameraThread = new HandlerThread("sable-camera");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());

        if (textureView.isAvailable()) {
            cameraHandler.post(this::openCurrentCamera);
        }
    }

    void stop() {
        closeCamera();

        HandlerThread thread = cameraThread;
        cameraThread = null;
        cameraHandler = null;

        if (thread != null) {
            thread.quitSafely();
        }
    }

    void toggleFacing() {
        front = !front;
        rawMode = false;
        postReopen();
    }

    void toggleResolution() {
        highResolution = !highResolution;
        postReconfigure();
    }

    void toggleRaw() {
        if (!rawAvailable) {
            status("RAW is not available on this camera.");
            return;
        }
        rawMode = !rawMode;
        postReconfigure();
    }

    void capture() {
        Handler handler = cameraHandler;
        if (handler != null) {
            handler.post(this::captureInternal);
        }
    }

    private void postReopen() {
        Handler handler = cameraHandler;
        if (handler != null) {
            handler.post(() -> {
                closeCamera();
                openCurrentCamera();
            });
        }
    }

    private void postReconfigure() {
        Handler handler = cameraHandler;
        if (handler != null) {
            handler.post(() -> {
                if (cameraDevice == null || characteristics == null) {
                    return;
                }
                configureSizes();
                createSession();
            });
        }
    }

    private void openCurrentCamera() {
        try {
            cameraId = findCameraId(
                    front
                            ? CameraCharacteristics.LENS_FACING_FRONT
                            : CameraCharacteristics.LENS_FACING_BACK
            );

            if (cameraId == null) {
                status(front ? "No front camera is visible." : "No rear camera is visible.");
                return;
            }

            characteristics = manager.getCameraCharacteristics(cameraId);
            rawAvailable = hasRawCapability(characteristics);
            if (!rawAvailable) {
                rawMode = false;
            }

            configureSizes();
            configureTransform();

            status("Opening camera " + cameraId + "…");

            manager.openCamera(
                    cameraId,
                    new CameraDevice.StateCallback() {
                        @Override
                        public void onOpened(CameraDevice camera) {
                            cameraDevice = camera;
                            createSession();
                        }

                        @Override
                        public void onDisconnected(CameraDevice camera) {
                            camera.close();
                            if (cameraDevice == camera) {
                                cameraDevice = null;
                            }
                            status("Camera disconnected.");
                        }

                        @Override
                        public void onError(CameraDevice camera, int error) {
                            camera.close();
                            if (cameraDevice == camera) {
                                cameraDevice = null;
                            }
                            status("Camera error " + error + ".");
                        }
                    },
                    cameraHandler
            );
        } catch (SecurityException e) {
            status("Camera permission denied.");
        } catch (CameraAccessException e) {
            status("Camera access failed: " + e.getMessage());
        } catch (RuntimeException e) {
            status("Camera setup failed: " + e.getMessage());
        }
    }

    private String findCameraId(int lensFacing) throws CameraAccessException {
        for (String id : manager.getCameraIdList()) {
            CameraCharacteristics c = manager.getCameraCharacteristics(id);
            Integer facingValue = c.get(CameraCharacteristics.LENS_FACING);
            if (facingValue != null && facingValue == lensFacing) {
                return id;
            }
        }
        return null;
    }

    private void configureSizes() {
        StreamConfigurationMap map =
                characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);

        if (map == null) {
            throw new IllegalStateException("Stream configuration map unavailable");
        }

        if (rawMode) {
            Size[] rawSizes = map.getOutputSizes(ImageFormat.RAW_SENSOR);
            if (rawSizes == null || rawSizes.length == 0) {
                throw new IllegalStateException("RAW_SENSOR size unavailable");
            }
            captureSize = largest(rawSizes);
        } else {
            Size[] jpegSizes = map.getOutputSizes(ImageFormat.JPEG);
            if (jpegSizes == null || jpegSizes.length == 0) {
                throw new IllegalStateException("JPEG size unavailable");
            }

            captureSize = highResolution
                    ? largest(jpegSizes)
                    : conventionalFourThree(jpegSizes);
        }

        Size[] previewSizes = map.getOutputSizes(SurfaceTexture.class);
        if (previewSizes == null || previewSizes.length == 0) {
            throw new IllegalStateException("Preview size unavailable");
        }
        previewSize = choosePreviewSize(previewSizes, captureSize);
    }

    private void createSession() {
        CameraDevice device = cameraDevice;
        if (device == null || !textureView.isAvailable()) {
            return;
        }

        closeSessionOnly();

        try {
            SurfaceTexture texture = textureView.getSurfaceTexture();
            if (texture == null) {
                status("Preview surface unavailable.");
                return;
            }

            texture.setDefaultBufferSize(previewSize.getWidth(), previewSize.getHeight());
            previewSurface = new Surface(texture);

            int format = rawMode ? ImageFormat.RAW_SENSOR : ImageFormat.JPEG;
            imageReader = ImageReader.newInstance(
                    captureSize.getWidth(),
                    captureSize.getHeight(),
                    format,
                    2
            );

            if (rawMode) {
                imageReader.setOnImageAvailableListener(this::onRawImage, cameraHandler);
            } else {
                imageReader.setOnImageAvailableListener(this::onJpegImage, cameraHandler);
            }

            List<Surface> surfaces = new ArrayList<>();
            surfaces.add(previewSurface);
            surfaces.add(imageReader.getSurface());

            device.createCaptureSession(
                    surfaces,
                    new CameraCaptureSession.StateCallback() {
                        @Override
                        public void onConfigured(CameraCaptureSession session) {
                            if (cameraDevice == null) {
                                session.close();
                                return;
                            }
                            captureSession = session;
                            startRepeatingPreview();
                        }

                        @Override
                        public void onConfigureFailed(CameraCaptureSession session) {
                            session.close();
                            status(
                                    "Session configuration failed for " +
                                            modeDescription() + "."
                            );
                        }
                    },
                    cameraHandler
            );

            configureTransform();
        } catch (CameraAccessException | RuntimeException e) {
            status("Session setup failed: " + e.getMessage());
        }
    }

    private void startRepeatingPreview() {
        if (cameraDevice == null || captureSession == null || previewSurface == null) {
            return;
        }

        try {
            CaptureRequest.Builder request =
                    cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            request.addTarget(previewSurface);
            applyAutoControls(request);

            captureSession.setRepeatingRequest(request.build(), null, cameraHandler);
            publishState();
            status("Ready — " + modeDescription());
        } catch (CameraAccessException e) {
            status("Preview failed: " + e.getMessage());
        }
    }

    private void captureInternal() {
        if (cameraDevice == null || captureSession == null || imageReader == null) {
            status("Camera is not ready.");
            return;
        }

        status("Capturing " + modeDescription() + "…");

        if (rawMode) {
            captureRaw();
        } else {
            captureJpeg();
        }
    }

    private void captureJpeg() {
        try {
            CaptureRequest.Builder request =
                    cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);
            request.addTarget(imageReader.getSurface());
            applyAutoControls(request);
            request.set(CaptureRequest.JPEG_QUALITY, (byte) 95);
            request.set(CaptureRequest.JPEG_ORIENTATION, jpegOrientation());

            captureSession.capture(
                    request.build(),
                    new CameraCaptureSession.CaptureCallback() {
                        @Override
                        public void onCaptureFailed(
                                CameraCaptureSession session,
                                CaptureRequest request,
                                android.hardware.camera2.CaptureFailure failure
                        ) {
                            status("JPEG capture failed: reason=" + failure.getReason());
                        }
                    },
                    cameraHandler
            );
        } catch (CameraAccessException e) {
            status("JPEG capture failed: " + e.getMessage());
        }
    }

    private void captureRaw() {
        pendingRawResult = null;
        if (pendingRawImage != null) {
            pendingRawImage.close();
            pendingRawImage = null;
        }

        try {
            CaptureRequest.Builder request =
                    cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);
            request.addTarget(imageReader.getSurface());
            applyAutoControls(request);

            captureSession.capture(
                    request.build(),
                    new CameraCaptureSession.CaptureCallback() {
                        @Override
                        public void onCaptureCompleted(
                                CameraCaptureSession session,
                                CaptureRequest request,
                                TotalCaptureResult result
                        ) {
                            pendingRawResult = result;
                            maybeSaveRaw();
                        }

                        @Override
                        public void onCaptureFailed(
                                CameraCaptureSession session,
                                CaptureRequest request,
                                android.hardware.camera2.CaptureFailure failure
                        ) {
                            status("RAW capture failed: reason=" + failure.getReason());
                        }
                    },
                    cameraHandler
            );
        } catch (CameraAccessException e) {
            status("RAW capture failed: " + e.getMessage());
        }
    }

    private void onJpegImage(ImageReader reader) {
        try (Image image = reader.acquireNextImage()) {
            if (image == null) {
                return;
            }

            ByteBuffer buffer = image.getPlanes()[0].getBuffer();
            byte[] jpeg = new byte[buffer.remaining()];
            buffer.get(jpeg);

            Uri uri = CaptureStore.saveJpeg(activity, jpeg);
            saved(uri, captureSize.getWidth() + "×" + captureSize.getHeight() + " JPEG");
        } catch (Exception e) {
            status("JPEG save failed: " + e.getMessage());
        }
    }

    private void onRawImage(ImageReader reader) {
        try {
            Image image = reader.acquireNextImage();
            if (image == null) {
                return;
            }

            if (pendingRawImage != null) {
                pendingRawImage.close();
            }
            pendingRawImage = image;
            maybeSaveRaw();
        } catch (RuntimeException e) {
            status("RAW image failed: " + e.getMessage());
        }
    }

    private void maybeSaveRaw() {
        if (pendingRawImage == null || pendingRawResult == null || characteristics == null) {
            return;
        }

        Image image = pendingRawImage;
        TotalCaptureResult result = pendingRawResult;
        pendingRawImage = null;
        pendingRawResult = null;

        try {
            Uri uri = CaptureStore.saveDng(activity, characteristics, result, image);
            saved(uri, captureSize.getWidth() + "×" + captureSize.getHeight() + " DNG");
        } catch (Exception e) {
            status("DNG save failed: " + e.getMessage());
        } finally {
            image.close();
        }
    }

    private void applyAutoControls(CaptureRequest.Builder request) {
        request.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);
        request.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);

        int[] modes = characteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
        if (modes == null) {
            return;
        }

        for (int mode : modes) {
            if (mode == CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE) {
                request.set(
                        CaptureRequest.CONTROL_AF_MODE,
                        CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                );
                return;
            }
        }

        for (int mode : modes) {
            if (mode == CaptureRequest.CONTROL_AF_MODE_AUTO) {
                request.set(
                        CaptureRequest.CONTROL_AF_MODE,
                        CaptureRequest.CONTROL_AF_MODE_AUTO
                );
                return;
            }
        }
    }

    private int jpegOrientation() {
        Integer sensor = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
        Integer lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING);
        if (sensor == null) {
            sensor = 0;
        }

        int rotation = textureView.getDisplay() == null
                ? Surface.ROTATION_0
                : textureView.getDisplay().getRotation();

        int deviceDegrees = switch (rotation) {
            case Surface.ROTATION_90 -> 90;
            case Surface.ROTATION_180 -> 180;
            case Surface.ROTATION_270 -> 270;
            default -> 0;
        };

        if (lensFacing != null && lensFacing == CameraCharacteristics.LENS_FACING_FRONT) {
            deviceDegrees = -deviceDegrees;
        }

        return (sensor + deviceDegrees + 360) % 360;
    }

    private void configureTransform() {
        if (previewSize == null || characteristics == null) {
            return;
        }

        activity.runOnUiThread(() -> {
            int viewWidth = textureView.getWidth();
            int viewHeight = textureView.getHeight();
            if (viewWidth == 0 || viewHeight == 0) {
                return;
            }

            Integer sensor = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
            Integer lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING);
            if (sensor == null) {
                sensor = 0;
            }

            int displayRotation = textureView.getDisplay() == null
                    ? Surface.ROTATION_0
                    : textureView.getDisplay().getRotation();

            int displayDegrees = switch (displayRotation) {
                case Surface.ROTATION_90 -> 90;
                case Surface.ROTATION_180 -> 180;
                case Surface.ROTATION_270 -> 270;
                default -> 0;
            };

            int relativeRotation;
            if (lensFacing != null
                    && lensFacing == CameraCharacteristics.LENS_FACING_FRONT) {
                relativeRotation = (sensor + displayDegrees) % 360;
            } else {
                relativeRotation = (sensor - displayDegrees + 360) % 360;
            }

            float bufferWidth = previewSize.getWidth();
            float bufferHeight = previewSize.getHeight();
            float rotatedWidth =
                    (relativeRotation == 90 || relativeRotation == 270)
                            ? bufferHeight
                            : bufferWidth;
            float rotatedHeight =
                    (relativeRotation == 90 || relativeRotation == 270)
                            ? bufferWidth
                            : bufferHeight;

            float scale = Math.max(
                    viewWidth / rotatedWidth,
                    viewHeight / rotatedHeight
            );

            Matrix matrix = new Matrix();
            matrix.postTranslate(-bufferWidth / 2f, -bufferHeight / 2f);
            matrix.postRotate(relativeRotation);
            matrix.postScale(scale, scale);
            matrix.postTranslate(viewWidth / 2f, viewHeight / 2f);

            if (lensFacing != null
                    && lensFacing == CameraCharacteristics.LENS_FACING_FRONT) {
                matrix.postScale(-1f, 1f, viewWidth / 2f, viewHeight / 2f);
            }

            textureView.setTransform(matrix);
        });
    }

    private void publishState() {
        String facingName = front ? "Front" : "Rear";
        String format = rawMode ? "RAW" : "JPEG";
        String resolution =
                captureSize.getWidth() + "×" + captureSize.getHeight();

        activity.runOnUiThread(
                () -> listener.onState(
                        new UiState(
                                cameraId,
                                facingName,
                                format,
                                resolution,
                                highResolution,
                                rawMode,
                                rawAvailable
                        )
                )
        );
    }

    private String modeDescription() {
        if (captureSize == null) {
            return rawMode ? "RAW" : "JPEG";
        }
        return (front ? "Front " : "Rear ")
                + (rawMode ? "RAW " : (highResolution ? "High JPEG " : "Normal JPEG "))
                + captureSize.getWidth() + "×" + captureSize.getHeight();
    }

    private void saved(Uri uri, String description) {
        activity.runOnUiThread(() -> listener.onSaved(uri, description));
        status("Saved " + description);
    }

    private void status(String message) {
        activity.runOnUiThread(() -> listener.onStatus(message));
    }

    private void closeSessionOnly() {
        if (captureSession != null) {
            captureSession.close();
            captureSession = null;
        }
        if (imageReader != null) {
            imageReader.close();
            imageReader = null;
        }
        if (previewSurface != null) {
            previewSurface.release();
            previewSurface = null;
        }
        if (pendingRawImage != null) {
            pendingRawImage.close();
            pendingRawImage = null;
        }
        pendingRawResult = null;
    }

    private void closeCamera() {
        closeSessionOnly();
        if (cameraDevice != null) {
            cameraDevice.close();
            cameraDevice = null;
        }
    }

    private static boolean hasRawCapability(CameraCharacteristics c) {
        int[] caps = c.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES);
        if (caps == null) {
            return false;
        }
        for (int cap : caps) {
            if (cap == CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_RAW) {
                return true;
            }
        }
        return false;
    }

    private static Size largest(Size[] sizes) {
        return Arrays.stream(sizes)
                .max(Comparator.comparingLong(CameraController::area))
                .orElseThrow();
    }

    private static Size conventionalFourThree(Size[] sizes) {
        final double target = 4.0 / 3.0;

        Size best = Arrays.stream(sizes)
                .filter(s -> s.getWidth() <= 4096 && s.getHeight() <= 3072)
                .filter(s -> Math.abs(
                        ((double) s.getWidth() / (double) s.getHeight()) - target
                ) < 0.02)
                .max(Comparator.comparingLong(CameraController::area))
                .orElse(null);

        if (best != null) {
            return best;
        }

        return Arrays.stream(sizes)
                .filter(s -> s.getWidth() <= 4096 && s.getHeight() <= 3072)
                .max(Comparator.comparingLong(CameraController::area))
                .orElseGet(() -> largest(sizes));
    }

    private static Size choosePreviewSize(Size[] sizes, Size capture) {
        double target = (double) capture.getWidth() / (double) capture.getHeight();

        Size best = Arrays.stream(sizes)
                .filter(s -> s.getWidth() <= 1920 && s.getHeight() <= 1440)
                .filter(s -> Math.abs(
                        ((double) s.getWidth() / (double) s.getHeight()) - target
                ) < 0.05)
                .max(Comparator.comparingLong(CameraController::area))
                .orElse(null);

        if (best != null) {
            return best;
        }

        best = Arrays.stream(sizes)
                .filter(s -> s.getWidth() <= 1920 && s.getHeight() <= 1440)
                .max(Comparator.comparingLong(CameraController::area))
                .orElse(null);

        return best != null ? best : largest(sizes);
    }

    private static long area(Size size) {
        return (long) size.getWidth() * size.getHeight();
    }

    @Override
    public void onSurfaceTextureAvailable(
            SurfaceTexture surface,
            int width,
            int height
    ) {
        Handler handler = cameraHandler;
        if (handler != null) {
            handler.post(this::openCurrentCamera);
        }
    }

    @Override
    public void onSurfaceTextureSizeChanged(
            SurfaceTexture surface,
            int width,
            int height
    ) {
        configureTransform();
    }

    @Override
    public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
        closeCamera();
        return true;
    }

    @Override
    public void onSurfaceTextureUpdated(SurfaceTexture surface) {
    }
}
