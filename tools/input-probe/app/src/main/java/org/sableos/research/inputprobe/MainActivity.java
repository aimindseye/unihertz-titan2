package org.sableos.research.inputprobe;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.os.SystemClock;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.util.Log;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

public final class MainActivity extends Activity {
    private static final String TAG = "SableInputProbe";
    private static final String GUIDED_FILE = "section-a-guided.tsv";

    private static final String[][] GUIDED_STEPS = {
            {"baseline-q", "Press Q once."},
            {"space-enter", "Press Space once, then Enter once."},
            {"shift-q", "Hold Shift, press Q, release Q, then release Shift."},
            {"alt-q", "Hold Alt, press Q, release Q, then release Alt."},
            {"sym-q", "Hold Sym, press Q, release Q, then release Sym."},
            {"q-repeat", "Hold Q for about 2 seconds, then release it."},
            {"backspace-repeat", "Type abcdef, then hold Backspace for about 2 seconds."},
            {"double-shift-q", "Tap Shift twice, then press Q once."}
    };

    private TextView sink;
    private EditText editor;
    private TextView logView;
    private TextView guideStatus;
    private TextView guidePrompt;
    private Button guideStart;
    private Button guideNext;

    private int lineCount = 0;
    private int guidedIndex = -1;
    private boolean guidedActive = false;
    private boolean suppressTextRecord = false;

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

        guideStatus = new TextView(this);
        guideStatus.setText("GUIDED SECTION A: press Start once. No log clearing or timers.");
        guideStatus.setTextSize(15f);
        guideStatus.setTextColor(Color.BLACK);
        guideStatus.setPadding(0, 8, 0, 4);
        root.addView(guideStatus);

