package org.sableos.research.cameraprobe;

import android.content.Context;
import android.graphics.ImageFormat;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.hardware.camera2.DngCreator;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Size;
import android.view.Surface;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.TimeZone;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

final class RawCaptureTester {
    record Result(JSONObject report, File latestFile) {}

    private static final long OPEN_TIMEOUT_MS = 5000;
    private static final long SESSION_TIMEOUT_MS = 5000;
    private static final long CAPTURE_TIMEOUT_MS = 30000;

    private RawCaptureTester() {}

    static Result run(Context context) throws Exception {
        CameraManager manager = context.getSystemService(CameraManager.class);
        if (manager == null) {
            throw new IllegalStateException("CameraManager unavailable");
        }

        JSONObject report = new JSONObject();
        report.put("schema", 1);
        report.put("probe", "org.sableos.research.cameraprobe");
        report.put("test", "raw-dng-capture");
        report.put("capturedUtc", isoUtcNow());

        File base = context.getExternalFilesDir("camera-probe/raw");
        if (base == null) {
            base = new File(context.getFilesDir(), "camera-probe/raw");
        }
        if (!base.isDirectory() && !base.mkdirs()) {
            throw new IllegalStateException("Unable to create " + base);
        }

        JSONArray tests = new JSONArray();
        String[] ids = manager.getCameraIdList();
        Arrays.sort(ids);

        for (String id : ids) {
            CameraCharacteristics chars = manager.getCameraCharacteristics(id);
            StreamConfigurationMap map =
                    chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);

            JSONObject entry = new JSONObject();
            entry.put("cameraId", id);

            if (!hasRawCapability(chars) || map == null) {
                entry.put("status", "skipped");
                entry.put("reason", "RAW capability/stream map unavailable");
                tests.put(entry);
                continue;
            }

            Size[] rawSizes = map.getOutputSizes(ImageFormat.RAW_SENSOR);
            if (rawSizes == null || rawSizes.length == 0) {
                entry.put("status", "skipped");
                entry.put("reason", "RAW_SENSOR output sizes unavailable");
                tests.put(entry);
                continue;
            }

            Size max = Arrays.stream(rawSizes)
                    .max(Comparator.comparingLong(RawCaptureTester::area))
                    .orElseThrow();

            tests.put(runOne(manager, chars, id, max, base));
        }

        report.put("tests", tests);

        byte[] bytes =
                report.toString(2).getBytes(java.nio.charset.StandardCharsets.UTF_8);

        File parent = base.getParentFile();
        File historical = new File(
                parent,
                "camera-raw-" + compactUtcNow() + ".json"
        );
        File latest = new File(parent, "camera-raw-latest.json");
        writeBytes(historical, bytes);
        writeBytes(latest, bytes);

        return new Result(report, latest);
    }

    private static JSONObject runOne(
            CameraManager manager,
            CameraCharacteristics chars,
            String cameraId,
            Size size,
            File outputDir
    ) throws Exception {
        JSONObject result = new JSONObject();
        result.put("cameraId", cameraId);
        result.put("requestedWidth", size.getWidth());
        result.put("requestedHeight", size.getHeight());

        File dngFile = new File(
                outputDir,
                "camera-" + safe(cameraId) + "-" +
                        size.getWidth() + "x" + size.getHeight() + ".dng"
        );

        HandlerThread thread = new HandlerThread("raw-capture-" + cameraId);
        thread.start();
        Handler handler = new Handler(thread.getLooper());

        CameraDevice device = null;
        CameraCaptureSession session = null;
        ImageReader reader = null;
        Image image = null;

        long startNanos = System.nanoTime();

        try {
            device = openCamera(manager, cameraId, handler);
            result.put("open", "success");

            reader = ImageReader.newInstance(
                    size.getWidth(),
                    size.getHeight(),
                    ImageFormat.RAW_SENSOR,
                    2
            );

            AtomicReference<Image> imageRef = new AtomicReference<>();
            AtomicReference<Throwable> imageError = new AtomicReference<>();
            CountDownLatch imageReady = new CountDownLatch(1);

            reader.setOnImageAvailableListener(r -> {
                try {
                    Image acquired = r.acquireNextImage();
                    if (acquired == null) {
                        throw new IllegalStateException("ImageReader returned null RAW image");
                    }
                    if (!imageRef.compareAndSet(null, acquired)) {
                        acquired.close();
                    }
                } catch (Throwable t) {
                    imageError.set(t);
                } finally {
                    imageReady.countDown();
                }
            }, handler);

            session = createSession(device, reader.getSurface(), handler);
            result.put("session", "configured");

            CaptureRequest.Builder request =
                    device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);
            request.addTarget(reader.getSurface());
            request.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);

            Integer afMode = chooseAfMode(
                    chars.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)
            );
            if (afMode != null) {
                request.set(CaptureRequest.CONTROL_AF_MODE, afMode);
                result.put("afMode", afMode);
            }

            CountDownLatch captureDone = new CountDownLatch(1);
            AtomicReference<TotalCaptureResult> captureResult = new AtomicReference<>();
            AtomicReference<Throwable> captureError = new AtomicReference<>();

            session.capture(
                    request.build(),
                    new CameraCaptureSession.CaptureCallback() {
                        @Override
                        public void onCaptureCompleted(
                                CameraCaptureSession session,
                                CaptureRequest request,
                                TotalCaptureResult result
                        ) {
                            captureResult.set(result);
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

            if (!captureDone.await(CAPTURE_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
                throw new IllegalStateException("RAW capture callback timeout");
            }
            if (captureError.get() != null) {
                throw new Exception(captureError.get());
            }
            if (!imageReady.await(CAPTURE_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
                throw new IllegalStateException("RAW image callback timeout");
            }
            if (imageError.get() != null) {
                throw new Exception(imageError.get());
            }

            image = imageRef.get();
            TotalCaptureResult metadata = captureResult.get();

            if (image == null) {
                throw new IllegalStateException("RAW image unavailable");
            }
            if (metadata == null) {
                throw new IllegalStateException("RAW capture metadata unavailable");
            }

            Long sensorTimestamp = metadata.get(CaptureResult.SENSOR_TIMESTAMP);
            if (sensorTimestamp != null) {
                result.put("sensorTimestampNs", sensorTimestamp);
            }

            try (
                    DngCreator creator = new DngCreator(chars, metadata);
                    FileOutputStream output = new FileOutputStream(dngFile, false)
            ) {
                creator.writeImage(output, image);
                output.flush();
            }

            if (!dngFile.isFile() || dngFile.length() == 0) {
                throw new IllegalStateException("DNG output file missing or empty");
            }

            result.put("status", "captured");
            result.put("bytes", dngFile.length());
            result.put("fileName", dngFile.getName());
        } catch (Throwable t) {
            result.put("status", "failed");
            result.put("errorClass", t.getClass().getName());
            result.put("error", String.valueOf(t.getMessage()));
        } finally {
            if (image != null) {
                image.close();
            }
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

    private static boolean hasRawCapability(CameraCharacteristics chars) {
        int[] caps = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES);
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
