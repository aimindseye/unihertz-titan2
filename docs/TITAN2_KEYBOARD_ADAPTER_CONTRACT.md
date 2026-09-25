# Titan 2 keyboard adapter contract — draft

Status: **static-stack capture complete; driver binding refinement in progress**

This document is the implementation-facing output of the Titan 2 keyboard
research. It should be filled from `t2-keyboard-static-map.sh` evidence, not by
copying current stock UX assignments.

## 1. Hardware / kernel capabilities to preserve

| Function | Stable identity | Driver / parent | Wake capability | Sable requirement |
| --- | --- | --- | --- | --- |
| physical key matrix | `TitanKey`, I2C `6-0058` | `aw9523_key` is the strong loaded-module candidate; exact driver symlink still to confirm | InputManager says non-waking; runtime matrix goes quiet screen-off | preserve raw key matrix and deliberate suspend behavior |
| keyboard capacitive surface | `touchPad`, I2C `2-0020` | `hynitron_touchpad` is the strong loaded-module candidate; exact bind still to confirm | non-waking in InputManager | preserve raw ABS_MT stream independently of Mouse Mode |
| upper programmable side key | `mtk-pmic-keys`, scan 249 | MediaTek PMIC/SPMI path; loaded module `mtk_pmic_keys` | raw path remains active screen-off and stock policy can wake rear display | preserve independent side-key path; implement wake policy deliberately |
| lower programmable side key | `gpio_key-func`, scan 250 | virtual input path; loaded `gpio_key` is a candidate producer | raw path remains active screen-off; no display wake in tested stock state | preserve independent side-key path |
| synthetic helper | `ff_key`, virtual input device | producer still unresolved | non-waking in InputManager | preserve only if required after producer/consumer mapping |
| keyboard illumination | vendor keyboard-light stack | loaded `keypad_led` with MediaTek PWM dependency | n/a | expose Sable-owned brightness/timeout policy over documented backend |

Do not hard-code event numbers.

## 2. Android static translation to reproduce or replace deliberately

| Layer | Stock evidence | Sable decision |
| --- | --- | --- |
| `.kl` | TitanKey-specific layout plus Generic mappings for generic/virtual devices | retain only mappings required by Sable; avoid stock shortcut semantics as hardware truth |
| `.kcm` | TitanKey character map plus Generic fallback on generic devices | preserve base character/modifier behavior; Sable IME policy remains replaceable |
| `.idc` | TitanKey/touch classification where present; InputReader classifies `touchPad` as TOUCHPAD | reproduce device classification needed for correct sources/axes |
| InputReader/vendor extensions | programmable-key interception and synthetic key 404 are observed above raw input | preserve only hardware-required translation; replace stock shortcut policy |
| wake policy | matrix/touchPad modules and keyboard-light module all reference MediaTek display-notify infrastructure; side-key paths differ | confirm exact driver bindings and wake sysfs, then implement explicit Sable suspend/wake policy |

## 2.1 Static-stack findings from stock V01.00.13

The first static-map pass resolves several previously inferred boundaries:

- `TitanKey` is rooted at I2C address `6-0058`; the loaded out-of-tree
  `aw9523_key` module is the strong driver candidate.
- `touchPad` is rooted at I2C address `2-0020`; the loaded
  `hynitron_touchpad` module is the strong driver candidate.
- `mtk-pmic-keys` is on the MediaTek PMIC/SPMI path and has a matching loaded
  `mtk_pmic_keys` module.
- `gpio_key-func` and `ff_key` appear as virtual-sysfs input devices; their
  exact producers still require one targeted binding/module inspection.
- `keypad_led` is a loaded out-of-tree module, and the loaded-module dependency
  list shows MediaTek PWM used by `keypad_led`. This gives a concrete kernel
  backend candidate for the physical keyboard illumination.
- `mtk_disp_notify` is referenced by `keypad_led`, `hynitron_touchpad`,
  `aw9523_key`, the touchscreen drivers and display stack. That dependency is
  consistent with the runtime observation that the keyboard matrix/touch paths
  change behavior with display power state. It is evidence of a display-state
  integration point, not yet proof of the exact suspend callback logic.

Stock properties also expose the policy split:

- `ro.agui.factory.physical_keyboard_project=yes`;
- `ro.agui.touchpad_function=yes`;
- `persist.sys.touchpad_event_mode=1`;
- `persist.sys.touchpad_forcescroll=no`;
- stock shortcut press properties currently resolve to
  `com.agui.shortcutsettings-NoOperate`;
- the default stock IME is the Kika-derived keyboard service.

Package ownership is likewise separated:

- `com.agui.keyboard` contains the keyboard shortcut UI/executor and has
  keyboard-remapping/layout permissions;
- `com.agui.shortcutsettings` is a privileged shortcut-policy app with event
  injection, power and wake-lock permissions;
- `com.agui.settings` contains `KeyboardGestureActivity` and
  `KeyboardLEDSettingsActivity`;
- `com.agui.spacebarkey` contains a dedicated `SpaceBarFunctionReceiver`.

These packages are stock policy/control surfaces. They must not be confused with
the kernel input devices themselves.

## 3. Vendor-framework capabilities

### Preserve if they are the only hardware owner

- side-key raw input plumbing;
- rear-display wake plumbing tied to Func1 if implemented below replaceable UI;
- any required touchPad device association/classification;
- keyboard-light backend access if only vendor services can drive it.

### Reimplement in Sable policy

- programmable key assignment;
- shortcut routing;
- camera shutter assignment;
- keyboard-light UX;
- optional touch-surface gestures;
- rear-display presentation policy.

## 4. Stock policy that must not define the hardware contract

Do not treat these as intrinsic keyboard behavior:

- Kika text-composition choices;
- user-configurable shortcut assignments;
- launcher-specific Home/Recents outcomes;
- Mouse Mode pointer policy;
- SubScreen notification allow-list;
- vendor synthetic actions whose hardware source can be represented more directly.

## 5. Acceptance criteria for the first Sable adapter

The first keyboard adapter should prove:

- every required physical key produces the expected Linux/Android/Sable action;
- modifiers and repeat are preserved;
- programmable side keys are distinguishable;
- keyboard touch surface remains independently available;
- screen-off wake behavior is deliberate, not accidental;
- keyboard illumination can be controlled through a documented adapter API;
- no dependency on Kika is required for base hardware input;
- stock-app removal does not remove the only owner of a required hardware function.

## 6. Remaining open fields

The first static pass substantially narrowed the unknowns. Next resolve:

- exact sysfs driver symlink/module binding for I2C `6-0058` (`TitanKey`) and `2-0020` (`touchPad`);
- exact producer for virtual `ff_key` and `gpio_key-func`;
- parent wakeup/runtime-PM attributes for the matrix, touchPad and side-key paths;
- the `keypad_led` exposed control node(s) and value range;
- device-tree wake/display-notify properties if exposed;
- whether vendor key 404 is synthesized by a kernel/input producer or framework code.

If any field remains vendor-private after static inspection, record the boundary
and defer deeper reverse engineering unless it blocks the first Sable adapter.
