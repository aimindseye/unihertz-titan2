package org.sableos.research.cameraprobe;

import android.content.Context;
import android.graphics.ImageFormat;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.media.Image;
import android.media.ImageReader;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Size;
import android.view.Surface;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.TimeZone;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

final class StillCaptureTester {
    record Result(JSONObject report, File latestFile) {}

    private static final long OPEN_TIMEOUT_MS = 5000;
    private static final long SESSION_TIMEOUT_MS = 5000;
    private static final long CAPTURE_TIMEOUT_MS = 30000;

    private StillCaptureTester() {}

    static Result run(Context context) throws Exception {
        CameraManager manager = context.getSystemService(CameraManager.class);
        if (manager == null) {
            throw new IllegalStateException("CameraManager unavailable");
        }

        JSONObject report = new JSONObject();
        report.put("schema", 1);
        report.put("probe", "org.sableos.research.cameraprobe");
        report.put("test", "jpeg-still-capture");
        report.put("capturedUtc", isoUtcNow());

        File base = context.getExternalFilesDir("camera-probe/captures");
        if (base == null) {
            base = new File(context.getFilesDir(), "camera-probe/captures");
        }
        if (!base.isDirectory() && !base.mkdirs()) {
            throw new IllegalStateException("Unable to create " + base);
        }

        JSONArray tests = new JSONArray();
        for (String id : manager.getCameraIdList()) {
            CameraCharacteristics chars = manager.getCameraCharacteristics(id);
            android.hardware.camera2.params.StreamConfigurationMap map =
                    chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
            if (map == null) {
                continue;
            }

            Size[] jpegSizes = map.getOutputSizes(ImageFormat.JPEG);
            if (jpegSizes == null || jpegSizes.length == 0) {
                continue;
            }

            Size max = largest(jpegSizes);
            Size conventional = largestWithin(jpegSizes, 4096, 3072);
            if (conventional == null) {
                conventional = smallest(jpegSizes);
            }

            tests.put(runOne(manager, id, "conventional", conventional, base));

            if (!max.equals(conventional)) {
                tests.put(runOne(manager, id, "maximum", max, base));
            }
        }

        report.put("tests", tests);

        byte[] bytes = report.toString(2).getBytes(java.nio.charset.StandardCharsets.UTF_8);
        File historical = new File(
                base.getParentFile(),
                "camera-capture-" + compactUtcNow() + ".json"
        );
        File latest = new File(base.getParentFile(), "camera-capture-latest.json");
        writeBytes(historical, bytes);
        writeBytes(latest, bytes);

        return new Result(report, latest);
    }

    private static JSONObject runOne(
            CameraManager manager,
            String cameraId,
            String label,
            Size size,
            File outputDir
    ) throws JSONException {
        JSONObject result = new JSONObject();
        result.put("cameraId", cameraId);
        result.put("label", label);
        result.put("requestedWidth", size.getWidth());
        result.put("requestedHeight", size.getHeight());

        String stem =
                "camera-" + safe(cameraId) + "-" + label + "-" +
                size.getWidth() + "x" + size.getHeight();
        File imageFile = new File(outputDir, stem + ".jpg");

        HandlerThread thread = new HandlerThread("still-capture-" + cameraId + "-" + label);
        thread.start();
        Handler handler = new Handler(thread.getLooper());

        CameraDevice device = null;
        CameraCaptureSession session = null;
        ImageReader reader = null;

        long startNanos = System.nanoTime();

        try {
            device = openCamera(manager, cameraId, handler);
            result.put("open", "success");

            reader = ImageReader.newInstance(
                    size.getWidth(),
                    size.getHeight(),
                    ImageFormat.JPEG,
                    2
            );

            ImageReader finalReader = reader;
            AtomicReference<Throwable> imageError = new AtomicReference<>();
            CountDownLatch imageReady = new CountDownLatch(1);

            reader.setOnImageAvailableListener(r -> {
                try (Image image = r.acquireNextImage()) {
                    if (image == null) {
                        throw new IllegalStateException("ImageReader returned null image");
                    }

                    ByteBuffer buffer = image.getPlanes()[0].getBuffer();
                    byte[] jpeg = new byte[buffer.remaining()];
                    buffer.get(jpeg);
                    writeBytes(imageFile, jpeg);
                } catch (Throwable t) {
                    imageError.set(t);
                } finally {
                    imageReady.countDown();
                }
            }, handler);

            session = createSession(device, finalReader.getSurface(), handler);
            result.put("session", "configured");

            CaptureRequest.Builder request =
                    device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);
            request.addTarget(finalReader.getSurface());
            request.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);

