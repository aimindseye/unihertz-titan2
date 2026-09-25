# Titan 2 Tier 1 SableOS capture runbook

**Scope:** execute Tier 1 sections A–D of
`TITAN_FAMILY_SABLEOS_RESEARCH_CHECKLIST.md` on the current Titan 2 stock
baseline before the first SableOS image experiment.

Issue: #13.

Raw evidence stays private under `artifacts/private/t2-tier1/`.

## Safety rules

- Always set `TITAN_SERIAL` explicitly.
- The collector verifies that the selected ADB target reports model `Titan 2`.
- The collector is read-only. It does not toggle mouse mode, SubScreen settings,
  rotation, lock state or screen power.
- Change requested UI states manually, then run a labeled state/event capture.
- Do not publish raw settings, dumpsys output, serials, modem identifiers or
  unreviewed vendor diagnostics.
- Do not use the Pixel 7 during these tests.

## Phase 0 — static baseline

From the repository root:

```bash
export TITAN_SERIAL="$Titan2"

bash tools/t2-tier1-collect.sh baseline
```

The baseline captures:

- evidence metadata: build, incremental, SPL, slot, AVB/lock state, collector
  commit and host/ADB versions;
- `/proc/bus/input/devices`;
- `getevent -lp`;
- `dumpsys input`;
- `dumpsys input_method`;
- readable `.kl`, `.kcm` and `.idc` files under system/vendor/odm/product;
- IME/package candidates;
- input/display-related settings;
- display and WindowManager inventories;
- SurfaceFlinger display inventory;
- overlays, services, packages and runtime owner candidates.

This is the first required capture.

## Phase 1 — identify keyboard and touch/pointer input devices

After the baseline, inspect locally:

```bash
CAP="$(find artifacts/private/t2-tier1 -maxdepth 1 -type d -name '*T*Z' | sort | tail -1)"

printf '\n=== /proc input device names + handlers ===\n'
grep -E '^(N: Name=|H: Handlers=|I: Bus=)' "$CAP/proc-input-devices.txt"

printf '\n=== getevent device blocks ===\n'
grep -E '^add device|^  name:|KEY \(|REL \(|ABS \(' "$CAP/getevent-capabilities.txt"

printf '\n=== candidate package/IME owners ===\n'
cat "$CAP/package-candidates.txt"

printf '\n=== display headline ===\n'
grep -Ei 'DisplayDeviceInfo|DisplayInfo|mDisplayId|uniqueId|modeId|real|density|rotation|cutout|rounded|address|FLAG_'   "$CAP/dumpsys-display.txt"   "$CAP/dumpsys-window-displays.txt"   "$CAP/surfaceflinger-display-id.txt"   | head -n 250
```

Share only this reviewed output initially. If it contains anything sensitive, redact it
before posting.

The goal is to identify:

- physical keyboard event device;
- capacitive keyboard/pointer device if separate;
- main touchscreen input device;
- rear SubScreen touch input device if present;
- primary and rear display identities.

## Phase 2 — raw keyboard event matrix

Use one labeled event capture per controlled test. Twelve seconds is usually
enough.

Example:

```bash
bash tools/t2-tier1-collect.sh events key-q-base 8
bash tools/t2-tier1-collect.sh events key-q-shift 8
bash tools/t2-tier1-collect.sh events key-q-alt 8
bash tools/t2-tier1-collect.sh events key-q-fnsym 8
```

Do not press unrelated keys during a capture.

Build the matrix in this order:

1. Space;
2. Enter;
3. Back/Escape candidate;
4. left/right Shift;
5. Alt;
6. Fn/Sym;
7. D-pad/navigation keys;
8. side-mounted Func1 and Func2 programmable buttons;
9. Home/Back/Recents candidates;
10. camera-compatible shutter candidates;
11. keyboard-backlight keys/gestures;
12. representative alpha and number keys.

For each important key, later repeat:

- base press/release;
- Shift;
- Alt;
- Fn/Sym;
- long press;
- auto-repeat;
- relevant two-key chord.

Linux events alone do **not** close checklist section A. After the physical
scancode map is known, add/run an Android input probe to capture KeyEvent
keyCode/meta state, MotionEvent axes and focused-text/non-text behavior.

## Phase 3 — mouse mode OFF vs ON

Put the phone into stock mouse mode **OFF** manually, then run:

```bash
bash tools/t2-tier1-collect.sh state mouse-off
bash tools/t2-tier1-collect.sh events mouse-off-slide 12
bash tools/t2-tier1-collect.sh events mouse-off-tap 8
```

Enable stock mouse mode manually and repeat:

```bash
bash tools/t2-tier1-collect.sh state mouse-on
bash tools/t2-tier1-collect.sh events mouse-on-slide 12
bash tools/t2-tier1-collect.sh events mouse-on-tap 8
```

The comparison should answer whether mouse mode:

- changes the same Linux input device;
- enables a second input device;
- changes REL/ABS axes;
- produces mouse buttons;
- leaves Linux events unchanged, implying higher-layer synthesis.

Do not attribute ownership to the stock IME until the event evidence supports it.

## Phase 4 — lockscreen / screen-off / app-context behavior

Once the key identity is known, repeat only the important keys under:

