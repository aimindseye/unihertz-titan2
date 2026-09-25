# Titan 2 keyboard adapter contract — draft

Status: **core keyboard hardware contract complete; residual synthetic/policy attribution remains**

This document is the implementation-facing output of the Titan 2 keyboard
research. It should be filled from `t2-keyboard-static-map.sh` evidence, not by
copying current stock UX assignments.

## 1. Hardware / kernel capabilities to preserve

| Function | Stable identity | Driver / parent | Wake capability | Sable requirement |
| --- | --- | --- | --- | --- |
| physical key matrix | `TitanKey`, I2C `6-0058` | exact driver `/sys/bus/i2c/drivers/TitanKey` -> module `aw9523_key`; DTBO sets `matrix_key_enable=1`, `single_key_enable=0`, `led_enable=0`, `gpio_enable=0` | node is `wakeup-source`, but key child sets `wake_up_enable=0`; `wakeup_key=57`, matching the tested Space scan code, so stock screen-off non-wake is statically explained | preserve raw matrix and explicitly choose Sable wake policy |
| keyboard capacitive surface | `touchPad`, I2C `2-0020` | exact driver `synaptics_dsx_pad` -> module `synaptics_1403_touch`; live/DTBO node `/soc/i2c@11c22000/cap_tkpd@2a`, `compatible=mediatek,cap_tkpd`, `reg=0x20`, reset GPIO 4, IRQ GPIO 75, power GPIO 59 | non-waking in InputManager | preserve raw ABS_MT stream independently of Mouse Mode |
| upper programmable side key | scan 249 / Func1 | DT `mt6363keys/home` sets `linux,keycodes=249` and `wakeup-source`; runtime exposes Func1 on `mtk-pmic-keys` | raw path remains active screen-off and stock policy can wake rear display | preserve independent side-key path; implement wake/presentation policy deliberately |
| lower programmable side key | `gpio_key-func`, scan 250 / Func2 | exact producer module `gpio_key.ko`; module description `agold gpio key`; DT also contains enabled `agold_gpio_key` (`compatible=mediatek,agold_gpio_key`, GPIO/IRQ 73). PMIC `home2` independently advertises keycode 250 but is not the observed runtime Func2 event source | raw `gpio_key-func` path remains active screen-off; module registers a wakeup source; stock policy does not visibly wake a display | preserve the `gpio_key.ko` side-key path and choose Sable wake/action policy deliberately |
| hardware volume keys | `gpio-keys` | exact platform driver: `/sys/bus/platform/drivers/gpio-keys`; DT has `volumeup` / `volumedown` children | stock wake semantics can be handled separately | preserve standard Linux key path |
| synthetic helper | `ff_key`, virtual input device | live event source is virtual (`/sys/devices/virtual`) with KEY_ENTER/arrows/KEY_POWER/KEY_BACK/scan249 capabilities. No exact `ff_key` string owner was found in vendor/system_ext/product/system, vendor/system/odm DLKM, or the decompressed GKI boot kernel | non-waking in InputManager | preserve only if a downstream consumer requires it; continue attribution through vendor-boot ramdisks and uinput/native producers |
| keyboard illumination | dedicated keypad-light stack | AW9523 parent sets `led_enable=0`; DTBO `compatible=agold,keypad-led`, `min_brightness=8`, `pwm_ch=2`; `keypad_led.ko` is the PWM driver. Live platform device is `/sys/devices/platform/keypad_led`, driver `keypad-led`, attribute `/sys/devices/platform/keypad_led/keyled_brightness`. Driver disassembly shows decimal input, effective clamp to 0..100, zero=off/nonzero=on, then `set_pwm_duty`; shell domain cannot read/stat the current value | n/a | use a Sable-owned 0..100 brightness API over the keypad PWM backend; document the low-level PWM mapping separately |

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
  `synaptics_1403_touch`. Its live firmware-node link resolves to
  `/soc/i2c@11c22000/cap_tkpd@2a`; DTBO decodes that node as
  `compatible=mediatek,cap_tkpd`, `reg=0x20`, reset GPIO 4, IRQ GPIO 75 and
  power GPIO 59. The node name's `@2a` suffix is therefore not the runtime I2C
  address; use `reg=0x20` / live `2-0020` as the authoritative address. This
  supersedes the Hynitron inference; the Hynitron 410x502 nodes are rear
  SubScreen touch candidates.
- `mtk-pmic-keys` is bound to platform driver `mtk-pmic-keys`, which resolves
  exactly to kernel module `mtk_pmic_keys`; DT exposes `mt6363keys` children
  including `power`, `home`, and `home2`.
- standard volume keys are bound through the exact platform driver
  `gpio-keys`; DT exposes `volumeup` and `volumedown`.
- `gpio_key-func` is produced by `gpio_key.ko`; its module strings include the
  exact input-device name and wakeup-source plumbing. The enabled
  `agold_gpio_key` DT node is the matching board-level GPIO-key candidate.
  `ff_key` remains unresolved and was not found as an exact input name in any
  extracted vendor-DLKM module.
