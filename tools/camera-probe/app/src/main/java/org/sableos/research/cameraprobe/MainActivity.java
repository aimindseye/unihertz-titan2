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
        runButton.setText("Run probe");
        runButton.setOnClickListener(v -> ensurePermissionAndRun());
        content.addView(runButton);

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

    private void ensurePermissionAndRun() {
        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            runProbe();
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
            runProbe();
        } else {
            statusView.setText("Camera permission is required to perform open tests.");
        }
    }

    private void runProbe() {
        runButton.setEnabled(false);
        statusView.setText("Running Camera2 probe… close other camera apps while this runs.");

        new Thread(() -> {
            try {
                ProbeCollector.Result result = ProbeCollector.collect(this);
                JSONObject report = result.report();

                runOnUiThread(() -> {
                    runButton.setEnabled(true);
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
                    statusView.setText(
                            "Probe failed:\n" +
                            t.getClass().getName() + ": " + t.getMessage()
                    );
                });
            }
        }, "camera-probe-worker").start();
    }
}