- unlocked non-text application;
- focused text field;
- lockscreen;
- screen off / wake test.

Screen-off and lockscreen tests change device state manually but the collector
remains observational.

Record whether the physical key:

- wakes the device;
- reaches Android after wake;
- is consumed by keyguard;
- behaves differently in a text editor vs non-text application.

## Phase 5 — primary display and rear SubScreen

For the Titan 2 rear display, prefer the guided helper first:

```bash
export TITAN_SERIAL="$Titan2"
bash tools/section-c-subscreen-capture.sh
```

It walks through rear-display OFF/ON state, single-tap and double-tap wake tests,
Func1 wake, rear touch/swipe, and main/rear screen coupling. The event windows
are open-ended: press Enter to start, perform the requested action, then press
Enter again to stop. There is no countdown timer.

Capture a normal primary-display state first:

```bash
bash tools/t2-tier1-collect.sh state display-primary-normal
```

For the rear SubScreen, create labeled state/event captures for each stock state
that can be reached safely:

```bash
bash tools/t2-tier1-collect.sh state subscreen-enabled
bash tools/t2-tier1-collect.sh events subscreen-touch 12
```

If the stock UI permits disabling the rear display, capture that state separately:

```bash
bash tools/t2-tier1-collect.sh state subscreen-disabled
bash tools/t2-tier1-collect.sh events subscreen-disabled-touch 12
```

For rear notification presentation, use the guided helper after the core
SubScreen lifecycle capture:

```bash
export TITAN_SERIAL="$Titan2"
bash tools/section-c-rear-notifications.sh
```

It keeps the overall rear-notification feature enabled, asks the operator to
set the installed Input Probe app BLOCKED then ALLOWED in the stock per-app
allow-list, posts the same app-owned local notification in each phase, records
rear wake/presentation, and captures private settings/package/service evidence.

Characterize, without assuming a display ID:

- display ID/type/unique ID;
- resolution, density and modes;
- touch association;
- natural orientation and rotation;
- brightness ownership;
- wake/double-tap behavior;
- screen-on/off coupling;
- app-launch/display restrictions;
- notification presentation;
- security restrictions;
- whether touch/input remains live when display output is disabled.

## Phase 6 — ownership classification

Start with the normalized findings in `docs/TITAN2_TIER1_FINDINGS.md`, then run
the ownership helper:

```bash
export TITAN_SERIAL="$Titan2"
bash tools/section-d-ownership-capture.sh
```

The helper captures static package/service/overlay ownership for the known
keyboard/SubScreen candidates and then guides a keyboard-backlight minimum ->
higher comparison using the actual stock brightness slider. For the cleaner
backend trace, use `tools/section-d-keyboard-backlight-trace.sh`; current stock
evidence shows the feature is vendor-owned and is not exposed through Android's
normal KbdBacklightController/Lights HAL surface.


Use the baseline package/service/overlay evidence plus targeted package dumps.

For every candidate owner, capture only after its package/service name is known:

```bash
adb -s "$TITAN_SERIAL" shell dumpsys package <package.name>   > "artifacts/private/t2-tier1/<local-private-path>.txt"
```

Classify each behavior into exactly one primary bucket:

```text
kernel/input-driver capability
vendor framework/service capability to preserve
replaceable stock app/IME policy
Sable-owned presentation behavior
```

Target behaviors:

- Func1 / Func2 programmable side buttons;
- keyboard remapping;
- mouse mode;
- shortcuts;
- keyboard backlight;
- programmable Func1/Func2 buttons;
- SubScreen lifecycle/input/security;
- Kika integration.

## Phase 7 — remaining navigation and camera-shutter candidates

After Sections B-D core work, use the guided remaining-keys helper:

```bash
export TITAN_SERIAL="$Titan2"
bash tools/section-a-nav-shutter-capture.sh
```

It keeps each capture isolated and records Linux events, Input Probe delivery,
focused-task changes and operator-visible behavior for Back/Home/Recents
candidates, navigation/cursor candidates and stock-Camera shutter candidates.
Printed labels are treated only as physical prompts; Android semantics are
assigned from captured evidence.

## Section A completion requirement

Section A is complete only after a normalized table can connect:

```text
Linux device
  -> scan code / EV_KEY
  -> .kl mapping
  -> Android KeyEvent keyCode/meta state
  -> .kcm / IME behavior
  -> focused app behavior
```

for the important Titan 2 keys and context variants.

## Section B completion requirement

Section B is complete when mouse/touch-surface behavior is attributable to a
specific platform layer with evidence from OFF/ON raw events plus Android
MotionEvent behavior.

## Section C completion requirement

Section C is complete when primary and rear-display topology can be represented
without hard-coded transient display IDs and the touch associations are known.

## Section D completion requirement

Section D is complete when removing/replacing an app or IME can be reasoned about
without accidentally removing the only owner of a hardware feature.

## After Tier 1

Do not jump directly to flashing.

Next checklist work is:

1. finish restore/deployment contract recapture;
2. normalize VINTF/HAL baseline;
3. complete AVB/security ownership inventory;
4. finish N0 hardware/runtime baseline areas;
5. populate the acceptance matrix;
6. only then choose the first bounded SableOS artifact/flash experiment.
