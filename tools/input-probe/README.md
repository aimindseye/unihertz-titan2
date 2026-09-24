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
