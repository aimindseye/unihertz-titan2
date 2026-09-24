package org.sableos.camera;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.TextureView;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

public final class MainActivity extends Activity implements CameraController.Listener {
    private static final int CAMERA_PERMISSION_REQUEST = 2001;

    private TextureView textureView;
    private TextView statusView;
    private TextView modeView;
    private Button cameraButton;
    private Button resolutionButton;
    private Button formatButton;
    private Button shutterButton;

    private CameraController controller;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        int pad = Math.round(10 * getResources().getDisplayMetrics().density);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.BLACK);
        root.setPadding(pad, pad, pad, pad);

        modeView = new TextView(this);
        modeView.setText("Sable Camera");
        modeView.setTextColor(Color.WHITE);
        modeView.setTextSize(18);
        modeView.setGravity(Gravity.CENTER_HORIZONTAL);
        root.addView(
                modeView,
                new LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                )
        );

        textureView = new TextureView(this);
        LinearLayout.LayoutParams previewParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
        );
        previewParams.topMargin = pad;
        previewParams.bottomMargin = pad;
        root.addView(textureView, previewParams);

        LinearLayout controls = new LinearLayout(this);
        controls.setOrientation(LinearLayout.HORIZONTAL);
        controls.setGravity(Gravity.CENTER);

        cameraButton = button("Rear");
        cameraButton.setOnClickListener(v -> {
            if (controller != null) {
                controller.toggleFacing();
            }
        });
        controls.addView(cameraButton, weightedButtonParams());

        resolutionButton = button("Normal");
        resolutionButton.setOnClickListener(v -> {
            if (controller != null) {
                controller.toggleResolution();
            }
        });
        controls.addView(resolutionButton, weightedButtonParams());

        formatButton = button("JPEG");
        formatButton.setOnClickListener(v -> {
            if (controller != null) {
                controller.toggleRaw();
            }
        });
        controls.addView(formatButton, weightedButtonParams());

        root.addView(
                controls,
                new LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                )
        );

        shutterButton = button("SHUTTER");
        shutterButton.setTextSize(18);
        shutterButton.setOnClickListener(v -> capture());
        LinearLayout.LayoutParams shutterParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
        shutterParams.topMargin = pad;
        root.addView(shutterButton, shutterParams);

        statusView = new TextView(this);
        statusView.setText("Camera permission required.");
        statusView.setTextColor(Color.LTGRAY);
        statusView.setTextSize(13);
        statusView.setGravity(Gravity.CENTER_HORIZONTAL);
        statusView.setPadding(0, pad, 0, 0);
        root.addView(
                statusView,
                new LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                )
        );

        setContentView(root);

        if (checkSelfPermission(Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(
                    new String[] { Manifest.permission.CAMERA },
                    CAMERA_PERMISSION_REQUEST
            );
        } else {
            ensureController();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (checkSelfPermission(Manifest.permission.CAMERA)
                == PackageManager.PERMISSION_GRANTED) {
            ensureController();
            controller.start();
        }
    }

    @Override
    protected void onPause() {
        if (controller != null) {
            controller.stop();
        }
        super.onPause();
    }

    private void ensureController() {
        if (controller == null) {
            controller = new CameraController(this, textureView, this);
        }
    }

    private Button button(String text) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        return button;
    }

    private LinearLayout.LayoutParams weightedButtonParams() {
        return new LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f
        );
    }

    private void capture() {
        if (controller != null) {
            controller.capture();
        }
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_CAMERA
                || keyCode == KeyEvent.KEYCODE_ENTER
                || keyCode == KeyEvent.KEYCODE_DPAD_CENTER
                || keyCode == KeyEvent.KEYCODE_SPACE) {
            capture();
            return true;
        }

        return super.onKeyUp(keyCode, event);
    }

    @Override
    public void onStatus(String message) {
        statusView.setText(message);
    }

    @Override
    public void onState(CameraController.UiState state) {
        cameraButton.setText(state.facing());
        resolutionButton.setText(state.highResolution() ? "High" : "Normal");

        if (state.rawMode()) {
            formatButton.setText("RAW");
        } else {
            formatButton.setText("JPEG");
        }
        formatButton.setEnabled(state.rawAvailable());

        modeView.setText(
                "Camera " + state.cameraId()
                        + " · " + state.facing()
                        + " · " + state.format()
                        + " · " + state.resolution()
        );
    }

    @Override
    public void onSaved(android.net.Uri uri, String description) {
        statusView.setText("Saved " + description + "\n" + uri);
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
            ensureController();
            controller.start();
        } else {
            statusView.setText("Camera permission is required.");
        }
    }
}
