# Titan 2 keyboard adapter contract — draft

Status: **static-stack capture complete; driver binding refinement in progress**

This document is the implementation-facing output of the Titan 2 keyboard
research. It should be filled from `t2-keyboard-static-map.sh` evidence, not by
copying current stock UX assignments.

## 1. Hardware / kernel capabilities to preserve

| Function | Stable identity | Driver / parent | Wake capability | Sable requirement |
| --- | --- | --- | --- | --- |
| physical key matrix | `TitanKey`, I2C `6-0058` | exact driver `/sys/bus/i2c/drivers/TitanKey` -> exact kernel module `/sys/module/aw9523_key`; DT node `aw9523b_led@58` with `aw9523b,key` child | InputManager says non-waking; runtime matrix goes quiet screen-off | preserve raw key matrix and deliberate suspend behavior |
| keyboard capacitive surface | `touchPad`, I2C `2-0020` | exact driver `/sys/bus/i2c/drivers/synaptics_dsx_pad` -> exact kernel module `/sys/module/synaptics_1403_touch`; DT naming still needs property-level reconciliation | non-waking in InputManager | preserve raw ABS_MT stream independently of Mouse Mode |
| upper programmable side key | `mtk-pmic-keys`, scan 249 | exact platform driver `/sys/bus/platform/drivers/mtk-pmic-keys` -> exact kernel module `/sys/module/mtk_pmic_keys`; DT node `mt6363keys` | raw path remains active screen-off and stock policy can wake rear display | preserve independent side-key path; implement wake policy deliberately |
| lower programmable side key | `gpio_key-func`, scan 250 | virtual input path; exact producer still unresolved | raw path remains active screen-off; no display wake in tested stock state | preserve independent side-key path |
| hardware volume keys | `gpio-keys` | exact platform driver: `/sys/bus/platform/drivers/gpio-keys`; DT has `volumeup` / `volumedown` children | stock wake semantics can be handled separately | preserve standard Linux key path |
| synthetic helper | `ff_key`, virtual input device | producer still unresolved | non-waking in InputManager | preserve only if required after producer/consumer mapping |
| keyboard illumination | vendor keyboard-light stack | DT exposes both top-level `keypad_led` and AW9523 `aw9523b,led` children; loaded `keypad_led` uses MediaTek PWM | n/a | determine which node controls physical keyboard backlight, then expose Sable-owned brightness/timeout policy |

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

The static-map plus targeted driver-inspection pass resolves several previously
inferred boundaries:

- `TitanKey` is rooted at I2C address `6-0058`, bound to the I2C driver
  `TitanKey`, and that driver resolves exactly to kernel module `aw9523_key`.
  DT exposes `aw9523b_led@58` with `aw9523b,key`, `aw9523b,led`, and GPIO
  children.
- `touchPad` is rooted at I2C address `2-0020`, bound to driver
  `synaptics_dsx_pad`, and that driver resolves exactly to kernel module
  `synaptics_1403_touch`. This supersedes the earlier inference from the loaded
  `hynitron_touchpad` module. DT naming still needs property-level inspection.
- `mtk-pmic-keys` is bound to platform driver `mtk-pmic-keys`, which resolves
  exactly to kernel module `mtk_pmic_keys`; DT exposes `mt6363keys` children
  including `power`, `home`, and `home2`.
- standard volume keys are bound through the exact platform driver
  `gpio-keys`; DT exposes `volumeup` and `volumedown`.
- `gpio_key-func` and `ff_key` still appear through virtual sysfs roots, so
  their exact producer remains the main unresolved side-key/synthetic-key
  question.
- keyboard illumination has two concrete DT-level candidates: a top-level
  `keypad_led` node and the AW9523 device's `aw9523b,led` children. The
  loaded `keypad_led` module uses MediaTek PWM, but current evidence does not
  yet prove which path corresponds to the user-visible keyboard backlight.
- `mtk_disp_notify` is referenced by keyboard/touch/light modules in the
  loaded-module graph. That remains consistent with the runtime display-power
  coupling, but exact callback logic is not yet proven.

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

- exact producer for virtual `ff_key` and `gpio_key-func`;
- property-level DT mapping for the `synaptics_dsx_pad` / `synaptics_1403_touch` touchPad path;
- parent wakeup/runtime-PM attributes for the matrix, touchPad and side-key paths;
- distinguish top-level `keypad_led` from AW9523 `aw9523b,led` and identify the user-visible keyboard-backlight control path/value range;
- inspect DT properties for `aw9523b_led@58`, `keypad_led`, touchPad candidates and `mt6363keys`;
- whether vendor key 404 is synthesized by a kernel/input producer or framework code.

If any field remains vendor-private after static inspection, record the boundary
and defer deeper reverse engineering unless it blocks the first Sable adapter.