- keyboard illumination is owned by `keypad_led.ko`, a dedicated `Keypad LED
  PWM Driver` depending on `mtk-pwm` and `mtk_disp_notify`; it exports
  `keyled_brightness`. AW9523 LED mode is disabled by DT on this board.
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
  and both are marked `wakeup-source`. Runtime confirms Func1 through the
  PMIC path. For Func2, the later EROFS/module pass supersedes the earlier PMIC
  inference: `gpio_key.ko` contains the exact runtime input name
  `gpio_key-func` and wakeup-source code, matching the enabled
  `agold_gpio_key` DT node. Treat PMIC `home2=250` as a parallel advertised
  capability, not as the proven runtime Func2 producer.
- the dedicated `keypad_led` overlay is `compatible=agold,keypad-led`, with
  `min_brightness=8` and `pwm_ch=2`. `keypad_led.ko` confirms this backend:
  description `Keypad LED PWM Driver`, dependencies `mtk-pwm,mtk_disp_notify`,
  and exported sysfs attribute `keyled_brightness`. Because AW9523 LED mode is
  disabled, this is the stock physical keyboard-backlight path.
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
- EROFS extraction of `vendor_dlkm.img` attributes the active names directly:
  `aw9523_key.ko` contains `TitanKey`; `synaptics_1403_touch.ko` contains
  `synaptics_dsx_pad`, `touchPad`, and `touchPad/input0`; and `gpio_key.ko`
  contains `gpio_key-func`. `hynitron_touchpad.ko` also contains generic
  `touchPad` strings, but the live I2C binding proves that the active keyboard
  surface is `synaptics_1403_touch`, not Hynitron.
- the prior `debugfs` attempt was invalid because DLKM images are EROFS. The
  corrected EROFS extraction completed successfully.

The final live closeout also established:

- the live keypad-light platform device is `/sys/devices/platform/keypad_led`,
  bound to platform driver `keypad-led`, with the exact sysfs attribute
  `keyled_brightness`. A parallel misc device exists at
  `/sys/class/misc/keypad_led`. Stock shell SELinux/DAC prevents reading or
  even fully statting the platform attribute, so the current numeric value is
  not available from an unprivileged ADB shell.
- `dumpsys input` still enumerates `ff_key`, `touchPad`, `TitanKey`, and
  `gpio_key-func`. The earlier all-`not-found` sysfs-name result was a
  collector/read-permission artifact, not disappearance of the devices.
- no exact `ff_key` owner was found in vendor-DLKM modules, and the bounded
  system/odm-DLKM search also produced no attribution. Deeper built-in-kernel
  and vendor userspace/framework searches are appropriate now that resource
  constraints are gone.
- the commented `# key 404 "KEY_FIRST"` in `Generic.kl` is the normal Linux
  input scan-code namespace and must not be conflated with the vendor Android
  KeyEvent value observed during keyboard-surface gesture testing.

The deep offline pass further established:

- `ff_key` is present live as a virtual keyboard-class input device with
  KEY_ENTER, directional arrows, KEY_POWER, KEY_BACK and scan 249
  capabilities. Its EventHub/sysfs root is virtual. No literal `ff_key`
  ownership was found in the extracted `vendor`, `system_ext`, `product`,
  or `system` filesystems, in the extracted vendor/system/odm DLKM modules,
  or in the decompressed GKI `boot.img` kernel. The remaining likely
  locations are vendor-boot ramdisk code/modules or a dynamically named
  userspace/uinput-style producer.
- the live global setting `agui_keyboard_background_light=1` exists, but this
  is a policy setting and must not be equated with the instantaneous PWM level.
- `keyled_brightness_store` parses a decimal unsigned value, clamps values at
  100, records on/off as zero versus nonzero, and calls `set_pwm_duty`.
  `keyled_brightness_show` returns the driver's cached brightness field.
  Therefore the driver-facing effective brightness domain is 0..100 even
  though the current numeric value remains unreadable from the stock shell
  domain.
- the only exact extracted-filesystem hits for `keyled_brightness` were the
  vendor init configuration and system_ext SELinux policy. Those files should
  be inspected next to identify the authorized writer/domain and whether an
  existing privileged service can expose the current value without rooting.
- a whole-filesystem DEX integer-404 scan covered hundreds of APK/JAR
  containers but produced many unrelated numeric-404 matches and did not
  isolate the keyboard-gesture producer. Follow-up must require actual
  `KeyEvent`/input-context references rather than merely the integer literal.

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

- producer/consumer role of `ff_key`; the large-filesystem, DLKM and GKI-kernel searches are negative, so inspect vendor-boot ramdisks and uinput/native producers next;
- instantaneous value and low-level PWM scaling behind `/sys/devices/platform/keypad_led/keyled_brightness`; the effective driver input range is now known as 0..100 but stock shell access is denied;
- exact stock UI/policy mapping (`agui_keyboard_background_light`, automatic/timeout/slider) to `keyled_brightness`, if matching stock behavior is desirable;
- vendor key 404 producer; current broad integer scanning is too noisy and must be narrowed to real KeyEvent/input code.

If any field remains vendor-private after static inspection, record the boundary
and defer deeper reverse engineering unless it blocks the first Sable adapter.