        guidePrompt = new TextView(this);
        guidePrompt.setText("The app will show one test at a time and save the session internally.");
        guidePrompt.setTextSize(18f);
        guidePrompt.setTextColor(Color.BLACK);
        guidePrompt.setBackgroundColor(0xfffff3cd);
        guidePrompt.setPadding(16, 18, 16, 18);
        root.addView(guidePrompt, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        LinearLayout guideButtons = new LinearLayout(this);
        guideButtons.setOrientation(LinearLayout.HORIZONTAL);

        guideStart = new Button(this);
        guideStart.setText("Start guided A");
        guideStart.setOnClickListener(v -> startGuidedSession());
        guideButtons.addView(guideStart, new LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        guideNext = new Button(this);
        guideNext.setText("Done -> Next");
        guideNext.setEnabled(false);
        guideNext.setOnClickListener(v -> nextGuidedStep());
        guideButtons.addView(guideNext, new LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        root.addView(guideButtons);

        editor = new EditText(this);
        editor.setHint("GUIDED TEXT FIELD");
        editor.setSingleLine(false);
        editor.setMinLines(3);
        editor.setTextSize(18f);
        editor.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        root.addView(editor, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        sink = new TextView(this);
        sink.setText("MANUAL NON-TEXT EVENT SINK\nTap here only for ad-hoc tests.");
        sink.setTextSize(14f);
        sink.setTextColor(Color.BLACK);
        sink.setBackgroundColor(0xffdddddd);
        sink.setPadding(12, 14, 12, 14);
        sink.setGravity(Gravity.CENTER);
        sink.setFocusable(true);
        sink.setFocusableInTouchMode(true);
        root.addView(sink, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        LinearLayout manualButtons = new LinearLayout(this);
        manualButtons.setOrientation(LinearLayout.HORIZONTAL);

        Button focusSink = new Button(this);
        focusSink.setText("Focus manual sink");
        focusSink.setOnClickListener(v -> {
            sink.requestFocus();
            append("STATE focus=NON_TEXT_SINK");
        });
        manualButtons.addView(focusSink, new LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        Button clear = new Button(this);
        clear.setText("Clear visible log");
        clear.setOnClickListener(v -> {
            logView.setText("");
            lineCount = 0;
            Log.i(TAG, "CLEAR_VISIBLE_LOG");
        });
        manualButtons.addView(clear, new LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        root.addView(manualButtons);

        logView = new TextView(this);
        logView.setTextSize(10f);
        logView.setTextColor(Color.BLACK);
        logView.setTextIsSelectable(true);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(logView);
        root.addView(scroll, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        setContentView(root);

        sink.setOnFocusChangeListener((v, hasFocus) ->
                append("STATE sinkFocus=" + hasFocus));
        editor.setOnFocusChangeListener((v, hasFocus) -> {
            append("STATE editorFocus=" + hasFocus);
            if (guidedActive) {
                recordGuided("FOCUS\teditor=" + hasFocus);
            }
        });

        editor.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable s) {
                if (guidedActive && !suppressTextRecord) {
                    recordGuided("TEXT\tvalue=" + sanitize(s.toString()));
                }
            }
        });

        sink.requestFocus();
        append("START displayId=" + getDisplayIdSafe()
                + " configuration=" + getResources().getConfiguration());
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        String line = formatKey(event);
        append(line);
        if (guidedActive) {
            recordGuided("KEY\t" + line);
        }
        return super.dispatchKeyEvent(event);
    }

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent event) {
        String line = formatMotion("GENERIC", event);
        append(line);
        if (guidedActive) {
            recordGuided("MOTION\t" + line);
        }
        return super.dispatchGenericMotionEvent(event);
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        append(formatMotion("TOUCH", event));
        return super.dispatchTouchEvent(event);
    }

    private void startGuidedSession() {
        guidedActive = true;
        guidedIndex = 0;
        guideStart.setEnabled(false);
        guideNext.setEnabled(true);
        truncateGuidedFile();
        recordGuided("SESSION_START\tdisplayId=" + getDisplayIdSafe()
                + "\tconfiguration=" + sanitize(getResources().getConfiguration().toString()));
        showGuidedStep();
    }

    private void nextGuidedStep() {
        if (!guidedActive) {
            return;
        }

        recordGuided("STEP_END\tvisibleText=" + sanitize(editor.getText().toString()));

        guidedIndex++;
        if (guidedIndex >= GUIDED_STEPS.length) {
            guidedActive = false;
            guideNext.setEnabled(false);
            guideStart.setEnabled(true);
            guideStatus.setText("GUIDED SECTION A COMPLETE");
            guidePrompt.setText("Done. Run tools/input-probe/pull-section-a-guided.sh on the host.");
            recordGuided("SESSION_END");
            return;
        }

        showGuidedStep();
    }

    private void showGuidedStep() {
        clearEditorWithoutRecording();

        String name = GUIDED_STEPS[guidedIndex][0];
        String prompt = GUIDED_STEPS[guidedIndex][1];

        guideStatus.setText(String.format(Locale.US,
                "GUIDED SECTION A — step %d of %d", guidedIndex + 1, GUIDED_STEPS.length));
        guidePrompt.setText(prompt + "\n\nTake as long as needed. Tap Done -> Next only after finishing.");
        recordGuided("STEP_START\tname=" + name + "\tprompt=" + sanitize(prompt));

        editor.requestFocus();
        editor.setSelection(editor.length());
    }

    private void clearEditorWithoutRecording() {
        suppressTextRecord = true;
        editor.setText("");
        suppressTextRecord = false;
    }

    private String currentStepName() {
        if (!guidedActive || guidedIndex < 0 || guidedIndex >= GUIDED_STEPS.length) {
            return "-";
        }
        return GUIDED_STEPS[guidedIndex][0];
    }

    private void truncateGuidedFile() {
        try (FileOutputStream out = openFileOutput(GUIDED_FILE, MODE_PRIVATE)) {
            out.write("elapsed_ns\tstep\ttype\tdetail\n".getBytes(StandardCharsets.UTF_8));
        } catch (IOException e) {
            Log.e(TAG, "Unable to start guided output", e);
            guideStatus.setText("ERROR: could not create guided output file");
        }
    }

    private void recordGuided(String detail) {
        String row = SystemClock.elapsedRealtimeNanos()
                + "\t" + currentStepName()
                + "\t" + detail + "\n";
        try (FileOutputStream out = openFileOutput(GUIDED_FILE, MODE_APPEND)) {
            out.write(row.getBytes(StandardCharsets.UTF_8));
        } catch (IOException e) {
            Log.e(TAG, "Unable to append guided output", e);
        }
    }

    private String sanitize(String value) {
        return value.replace("\\", "\\\\")
                .replace("\t", "\\t")
                .replace("\r", "\\r")
                .replace("\n", "\\n");
    }

    private String formatKey(KeyEvent e) {
        InputDevice d = InputDevice.getDevice(e.getDeviceId());
        return String.format(Locale.US,
                "action=%s keyCode=%d(%s) scanCode=%d repeat=%d meta=0x%x "
                        + "deviceId=%d device=%s source=0x%x displayId=%d flags=0x%x unicode=0x%x",
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
                "%s action=%s deviceId=%d device=%s source=0x%x displayId=%d "
                        + "x=%.2f y=%.2f pressure=%.3f size=%.3f touchMajor=%.2f touchMinor=%.2f "
                        + "relX=%.2f relY=%.2f hscroll=%.2f vscroll=%.2f buttons=0x%x meta=0x%x",
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
