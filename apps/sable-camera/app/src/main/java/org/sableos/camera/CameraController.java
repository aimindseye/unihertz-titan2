package org.sableos.camera;

import android.app.Activity;
import android.graphics.ImageFormat;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.MeteringRectangle;
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
    private CaptureRequest.Builder previewRequestBuilder;

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
    private MeteringRectangle[] focusAfRegions;
    private MeteringRectangle[] focusAeRegions;

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

    void focusAt(float viewX, float viewY) {
        Handler handler = cameraHandler;
        if (handler != null) {
            handler.post(() -> focusAtInternal(viewX, viewY));
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

            previewRequestBuilder = request;
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
            Uri uri = CaptureStore.saveDng(
                    activity,
                    characteristics,
                    result,
                    image,
                    jpegOrientation()
            );
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

        if (focusAfRegions != null) {
            Integer maxAf = characteristics.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF);
            if (maxAf != null && maxAf > 0) {
                request.set(CaptureRequest.CONTROL_AF_REGIONS, focusAfRegions);
            }
        }

        if (focusAeRegions != null) {
            Integer maxAe = characteristics.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE);
            if (maxAe != null && maxAe > 0) {
                request.set(CaptureRequest.CONTROL_AE_REGIONS, focusAeRegions);
            }
        }

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

        int deviceDegrees = displayDegrees();

        if (lensFacing != null
                && lensFacing == CameraCharacteristics.LENS_FACING_FRONT) {
            return (sensor + deviceDegrees + 360) % 360;
        }

        return (sensor - deviceDegrees + 360) % 360;
    }

    private int displayDegrees() {
        int rotation = textureView.getDisplay() == null
                ? Surface.ROTATION_0
                : textureView.getDisplay().getRotation();

        return switch (rotation) {
            case Surface.ROTATION_90 -> 90;
            case Surface.ROTATION_180 -> 180;
            case Surface.ROTATION_270 -> 270;
            default -> 0;
        };
    }

    private int relativeSensorRotation() {
        Integer sensor = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
        Integer lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING);
        if (sensor == null) {
            sensor = 0;
        }

        int display = displayDegrees();
        if (lensFacing != null
                && lensFacing == CameraCharacteristics.LENS_FACING_FRONT) {
            return (sensor + display + 360) % 360;
        }
        return (sensor - display + 360) % 360;
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

            int relativeRotation = relativeSensorRotation();
            boolean swapped = relativeRotation == 90 || relativeRotation == 270;

            if (textureView instanceof AutoFitTextureView autoFit) {
                if (swapped) {
                    autoFit.setAspectRatio(
                            previewSize.getHeight(),
                            previewSize.getWidth()
                    );
                } else {
                    autoFit.setAspectRatio(
                            previewSize.getWidth(),
                            previewSize.getHeight()
                    );
                }
            }

            int displayRotation = textureView.getDisplay() == null
                    ? Surface.ROTATION_0
                    : textureView.getDisplay().getRotation();

            Matrix matrix = new Matrix();
            RectF viewRect = new RectF(0, 0, viewWidth, viewHeight);
            float centerX = viewRect.centerX();
            float centerY = viewRect.centerY();

            if (displayRotation == Surface.ROTATION_90
                    || displayRotation == Surface.ROTATION_270) {
                RectF bufferRect = new RectF(
                        0,
                        0,
                        previewSize.getHeight(),
                        previewSize.getWidth()
                );
                bufferRect.offset(
                        centerX - bufferRect.centerX(),
                        centerY - bufferRect.centerY()
                );
                matrix.setRectToRect(
                        viewRect,
                        bufferRect,
                        Matrix.ScaleToFit.FILL
                );

                float scale = Math.max(
                        (float) viewHeight / previewSize.getHeight(),
                        (float) viewWidth / previewSize.getWidth()
                );
                matrix.postScale(scale, scale, centerX, centerY);
                matrix.postRotate(
                        90f * (displayRotation - 2),
                        centerX,
                        centerY
                );
            } else if (displayRotation == Surface.ROTATION_180) {
                matrix.postRotate(180f, centerX, centerY);
            }

            Integer lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING);
            if (lensFacing != null
                    && lensFacing == CameraCharacteristics.LENS_FACING_FRONT) {
                matrix.postScale(-1f, 1f, centerX, centerY);
            }

            textureView.setTransform(matrix);
        });
    }

    private void focusAtInternal(float viewX, float viewY) {
        if (captureSession == null
                || previewRequestBuilder == null
                || characteristics == null
                || previewSize == null) {
            status("Camera is not ready to focus.");
            return;
        }

        Integer maxAf = characteristics.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF);
        Integer maxAe = characteristics.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE);

        boolean supportsAfRegion = maxAf != null && maxAf > 0;
        boolean supportsAeRegion = maxAe != null && maxAe > 0;

        if (!supportsAfRegion && !supportsAeRegion) {
            status("Tap metering regions are not supported on this camera.");
            return;
        }

        Rect active = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE);
        if (active == null) {
            status("Sensor active array unavailable.");
            return;
        }

        Matrix inverse = new Matrix();
        Matrix transform = new Matrix();
        textureView.getTransform(transform);

        if (!transform.invert(inverse)) {
            status("Unable to map focus point.");
            return;
        }

        float[] point = new float[] { viewX, viewY };
        inverse.mapPoints(point);

        float nx = clamp(point[0] / Math.max(1f, textureView.getWidth()), 0f, 1f);
        float ny = clamp(point[1] / Math.max(1f, textureView.getHeight()), 0f, 1f);

        int sensorX = active.left + Math.round(nx * active.width());
        int sensorY = active.top + Math.round(ny * active.height());

        int regionWidth = Math.max(64, active.width() / 8);
        int regionHeight = Math.max(64, active.height() / 8);

        int left = clampInt(
                sensorX - regionWidth / 2,
                active.left,
                active.right - regionWidth
        );
        int top = clampInt(
                sensorY - regionHeight / 2,
                active.top,
                active.bottom - regionHeight
        );

        MeteringRectangle region = new MeteringRectangle(
                left,
                top,
                regionWidth,
                regionHeight,
                MeteringRectangle.METERING_WEIGHT_MAX
        );

        focusAfRegions = supportsAfRegion
                ? new MeteringRectangle[] { region }
                : null;
        focusAeRegions = supportsAeRegion
                ? new MeteringRectangle[] { region }
                : null;

        try {
            if (supportsAfRegion) {
                previewRequestBuilder.set(
                        CaptureRequest.CONTROL_AF_REGIONS,
                        focusAfRegions
                );
                previewRequestBuilder.set(
                        CaptureRequest.CONTROL_AF_MODE,
                        CaptureRequest.CONTROL_AF_MODE_AUTO
                );
                previewRequestBuilder.set(
                        CaptureRequest.CONTROL_AF_TRIGGER,
                        CaptureRequest.CONTROL_AF_TRIGGER_CANCEL
                );
                captureSession.capture(
                        previewRequestBuilder.build(),
                        null,
                        cameraHandler
                );

                previewRequestBuilder.set(
                        CaptureRequest.CONTROL_AF_TRIGGER,
                        CaptureRequest.CONTROL_AF_TRIGGER_START
                );
            }

            if (supportsAeRegion) {
                previewRequestBuilder.set(
                        CaptureRequest.CONTROL_AE_REGIONS,
                        focusAeRegions
                );
                previewRequestBuilder.set(
                        CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER,
                        CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER_START
                );
            }

            status("Focusing…");

            captureSession.capture(
                    previewRequestBuilder.build(),
                    new CameraCaptureSession.CaptureCallback() {
                        @Override
                        public void onCaptureCompleted(
                                CameraCaptureSession session,
                                CaptureRequest request,
                                TotalCaptureResult result
                        ) {
                            Integer afState = result.get(CaptureResult.CONTROL_AF_STATE);
                            restorePreviewAfterFocus();
                            if (afState != null
                                    && afState == CaptureResult.CONTROL_AF_STATE_FOCUSED_LOCKED) {
                                status("Focus locked.");
                            } else if (afState != null
                                    && afState == CaptureResult.CONTROL_AF_STATE_NOT_FOCUSED_LOCKED) {
                                status("Focus completed; lock not achieved.");
                            } else {
                                status("Focus point applied.");
                            }
                        }
                    },
                    cameraHandler
            );
        } catch (CameraAccessException e) {
            status("Tap focus failed: " + e.getMessage());
        }
    }

    private void restorePreviewAfterFocus() {
        if (captureSession == null || previewRequestBuilder == null) {
            return;
        }

        try {
            previewRequestBuilder.set(
                    CaptureRequest.CONTROL_AF_TRIGGER,
                    CaptureRequest.CONTROL_AF_TRIGGER_IDLE
            );
            previewRequestBuilder.set(
                    CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER,
                    CaptureRequest.CONTROL_AE_PRECAPTURE_TRIGGER_IDLE
            );

            int[] modes =
                    characteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
            if (contains(modes, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)) {
                previewRequestBuilder.set(
                        CaptureRequest.CONTROL_AF_MODE,
                        CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                );
            }

            captureSession.setRepeatingRequest(
                    previewRequestBuilder.build(),
                    null,
                    cameraHandler
            );
        } catch (CameraAccessException e) {
            status("Preview resume after focus failed: " + e.getMessage());
        }
    }

    private static boolean contains(int[] values, int wanted) {
        if (values == null) {
            return false;
        }
        for (int value : values) {
            if (value == wanted) {
                return true;
            }
        }
        return false;
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }

    private static int clampInt(int value, int min, int max) {
        if (max < min) {
            return min;
        }
        return Math.max(min, Math.min(max, value));
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
        previewRequestBuilder = null;
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
        focusAfRegions = null;
        focusAeRegions = null;
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