            Integer afMode = chooseAfMode(
                    manager.getCameraCharacteristics(cameraId)
                            .get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)
            );
            if (afMode != null) {
                request.set(CaptureRequest.CONTROL_AF_MODE, afMode);
                result.put("afMode", afMode);
            }

            CountDownLatch captureDone = new CountDownLatch(1);
            AtomicReference<Throwable> captureError = new AtomicReference<>();
            AtomicReference<Long> sensorTimestamp = new AtomicReference<>();

            session.capture(
                    request.build(),
                    new CameraCaptureSession.CaptureCallback() {
                        @Override
                        public void onCaptureCompleted(
                                CameraCaptureSession session,
                                CaptureRequest request,
                                android.hardware.camera2.TotalCaptureResult captureResult
                        ) {
                            sensorTimestamp.set(
                                    captureResult.get(CaptureResult.SENSOR_TIMESTAMP)
                            );
                            captureDone.countDown();
                        }

                        @Override
                        public void onCaptureFailed(
                                CameraCaptureSession session,
                                CaptureRequest request,
                                android.hardware.camera2.CaptureFailure failure
                        ) {
                            captureError.set(
                                    new IllegalStateException(
                                            "capture failed reason=" + failure.getReason()
                                    )
                            );
                            captureDone.countDown();
                        }
                    },
                    handler
            );

            boolean captureCallback = captureDone.await(
                    CAPTURE_TIMEOUT_MS,
                    TimeUnit.MILLISECONDS
            );
            boolean imageCallback = imageReady.await(
                    CAPTURE_TIMEOUT_MS,
                    TimeUnit.MILLISECONDS
            );

            if (!captureCallback) {
                throw new IllegalStateException("capture callback timeout");
            }
            if (captureError.get() != null) {
                throw captureError.get();
            }
            if (!imageCallback) {
                throw new IllegalStateException("image callback timeout");
            }
            if (imageError.get() != null) {
                throw imageError.get();
            }
            if (!imageFile.isFile() || imageFile.length() == 0) {
                throw new IllegalStateException("JPEG output file missing or empty");
            }

            result.put("status", "captured");
            result.put("bytes", imageFile.length());
            result.put("fileName", imageFile.getName());
            if (sensorTimestamp.get() != null) {
                result.put("sensorTimestampNs", sensorTimestamp.get());
            }
        } catch (Throwable t) {
            result.put("status", "failed");
            result.put("errorClass", t.getClass().getName());
            result.put("error", String.valueOf(t.getMessage()));
        } finally {
            if (session != null) {
                session.close();
            }
            if (device != null) {
                device.close();
            }
            if (reader != null) {
                reader.close();
            }
            thread.quitSafely();
        }

        result.put(
                "elapsedMs",
                TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos)
        );
        return result;
    }

    private static CameraDevice openCamera(
            CameraManager manager,
            String id,
            Handler handler
    ) throws Exception {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<CameraDevice> opened = new AtomicReference<>();
        AtomicReference<Throwable> error = new AtomicReference<>();

        manager.openCamera(
                id,
                new CameraDevice.StateCallback() {
                    @Override
                    public void onOpened(CameraDevice camera) {
                        opened.set(camera);
                        latch.countDown();
                    }

                    @Override
                    public void onDisconnected(CameraDevice camera) {
                        camera.close();
                        error.set(new IllegalStateException("camera disconnected"));
                        latch.countDown();
                    }

                    @Override
                    public void onError(CameraDevice camera, int errorCode) {
                        camera.close();
                        error.set(
                                new IllegalStateException("camera error=" + errorCode)
                        );
                        latch.countDown();
                    }
                },
                handler
        );

        if (!latch.await(OPEN_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
            throw new IllegalStateException("camera open timeout");
        }
        if (error.get() != null) {
            throw new Exception(error.get());
        }
        CameraDevice device = opened.get();
        if (device == null) {
            throw new IllegalStateException("camera did not open");
        }
        return device;
    }

    private static CameraCaptureSession createSession(
            CameraDevice device,
            Surface surface,
            Handler handler
    ) throws Exception {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<CameraCaptureSession> configured = new AtomicReference<>();
        AtomicReference<Throwable> error = new AtomicReference<>();

        device.createCaptureSession(
                List.of(surface),
                new CameraCaptureSession.StateCallback() {
                    @Override
                    public void onConfigured(CameraCaptureSession session) {
                        configured.set(session);
                        latch.countDown();
                    }

                    @Override
                    public void onConfigureFailed(CameraCaptureSession session) {
                        error.set(
                                new IllegalStateException("session configuration failed")
                        );
                        latch.countDown();
                    }
                },
                handler
        );

        if (!latch.await(SESSION_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
            throw new IllegalStateException("session configuration timeout");
        }
        if (error.get() != null) {
            throw new Exception(error.get());
        }

        CameraCaptureSession session = configured.get();
        if (session == null) {
            throw new IllegalStateException("session not configured");
        }
        return session;
    }

    private static Integer chooseAfMode(int[] modes) {
        if (modes == null || modes.length == 0) {
            return null;
        }
        for (int mode : modes) {
            if (mode == CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE) {
                return mode;
            }
        }
        for (int mode : modes) {
            if (mode == CaptureRequest.CONTROL_AF_MODE_AUTO) {
                return mode;
            }
        }
        for (int mode : modes) {
            if (mode == CaptureRequest.CONTROL_AF_MODE_OFF) {
                return mode;
            }
        }
        return modes[0];
    }

    private static Size largest(Size[] sizes) {
        return Arrays.stream(sizes)
                .max(Comparator.comparingLong(StillCaptureTester::area))
                .orElseThrow();
    }

    private static Size smallest(Size[] sizes) {
        return Arrays.stream(sizes)
                .min(Comparator.comparingLong(StillCaptureTester::area))
                .orElseThrow();
    }

    private static Size largestWithin(
            Size[] sizes,
            int maxWidth,
            int maxHeight
    ) {
        return Arrays.stream(sizes)
                .filter(s -> s.getWidth() <= maxWidth && s.getHeight() <= maxHeight)
                .max(Comparator.comparingLong(StillCaptureTester::area))
                .orElse(null);
    }

    private static long area(Size size) {
        return (long) size.getWidth() * size.getHeight();
    }

    private static String safe(String value) {
        return value.replaceAll("[^A-Za-z0-9_.-]", "_");
    }

    private static void writeBytes(File file, byte[] bytes) throws Exception {
        try (FileOutputStream stream = new FileOutputStream(file, false)) {
            stream.write(bytes);
            stream.flush();
        }
    }

    private static String isoUtcNow() {
        SimpleDateFormat format =
                new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US);
        format.setTimeZone(TimeZone.getTimeZone("UTC"));
        return format.format(new Date());
    }

    private static String compactUtcNow() {
        SimpleDateFormat format =
                new SimpleDateFormat("yyyyMMdd-HHmmss'Z'", Locale.US);
        format.setTimeZone(TimeZone.getTimeZone("UTC"));
        return format.format(new Date());
    }
}
