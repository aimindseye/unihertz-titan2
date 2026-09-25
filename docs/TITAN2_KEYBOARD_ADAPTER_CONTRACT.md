# Titan 2 keyboard adapter contract — draft

Status: **static-stack capture substantially complete; DTBO/module attribution refinement in progress**

This document is the implementation-facing output of the Titan 2 keyboard
research. It should be filled from `t2-keyboard-static-map.sh` evidence, not by
copying current stock UX assignments.

## 1. Hardware / kernel capabilities to preserve

| Function | Stable identity | Driver / parent | Wake capability | Sable requirement |
| --- | --- | --- | --- | --- |
| physical key matrix | `TitanKey`, I2C `6-0058` | exact driver `/sys/bus/i2c/drivers/TitanKey` -> module `aw9523_key`; DTBO sets `matrix_key_enable=1`, `single_key_enable=0`, `led_enable=0`, `gpio_enable=0` | node is `wakeup-source`, but key child sets `wake_up_enable=0`; `wakeup_key=57`, matching the tested Space scan code, so stock screen-off non-wake is statically explained | preserve raw matrix and explicitly choose Sable wake policy |
| keyboard capacitive surface | `touchPad`, I2C `2-0020` | exact driver `/sys/bus/i2c/drivers/synaptics_dsx_pad` -> exact kernel module `/sys/module/synaptics_1403_touch`; DT naming still needs property-level reconciliation | non-waking in InputManager | preserve raw ABS_MT stream independently of Mouse Mode |
| upper programmable side key | scan 249 / Func1 | DT `mt6363keys/home` sets `linux,keycodes=249` and `wakeup-source`; runtime exposes Func1 on `mtk-pmic-keys` | raw path remains active screen-off and stock policy can wake rear display | preserve independent side-key path; implement wake/presentation policy deliberately |
| lower programmable side key | scan 250 / Func2 | DT `mt6363keys/home2` sets `linux,keycodes=250` and `wakeup-source`; runtime also exposes scan 250 through virtual `gpio_key-func`, so the secondary producer/reroute still needs attribution | raw path remains active screen-off; no display wake in tested stock state | preserve independent side-key path; do not copy stock no-op policy |
| hardware volume keys | `gpio-keys` | exact platform driver: `/sys/bus/platform/drivers/gpio-keys`; DT has `volumeup` / `volumedown` children | stock wake semantics can be handled separately | preserve standard Linux key path |
| synthetic helper | `ff_key`, virtual input device | producer still unresolved | non-waking in InputManager | preserve only if required after producer/consumer mapping |
| keyboard illumination | dedicated keypad-light stack | AW9523 parent explicitly sets `led_enable=0`; separate DTBO node `compatible=agold,keypad-led`, `min_brightness=8`, `pwm_ch=2`; vendor DLKM contains `keypad_led.ko` and prior module graph shows `mtk_pwm` dependency | n/a | treat `keypad_led`/PWM as the stock physical keyboard-light backend; expose Sable-owned brightness/timeout policy |

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

The existing V01.00.13 source images add stronger firmware-level evidence:
The decoded DTBO values close several of those questions:

- the AW9523 device is configured as a **matrix-key device** on this board:
  `matrix_key_enable=1`, while `single_key_enable=0`, `led_enable=0`, and
  `gpio_enable=0`. Its LED child descriptions therefore exist in the overlay
  but are disabled for the active Titan 2 configuration.
- the AW9523 node is marked `wakeup-source`, but its key child sets
  `wake_up_enable=0`. The configured `wakeup_key` value is 57, which matches
  the Linux scan code observed for Space. This statically explains why Space /
  the matrix did not wake the handset in the tested stock screen-off state.
- `mt6363keys/home` and `home2` carry Linux keycodes 249 and 250 respectively
  and both are marked `wakeup-source`. Those values line up exactly with the
  Func1/Func2 scan codes already observed at runtime. The physical side-key
  source is therefore in the PMIC key block; the separate runtime
  `gpio_key-func` device for scan 250 should be treated as a secondary
  exposed/synthetic path until its producer is attributed.
- the dedicated `keypad_led` overlay is `compatible=agold,keypad-led`, with
  `min_brightness=8` and `pwm_ch=2`. Because AW9523 LED mode is disabled,
  this is now the strong stock backend for the physical keyboard backlight.
- the Hynitron overlay entries use 410x502 display coordinates, reinforcing
  that those nodes belong to the rear SubScreen touch path rather than the
  keyboard capacitive surface.


- `dtbo.img` contains the AW9523 keyboard/LED overlay, including
  `aw9523b,matrix_key_enable`, `aw9523b,single_key_enable`,
  `aw9523b,wake_up_enable`, `aw9523b,wakeup_key`,
  `aw9523b,default_brightness`, `aw9523b,max_brightness`, and the
  `aw9523b,key` / `aw9523b,led` child namespaces.
- the same DTBO also contains a separate `keypad_led` overlay with
  `min_brightness` and `pwm_ch`. This proves that AW9523 LED configuration
  and the keypad-PWM light node coexist in the stock board overlays; it does not
  yet prove which AW9523 LEDs, if any, are the user-visible keyboard backlight.
- `vendor_boot.img`'s extracted base DTB only surfaced `mt6363keys` and
  `wakeup-source` among the keyboard-focused strings. The AW9523 and
  `keypad_led` configuration is therefore board-overlay evidence from
  `dtbo.img`, not merely a string observed in the base vendor DTB.
- `vendor_dlkm.img` is EROFS and contains the expected keyboard/input modules,
  including `aw9523_key.ko`, `synaptics_1403_touch.ko`,
  `hynitron_touchpad.ko`, `gpio_key.ko`, and `keypad_led.ko`.
  It also contains the literal runtime names `TitanKey` and
  `touchPad/input0`. Attribution of those literals to individual modules
  requires extracting only the small EROFS vendor-DLKM image.
- the prior `debugfs` listing attempt is invalid for these DLKM images because
  they are EROFS, not ext4. Future module extraction must use EROFS-aware tools.

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
- after the Pixel build is no longer resource-sensitive, optionally extract only the 18 MiB V01.00.13 `vendor_dlkm.img` with EROFS-aware tooling to attribute `ff_key` / `gpio_key-func` names to individual modules;
- property-level DT mapping for the `synaptics_dsx_pad` / `synaptics_1403_touch` keyboard touchPad path if needed for the first adapter;
- exact vendor mapping from user-facing keyboard-light slider values to the `keypad_led` PWM backend, only if implementation requires matching stock levels;
- whether vendor key 404 is synthesized by a kernel/input producer or framework code.

If any field remains vendor-private after static inspection, record the boundary
and defer deeper reverse engineering unless it blocks the first Sable adapter.
