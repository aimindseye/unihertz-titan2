package org.sableos.research.cameraprobe;

import android.content.Context;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Range;
import android.util.Rational;
import android.util.Size;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.lang.reflect.Array;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.TimeZone;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

final class ProbeCollector {
    record Result(
            JSONObject report,
            File latestFile,
            List<String> visibleCameraIds
    ) {}

    private ProbeCollector() {}

    static Result collect(Context context) throws Exception {
        CameraManager manager = context.getSystemService(CameraManager.class);
        if (manager == null) {
            throw new IllegalStateException("CameraManager unavailable");
        }

        JSONObject report = new JSONObject();
        report.put("schema", 1);
        report.put("probe", "org.sableos.research.cameraprobe");
        report.put("probeVersion", "0.1");
        report.put("capturedUtc", isoUtcNow());
        report.put("build", collectBuild());

        String[] ids = manager.getCameraIdList();
        Arrays.sort(ids);

        JSONArray visibleIds = new JSONArray();
        for (String id : ids) {
            visibleIds.put(id);
        }
        report.put("visibleCameraIds", visibleIds);

        JSONArray cameras = new JSONArray();
        for (String id : ids) {
            JSONObject camera = describeCamera(manager, id);
            camera.put("openTest", openCamera(manager, id));
            cameras.put(camera);
        }
        report.put("cameras", cameras);

        File latest = writeReport(context, report);
        return new Result(
                report,
                latest,
                Collections.unmodifiableList(Arrays.asList(ids.clone()))
        );
    }

    private static JSONObject collectBuild() throws JSONException {
        JSONObject build = new JSONObject();
        build.put("manufacturer", Build.MANUFACTURER);
        build.put("brand", Build.BRAND);
        build.put("model", Build.MODEL);
        build.put("device", Build.DEVICE);
        build.put("product", Build.PRODUCT);
        build.put("display", Build.DISPLAY);
        build.put("fingerprint", Build.FINGERPRINT);
        build.put("sdkInt", Build.VERSION.SDK_INT);
        build.put("release", Build.VERSION.RELEASE);
        build.put("incremental", Build.VERSION.INCREMENTAL);
        build.put("securityPatch", Build.VERSION.SECURITY_PATCH);
        return build;
    }

