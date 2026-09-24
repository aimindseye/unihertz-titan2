# Titan 2 Android Input Probe

Small no-privilege app for Tier-1 SableOS input research.

It records, both on screen and in logcat under tag `SableInputProbe`:

- Android `KeyEvent` action, keyCode/name, scanCode, repeat count and meta state;
- input device name / device ID / source;
- event display ID;
- Unicode value seen by Android;
- generic `MotionEvent` data from touchpad/pointer sources;
- normal touch events;
- focused non-text vs editable-text context.

The app intentionally does not remap or consume keys before Android/system policy
gets a chance to handle them.

## Build

```bash
cd tools/input-probe
bash build.sh
```

## Install only on Titan 2

```bash
export TITAN_SERIAL=<titan-adb-serial>
bash install-titan2.sh
```

## Capture logcat

```bash
adb -s "$TITAN_SERIAL" logcat -c
adb -s "$TITAN_SERIAL" logcat -v threadtime -s SableInputProbe:I '*:S'
```

Use the **NON-TEXT EVENT SINK** first. Then repeat selected keys after tapping the
text field. A key that is visible in Linux `getevent` but absent from this app
may be consumed or transformed by Android/framework/vendor policy before app
dispatch.


## Guided Section A mode

For the repeat/chord/text-context portion of Tier-1 Section A, use the guided
mode instead of manually clearing logcat between tests.

1. Build and install the latest probe.
2. Open **Input Probe**.
3. Tap **Start guided A** once.
4. Follow the large instruction shown on the phone.
5. Take as long as needed.
6. After each instruction, tap **Done -> Next**.
7. The app clears only its test text field automatically and keeps a structured
   private session file.

The guided sequence currently covers:

- Q baseline;
- Space then Enter;
- Shift+Q;
- Alt+Q;
- Sym+Q;
- Q auto-repeat;
- Backspace auto-repeat after typing `abcdef`;
- double-Shift then Q.

No host timer and no manual log clearing are required.

When the phone says **GUIDED SECTION A COMPLETE**, pull the private result:

```bash
export TITAN_SERIAL=<titan-adb-serial>
bash tools/input-probe/pull-section-a-guided.sh
```

The puller uses `run-as` on the debug probe and writes the reviewed session
under `artifacts/private/t2-tier1/<timestamp>-section-a-guided/`.

For lockscreen and screen-off context tests use the separate guided host helper:

```bash
bash tools/section-a-context-capture.sh lockscreen
bash tools/section-a-context-capture.sh screenoff
```

That helper presents one instruction at a time and handles all capture filenames
and timing automatically.
