package org.sableos.research.cameraprobe;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import org.json.JSONObject;

public final class MainActivity extends Activity {
    private static final int CAMERA_PERMISSION_REQUEST = 1001;

    private Button runButton;
    private Button captureButton;
    private Button rawButton;
    private TextView statusView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        int pad = Math.round(16 * getResources().getDisplayMetrics().density);

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("Titan 2 Camera Probe");
        title.setTextSize(24);
        content.addView(title);

        TextView explanation = new TextView(this);
        explanation.setText(
                "Normal-app Camera2 capability probe.\n\n" +
                "It enumerates cameras visible to this process, records characteristics " +
                "and accessible vendor tags, and attempts to open every returned camera.\n\n" +
                "Raw JSON stays in app-specific storage until pulled with adb."
        );
        explanation.setTextSize(16);
        explanation.setPadding(0, pad, 0, pad);
        content.addView(explanation);

        runButton = new Button(this);
        runButton.setText("Run metadata probe");
        runButton.setOnClickListener(v -> ensurePermissionAndRun(0));
        content.addView(runButton);

        captureButton = new Button(this);
        captureButton.setText("Run JPEG capture tests");
        captureButton.setOnClickListener(v -> ensurePermissionAndRun(1));
        content.addView(captureButton);

        rawButton = new Button(this);
        rawButton.setText("Run RAW DNG capture test");
        rawButton.setOnClickListener(v -> ensurePermissionAndRun(2));
        content.addView(rawButton);

        statusView = new TextView(this);
        statusView.setText("Ready.");
        statusView.setTextSize(14);
        statusView.setTextIsSelectable(true);
        statusView.setPadding(0, pad, 0, 0);
        content.addView(statusView);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);
        setContentView(scroll);
    }

    private int pendingAction;

    private void ensurePermissionAndRun(int action) {
        pendingAction = action;

        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            runPendingAction();
            return;
        }

        requestPermissions(
                new String[] { Manifest.permission.CAMERA },
                CAMERA_PERMISSION_REQUEST
        );
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode,
            String[] permissions,
            int[] grantResults
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);

        if (requestCode != CAMERA_PERMISSION_REQUEST) {
            return;
        }

        if (grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            runPendingAction();
        } else {
            statusView.setText("Camera permission is required to perform open tests.");
        }
    }



    private void runPendingAction() {
        switch (pendingAction) {
            case 1 -> runCaptureTests();
            case 2 -> runRawCaptureTest();
            default -> runProbe();
        }
    }

    private void runCaptureTests() {
        runButton.setEnabled(false);
        captureButton.setEnabled(false);
        rawButton.setEnabled(false);
        statusView.setText(
                "Running JPEG still-capture tests… close other camera apps. " +
                "Maximum-resolution captures may take several seconds."
        );

        new Thread(() -> {
            try {
                StillCaptureTester.Result result = StillCaptureTester.run(this);

                runOnUiThread(() -> {
                    runButton.setEnabled(true);
                    captureButton.setEnabled(true);
                    rawButton.setEnabled(true);
                    statusView.setText(
                            "JPEG capture tests complete.\n\n" +
                            "Saved report:\n" + result.latestFile().getAbsolutePath() +
                            "\n\nRaw JPEGs are in the captures subdirectory."
                    );
                });
            } catch (Throwable t) {
                runOnUiThread(() -> {
                    runButton.setEnabled(true);
                    captureButton.setEnabled(true);
                    rawButton.setEnabled(true);
                    statusView.setText(
                            "Capture tests failed:\n" +
                            t.getClass().getName() + ": " + t.getMessage()
                    );
                });
            }
        }, "camera-capture-worker").start();
    }


    private void runRawCaptureTest() {
        runButton.setEnabled(false);
        captureButton.setEnabled(false);
        rawButton.setEnabled(false);
        statusView.setText(
                "Running RAW DNG capture test… close other camera apps. " +
                "Only cameras that advertise RAW_SENSOR will be exercised."
        );

        new Thread(() -> {
            try {
                RawCaptureTester.Result result = RawCaptureTester.run(this);

                runOnUiThread(() -> {
                    runButton.setEnabled(true);
                    captureButton.setEnabled(true);
                    rawButton.setEnabled(true);
                    statusView.setText(
                            "RAW capture test complete.\n\n" +
                            "Saved report:\n" + result.latestFile().getAbsolutePath() +
                            "\n\nDNG output is in the raw subdirectory."
                    );
                });
            } catch (Throwable t) {
                runOnUiThread(() -> {
                    runButton.setEnabled(true);
                    captureButton.setEnabled(true);
                    rawButton.setEnabled(true);
                    statusView.setText(
                            "RAW capture test failed:\n" +
                            t.getClass().getName() + ": " + t.getMessage()
                    );
                });
            }
        }, "camera-raw-worker").start();
    }

    private void runProbe() {
        runButton.setEnabled(false);
        captureButton.setEnabled(false);
        rawButton.setEnabled(false);
        statusView.setText("Running Camera2 probe… close other camera apps while this runs.");

        new Thread(() -> {
            try {
                ProbeCollector.Result result = ProbeCollector.collect(this);
                JSONObject report = result.report();

                runOnUiThread(() -> {
                    runButton.setEnabled(true);
                    captureButton.setEnabled(true);
                    rawButton.setEnabled(true);
                    statusView.setText(
                            "Probe complete.\n\n" +
                            "Visible camera IDs: " + result.visibleCameraIds() + "\n\n" +
                            "Saved latest report:\n" + result.latestFile().getAbsolutePath() +
                            "\n\nReport bytes: " + result.latestFile().length() +
                            "\n\nTop-level keys: " + report.names()
                    );
                });
            } catch (Throwable t) {
                runOnUiThread(() -> {
                    runButton.setEnabled(true);
                    captureButton.setEnabled(true);
                    rawButton.setEnabled(true);
                    statusView.setText(
                            "Probe failed:\n" +
                            t.getClass().getName() + ": " + t.getMessage()
                    );
                });
            }
        }, "camera-probe-worker").start();
    }
}
