package org.sableos.camera;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.DngCreator;
import android.hardware.camera2.TotalCaptureResult;
import android.media.Image;
import android.net.Uri;
import android.os.Environment;
import android.provider.MediaStore;

import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

final class CaptureStore {
    private CaptureStore() {}

    static Uri saveJpeg(Context context, byte[] jpeg) throws Exception {
        String name = "SABLE_" + timestamp() + ".jpg";
        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        values.put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg");
        values.put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                Environment.DIRECTORY_DCIM + "/SableCamera"
        );
        values.put(MediaStore.MediaColumns.IS_PENDING, 1);

        ContentResolver resolver = context.getContentResolver();
        Uri uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) {
            throw new IllegalStateException("MediaStore JPEG insert failed");
        }

        boolean success = false;
        try (OutputStream output = resolver.openOutputStream(uri, "w")) {
            if (output == null) {
                throw new IllegalStateException("Unable to open JPEG output stream");
            }
            output.write(jpeg);
            output.flush();
            success = true;
        } finally {
            if (!success) {
                resolver.delete(uri, null, null);
            }
        }

        values.clear();
        values.put(MediaStore.MediaColumns.IS_PENDING, 0);
        resolver.update(uri, values, null, null);
        return uri;
    }

    static Uri saveDng(
            Context context,
            CameraCharacteristics characteristics,
            TotalCaptureResult result,
            Image image
    ) throws Exception {
        String name = "SABLE_" + timestamp() + ".dng";
        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        values.put(MediaStore.MediaColumns.MIME_TYPE, "image/x-adobe-dng");
        values.put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                Environment.DIRECTORY_DCIM + "/SableCamera"
        );
        values.put(MediaStore.MediaColumns.IS_PENDING, 1);

        ContentResolver resolver = context.getContentResolver();
        Uri collection = MediaStore.Files.getContentUri("external");
        Uri uri = resolver.insert(collection, values);
        if (uri == null) {
            throw new IllegalStateException("MediaStore DNG insert failed");
        }

        boolean success = false;
        try (
                DngCreator creator = new DngCreator(characteristics, result);
                OutputStream output = resolver.openOutputStream(uri, "w")
        ) {
            if (output == null) {
                throw new IllegalStateException("Unable to open DNG output stream");
            }
            creator.writeImage(output, image);
            output.flush();
            success = true;
        } finally {
            if (!success) {
                resolver.delete(uri, null, null);
            }
        }

        values.clear();
        values.put(MediaStore.MediaColumns.IS_PENDING, 0);
        resolver.update(uri, values, null, null);
        return uri;
    }

    private static String timestamp() {
        return new SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(new Date());
    }
}
