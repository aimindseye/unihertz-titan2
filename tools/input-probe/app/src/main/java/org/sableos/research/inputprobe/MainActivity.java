package org.sableos.research.inputprobe;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.text.InputType;
import android.util.Log;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.Locale;

public final class MainActivity extends Activity {
    private static final String TAG = "SableInputProbe";

    private TextView sink;
    private EditText editor;
    private TextView logView;
    private int lineCount = 0;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(12, 12, 12, 12);
        root.setBackgroundColor(Color.WHITE);

        TextView title = new TextView(this);
        title.setText("Titan 2 Input Probe");
        title.setTextSize(20f);
        title.setTextColor(Color.BLACK);
        root.addView(title, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        sink = new TextView(this);
        sink.setText("NON-TEXT EVENT SINK\nTap here, then press physical keys or use the keyboard touch surface.");
        sink.setTextSize(16f);
        sink.setTextColor(Color.BLACK);
        sink.setBackgroundColor(0xffdddddd);
        sink.setPadding(16, 24, 16, 24);
        sink.setGravity(Gravity.CENTER);
        sink.setFocusable(true);
        sink.setFocusableInTouchMode(true);
        root.addView(sink, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        editor = new EditText(this);
        editor.setHint("TEXT FIELD — tap here to compare IME/text behavior");
        editor.setSingleLine(false);
        editor.setMinLines(3);
        editor.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        root.addView(editor, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        LinearLayout buttons = new LinearLayout(this);
        buttons.setOrientation(LinearLayout.HORIZONTAL);

        Button focusSink = new Button(this);
        focusSink.setText("Focus sink");
        focusSink.setOnClickListener(v -> {
            sink.requestFocus();
            append("STATE focus=NON_TEXT_SINK");
        });
        buttons.addView(focusSink, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        Button clear = new Button(this);
        clear.setText("Clear log");
        clear.setOnClickListener(v -> {
            logView.setText("");
            lineCount = 0;
            Log.i(TAG, "CLEAR");
        });
        buttons.addView(clear, new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        root.addView(buttons, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        logView = new TextView(this);
        logView.setTextSize(11f);
        logView.setTextColor(Color.BLACK);
        logView.setTextIsSelectable(true);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(logView);
        root.addView(scroll, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 2f));

        setContentView(root);

        sink.setOnFocusChangeListener((v, hasFocus) ->
                append("STATE sinkFocus=" + hasFocus));
        editor.setOnFocusChangeListener((v, hasFocus) ->
                append("STATE editorFocus=" + hasFocus));

        sink.requestFocus();
        append("START displayId=" + getDisplayIdSafe()
                + " configuration=" + getResources().getConfiguration());
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        append(formatKey(event));
        return super.dispatchKeyEvent(event);
    }

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent event) {
        append(formatMotion("GENERIC", event));
        return super.dispatchGenericMotionEvent(event);
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        append(formatMotion("TOUCH", event));
        return super.dispatchTouchEvent(event);
    }

    private String formatKey(KeyEvent e) {
        InputDevice d = InputDevice.getDevice(e.getDeviceId());
        return String.format(Locale.US,
                "KEY action=%s keyCode=%d(%s) scanCode=%d repeat=%d meta=0x%x " +
                        "deviceId=%d device=%s source=0x%x displayId=%d flags=0x%x unicode=0x%x",
                keyAction(e.getAction()),
                e.getKeyCode(),
                KeyEvent.keyCodeToString(e.getKeyCode()),
                e.getScanCode(),
                e.getRepeatCount(),
                e.getMetaState(),
                e.getDeviceId(),
                d == null ? "null" : d.getName(),
                e.getSource(),
                inputEventDisplayId(e),
                e.getFlags(),
                e.getUnicodeChar());
    }

    private String formatMotion(String kind, MotionEvent e) {
        InputDevice d = InputDevice.getDevice(e.getDeviceId());
        return String.format(Locale.US,
                "%s action=%s deviceId=%d device=%s source=0x%x displayId=%d " +
                        "x=%.2f y=%.2f pressure=%.3f size=%.3f touchMajor=%.2f touchMinor=%.2f " +
                        "relX=%.2f relY=%.2f hscroll=%.2f vscroll=%.2f buttons=0x%x meta=0x%x",
                kind,
                MotionEvent.actionToString(e.getAction()),
                e.getDeviceId(),
                d == null ? "null" : d.getName(),
                e.getSource(),
                inputEventDisplayId(e),
                e.getX(),
                e.getY(),
                e.getPressure(),
                e.getSize(),
                e.getTouchMajor(),
                e.getTouchMinor(),
                e.getAxisValue(MotionEvent.AXIS_RELATIVE_X),
                e.getAxisValue(MotionEvent.AXIS_RELATIVE_Y),
                e.getAxisValue(MotionEvent.AXIS_HSCROLL),
                e.getAxisValue(MotionEvent.AXIS_VSCROLL),
                e.getButtonState(),
                e.getMetaState());
    }

    private String keyAction(int action) {
        return switch (action) {
            case KeyEvent.ACTION_DOWN -> "DOWN";
            case KeyEvent.ACTION_UP -> "UP";
            case KeyEvent.ACTION_MULTIPLE -> "MULTIPLE";
            default -> Integer.toString(action);
        };
    }

    private int getDisplayIdSafe() {
        return getDisplay() == null ? -1 : getDisplay().getDisplayId();
    }

    private int inputEventDisplayId(InputEvent event) {
        try {
            Object value = InputEvent.class.getMethod("getDisplayId").invoke(event);
            return value instanceof Integer ? (Integer) value : -1;
        } catch (ReflectiveOperationException | RuntimeException ignored) {
            // getDisplayId() is not part of every public Android SDK surface.
            // Keep the probe portable and report -1 when the runtime does not expose it.
            return -1;
        }
    }

    private void append(String line) {
        Log.i(TAG, line);
        if (logView == null) {
            return;
        }
        lineCount++;
        if (lineCount > 500) {
            logView.setText("");
            lineCount = 1;
        }
        logView.append(line);
        logView.append("\n");
    }
}