    private static JSONObject describeCamera(
            CameraManager manager,
            String id
    ) throws CameraAccessException, JSONException {
        CameraCharacteristics c = manager.getCameraCharacteristics(id);

        JSONObject out = new JSONObject();
        out.put("id", id);
        out.put("facing", facingName(c.get(CameraCharacteristics.LENS_FACING)));
        out.put(
                "hardwareLevel",
                hardwareLevelName(c.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL))
        );
        out.put(
                "sensorOrientation",
                jsonValue(c.get(CameraCharacteristics.SENSOR_ORIENTATION))
        );
        out.put(
                "flashAvailable",
                jsonValue(c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE))
        );

        JSONArray capabilities = new JSONArray();
        int[] caps = c.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES);
        if (caps != null) {
            int[] sorted = caps.clone();
            Arrays.sort(sorted);
            for (int cap : sorted) {
                JSONObject item = new JSONObject();
                item.put("value", cap);
                item.put("name", capabilityName(cap));
                capabilities.put(item);
            }
        }
        out.put("capabilities", capabilities);

        List<String> physical = new ArrayList<>(c.getPhysicalCameraIds());
        Collections.sort(physical);
        out.put("physicalCameraIds", new JSONArray(physical));

        JSONObject standard = new JSONObject();
        putCharacteristic(
                standard, "availableFocalLengths",
                c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
        );
        putCharacteristic(
                standard, "availableApertures",
                c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)
        );
        putCharacteristic(
                standard, "availableOpticalStabilization",
                c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)
        );
        putCharacteristic(
                standard, "minimumFocusDistance",
                c.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE)
        );
        putCharacteristic(
                standard, "sensorPhysicalSize",
                c.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
        );
        putCharacteristic(
                standard, "pixelArraySize",
                c.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
        );
        putCharacteristic(
                standard, "activeArraySize",
                c.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
        );
        putCharacteristic(
                standard, "preCorrectionActiveArraySize",
                c.get(CameraCharacteristics.SENSOR_INFO_PRE_CORRECTION_ACTIVE_ARRAY_SIZE)
        );
        putCharacteristic(
                standard, "sensitivityRange",
                c.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
        );
        putCharacteristic(
                standard, "exposureTimeRange",
                c.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
        );
        putCharacteristic(
                standard, "maxFrameDuration",
                c.get(CameraCharacteristics.SENSOR_INFO_MAX_FRAME_DURATION)
        );
        putCharacteristic(
                standard, "colorFilterArrangement",
                c.get(CameraCharacteristics.SENSOR_INFO_COLOR_FILTER_ARRANGEMENT)
        );
        putCharacteristic(
                standard, "zoomRatioRange",
                c.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
        );
        putCharacteristic(
                standard, "maxDigitalZoom",
                c.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)
        );
        putCharacteristic(
                standard, "availableVideoStabilizationModes",
                c.get(CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES)
        );
        putCharacteristic(
                standard, "aeFpsRanges",
                c.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
        );
        out.put("standardCharacteristics", standard);

        StreamConfigurationMap map =
                c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
        out.put("streams", describeStreams(map));

        out.put("vendorCharacteristics", describeVendorCharacteristics(c));
        out.put(
                "vendorRequestKeys",
                vendorCaptureRequestKeys(c.getAvailableCaptureRequestKeys())
        );
        out.put(
                "vendorResultKeys",
                vendorCaptureResultKeys(c.getAvailableCaptureResultKeys())
        );
        out.put(
                "vendorSessionKeys",
                vendorCaptureRequestKeys(c.getAvailableSessionKeys())
        );
        out.put(
                "vendorPhysicalRequestKeys",
                vendorCaptureRequestKeys(c.getAvailablePhysicalCameraRequestKeys())
        );
        return out;
    }

    private static JSONObject describeStreams(
            StreamConfigurationMap map
    ) throws JSONException {
        JSONObject out = new JSONObject();
        if (map == null) {
            out.put("available", false);
            return out;
        }

        out.put("available", true);

        int[] outputFormats = map.getOutputFormats();
        Arrays.sort(outputFormats);
        JSONArray outputs = new JSONArray();
        for (int format : outputFormats) {
            JSONObject f = new JSONObject();
            f.put("format", format);
            f.put("name", formatName(format));
            f.put("sizes", sizesToJson(map.getOutputSizes(format)));

            try {
                Size[] high = map.getHighResolutionOutputSizes(format);
                f.put("highResolutionSizes", sizesToJson(high));
            } catch (RuntimeException ignored) {
                // Some vendor implementations reject high-resolution queries
                // for formats even when the format appears in the output list.
            }

            outputs.put(f);
        }
        out.put("outputs", outputs);

        int[] inputFormats = map.getInputFormats();
        Arrays.sort(inputFormats);
        JSONArray inputs = new JSONArray();
        for (int format : inputFormats) {
            JSONObject f = new JSONObject();
            f.put("format", format);
            f.put("name", formatName(format));
            f.put("sizes", sizesToJson(map.getInputSizes(format)));
            inputs.put(f);
        }
        out.put("inputs", inputs);

        JSONArray highSpeed = new JSONArray();
        try {
            Size[] sizes = map.getHighSpeedVideoSizes();
            if (sizes != null) {
                Arrays.sort(
                        sizes,
                        Comparator.comparingInt(Size::getWidth)
                                .thenComparingInt(Size::getHeight)
                );
                for (Size size : sizes) {
                    JSONObject entry = new JSONObject();
                    entry.put("size", jsonValue(size));
                    Range<Integer>[] ranges = map.getHighSpeedVideoFpsRangesFor(size);
                    entry.put("fpsRanges", jsonValue(ranges));
                    highSpeed.put(entry);
                }
            }
        } catch (RuntimeException ignored) {
            // Keep the rest of the report even if a vendor map rejects this.
        }
        out.put("highSpeedVideo", highSpeed);

        return out;
    }


    private static JSONArray vendorCaptureRequestKeys(
            List<CaptureRequest.Key<?>> keys
    ) throws JSONException {
        JSONArray out = new JSONArray();
        if (keys == null) {
            return out;
        }

        List<String> names = new ArrayList<>();
        for (CaptureRequest.Key<?> key : keys) {
            String name = key.getName();
            if (!name.startsWith("android.")) {
                names.add(name);
            }
        }
        Collections.sort(names);
        for (String name : names) {
            out.put(name);
        }
        return out;
    }

    private static JSONArray vendorCaptureResultKeys(
            List<CaptureResult.Key<?>> keys
    ) throws JSONException {
        JSONArray out = new JSONArray();
        if (keys == null) {
            return out;
        }

        List<String> names = new ArrayList<>();
        for (CaptureResult.Key<?> key : keys) {
            String name = key.getName();
            if (!name.startsWith("android.")) {
                names.add(name);
            }
        }
        Collections.sort(names);
        for (String name : names) {
            out.put(name);
        }
        return out;
    }

    private static JSONArray describeVendorCharacteristics(
            CameraCharacteristics c
    ) throws JSONException {
        List<CameraCharacteristics.Key<?>> keys = new ArrayList<>(c.getKeys());
        keys.sort(Comparator.comparing(CameraCharacteristics.Key::getName));

        JSONArray out = new JSONArray();
        for (CameraCharacteristics.Key<?> key : keys) {
            String name = key.getName();
            if (name.startsWith("android.")) {
                continue;
            }

            JSONObject item = new JSONObject();
            item.put("name", name);

            try {
                item.put("value", jsonValue(getUnchecked(c, key)));
            } catch (RuntimeException e) {
                item.put("readError", e.getClass().getSimpleName() + ": " + e.getMessage());
            }

            out.put(item);
        }
        return out;
    }

    @SuppressWarnings({"rawtypes", "unchecked"})
    private static Object getUnchecked(
            CameraCharacteristics c,
            CameraCharacteristics.Key<?> key
    ) {
        return c.get((CameraCharacteristics.Key) key);
    }

    private static JSONObject openCamera(
            CameraManager manager,
            String id
    ) throws JSONException {
        JSONObject result = new JSONObject();
        result.put("attempted", true);

        HandlerThread callbacks = new HandlerThread("probe-camera-" + id);
        callbacks.start();
        Handler handler = new Handler(callbacks.getLooper());

        CountDownLatch done = new CountDownLatch(1);

        try {
            manager.openCamera(
                    id,
                    new CameraDevice.StateCallback() {
                        @Override
                        public void onOpened(CameraDevice camera) {
                            try {
                                result.put("status", "opened");
                            } catch (JSONException ignored) {
                            }
                            camera.close();
                            done.countDown();
                        }

                        @Override
                        public void onDisconnected(CameraDevice camera) {
                            try {
                                result.put("status", "disconnected");
                            } catch (JSONException ignored) {
                            }
                            camera.close();
                            done.countDown();
                        }

                        @Override
                        public void onError(CameraDevice camera, int error) {
                            try {
                                result.put("status", "error");
                                result.put("error", error);
                                result.put("errorName", cameraErrorName(error));
                            } catch (JSONException ignored) {
                            }
                            camera.close();
                            done.countDown();
                        }
                    },
                    handler
            );

            if (!done.await(5, TimeUnit.SECONDS)) {
                result.put("status", "timeout");
            }
        } catch (CameraAccessException e) {
            result.put("status", "cameraAccessException");
            result.put("reason", e.getReason());
            result.put("message", e.getMessage());
        } catch (SecurityException e) {
            result.put("status", "securityException");
            result.put("message", e.getMessage());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            result.put("status", "interrupted");
        } finally {
            callbacks.quitSafely();
        }

        return result;
    }

    private static File writeReport(
            Context context,
            JSONObject report
    ) throws Exception {
        File base = context.getExternalFilesDir("camera-probe");
        if (base == null) {
            base = new File(context.getFilesDir(), "camera-probe");
        }

        if (!base.isDirectory() && !base.mkdirs()) {
            throw new IllegalStateException("Unable to create " + base);
        }

        String stamp = compactUtcNow();
        File historical = new File(base, "camera-probe-" + stamp + ".json");
        File latest = new File(base, "camera-probe-latest.json");

        byte[] bytes = report.toString(2).getBytes(StandardCharsets.UTF_8);
        writeBytes(historical, bytes);
        writeBytes(latest, bytes);
        return latest;
    }

    private static void writeBytes(File file, byte[] bytes) throws Exception {
        try (FileOutputStream stream = new FileOutputStream(file, false)) {
            stream.write(bytes);
            stream.flush();
        }
    }

    private static void putCharacteristic(
            JSONObject object,
            String name,
            Object value
    ) throws JSONException {
        object.put(name, jsonValue(value));
    }

    private static JSONArray sizesToJson(Size[] sizes) throws JSONException {
        JSONArray out = new JSONArray();
        if (sizes == null) {
            return out;
        }

        Size[] sorted = sizes.clone();
        Arrays.sort(
                sorted,
                Comparator.comparingInt(Size::getWidth)
                        .thenComparingInt(Size::getHeight)
        );

        for (Size size : sorted) {
            out.put(jsonValue(size));
        }
        return out;
    }

    private static Object jsonValue(Object value) throws JSONException {
        if (value == null) {
            return JSONObject.NULL;
        }

        if (value instanceof JSONObject
                || value instanceof JSONArray
                || value instanceof Number
                || value instanceof Boolean
                || value instanceof String) {
            return value;
        }

        if (value instanceof Size size) {
            JSONObject out = new JSONObject();
            out.put("width", size.getWidth());
            out.put("height", size.getHeight());
            return out;
        }

        if (value instanceof Rect rect) {
            JSONObject out = new JSONObject();
            out.put("left", rect.left);
            out.put("top", rect.top);
            out.put("right", rect.right);
            out.put("bottom", rect.bottom);
            return out;
        }

        if (value instanceof Range<?> range) {
            JSONObject out = new JSONObject();
            out.put("lower", jsonValue(range.getLower()));
            out.put("upper", jsonValue(range.getUpper()));
            return out;
        }

        if (value instanceof Rational rational) {
            JSONObject out = new JSONObject();
            out.put("numerator", rational.getNumerator());
            out.put("denominator", rational.getDenominator());
            out.put("decimal", rational.doubleValue());
            return out;
        }

        if (value instanceof Collection<?> collection) {
            JSONArray out = new JSONArray();
            for (Object item : collection) {
                out.put(jsonValue(item));
            }
            return out;
        }

        if (value instanceof Set<?> set) {
            List<String> sorted = new ArrayList<>();
            for (Object item : set) {
                sorted.add(String.valueOf(item));
            }
            Collections.sort(sorted);
            return new JSONArray(sorted);
        }

        Class<?> type = value.getClass();
        if (type.isArray()) {
            JSONArray out = new JSONArray();
            int length = Array.getLength(value);
            for (int i = 0; i < length; i++) {
                out.put(jsonValue(Array.get(value, i)));
            }
            return out;
        }

        return String.valueOf(value);
    }

    private static String facingName(Integer value) {
        if (value == null) {
            return "UNKNOWN";
        }
        return switch (value) {
            case CameraCharacteristics.LENS_FACING_FRONT -> "FRONT";
            case CameraCharacteristics.LENS_FACING_BACK -> "BACK";
            case CameraCharacteristics.LENS_FACING_EXTERNAL -> "EXTERNAL";
            default -> "UNKNOWN(" + value + ")";
        };
    }

    private static String hardwareLevelName(Integer value) {
        if (value == null) {
            return "UNKNOWN";
        }
        return switch (value) {
            case CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY -> "LEGACY";
            case CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED -> "LIMITED";
            case CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL -> "FULL";
            case CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3 -> "LEVEL_3";
            case CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_EXTERNAL -> "EXTERNAL";
            default -> "UNKNOWN(" + value + ")";
        };
    }

    private static String capabilityName(int value) {
        return switch (value) {
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_BACKWARD_COMPATIBLE ->
                    "BACKWARD_COMPATIBLE";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR ->
                    "MANUAL_SENSOR";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_POST_PROCESSING ->
                    "MANUAL_POST_PROCESSING";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_RAW -> "RAW";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_PRIVATE_REPROCESSING ->
                    "PRIVATE_REPROCESSING";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_READ_SENSOR_SETTINGS ->
                    "READ_SENSOR_SETTINGS";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_BURST_CAPTURE ->
                    "BURST_CAPTURE";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_YUV_REPROCESSING ->
                    "YUV_REPROCESSING";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_DEPTH_OUTPUT ->
                    "DEPTH_OUTPUT";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_CONSTRAINED_HIGH_SPEED_VIDEO ->
                    "CONSTRAINED_HIGH_SPEED_VIDEO";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MOTION_TRACKING ->
                    "MOTION_TRACKING";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA ->
                    "LOGICAL_MULTI_CAMERA";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MONOCHROME ->
                    "MONOCHROME";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_SECURE_IMAGE_DATA ->
                    "SECURE_IMAGE_DATA";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_SYSTEM_CAMERA ->
                    "SYSTEM_CAMERA";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_OFFLINE_PROCESSING ->
                    "OFFLINE_PROCESSING";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_ULTRA_HIGH_RESOLUTION_SENSOR ->
                    "ULTRA_HIGH_RESOLUTION_SENSOR";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_REMOSAIC_REPROCESSING ->
                    "REMOSAIC_REPROCESSING";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_DYNAMIC_RANGE_TEN_BIT ->
                    "DYNAMIC_RANGE_TEN_BIT";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_STREAM_USE_CASE ->
                    "STREAM_USE_CASE";
            case CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_COLOR_SPACE_PROFILES ->
                    "COLOR_SPACE_PROFILES";
            default -> "UNKNOWN(" + value + ")";
        };
    }

    private static String formatName(int format) {
        return switch (format) {
            case ImageFormat.JPEG -> "JPEG";
            case ImageFormat.YUV_420_888 -> "YUV_420_888";
            case ImageFormat.RAW_SENSOR -> "RAW_SENSOR";
            case ImageFormat.RAW10 -> "RAW10";
            case ImageFormat.RAW12 -> "RAW12";
            case ImageFormat.PRIVATE -> "PRIVATE";
            case ImageFormat.DEPTH16 -> "DEPTH16";
            case ImageFormat.DEPTH_JPEG -> "DEPTH_JPEG";
            case ImageFormat.HEIC -> "HEIC";
            case ImageFormat.YCBCR_P010 -> "YCBCR_P010";
            default -> "FORMAT_" + format;
        };
    }

    private static String cameraErrorName(int error) {
        return switch (error) {
            case CameraDevice.StateCallback.ERROR_CAMERA_IN_USE -> "CAMERA_IN_USE";
            case CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE -> "MAX_CAMERAS_IN_USE";
            case CameraDevice.StateCallback.ERROR_CAMERA_DISABLED -> "CAMERA_DISABLED";
            case CameraDevice.StateCallback.ERROR_CAMERA_DEVICE -> "CAMERA_DEVICE";
            case CameraDevice.StateCallback.ERROR_CAMERA_SERVICE -> "CAMERA_SERVICE";
            default -> "UNKNOWN(" + error + ")";
        };
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
