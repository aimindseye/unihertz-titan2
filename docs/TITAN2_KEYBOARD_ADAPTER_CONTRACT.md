# Titan 2 keyboard adapter contract — draft

Status: **keyboard hardware and vendor input-translation contract complete; only optional stock-UX parity details remain**

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
| fingerprint gesture helper | `ff_key`, virtual input device | attributed to loaded vendor-boot module `focaltech_fp.ko`: the module contains exact runtime name `ff_key`, source path `.../fingerprint/focaltech_fp/ff_core.c`, `ff_register_device`, `register gesture keycode:%d`, and imports `input_allocate_device` / `input_register_device` | non-waking in InputManager | not part of the physical keyboard contract; preserve only if Sable wants FocalTech fingerprint gesture keys |
| keyboard illumination | dedicated keypad-light stack | DTBO `compatible=agold,keypad-led`, `min_brightness=8`, `pwm_ch=2`; live node `/sys/devices/platform/keypad_led/keyled_brightness`; vendor init explicitly `chmod 0666` + `chown system`; SELinux labels it `sysfs_agold`. Driver accepts 0..100, 0 disables PWM, nonzero values below 8 are raised to 8, and 100 is internally capped to 99 before MediaTek PWM programming | n/a | use a Sable-owned 0..100 API; map 0=off and preserve the board minimum nonzero level unless Sable intentionally changes it |

Do not hard-code event numbers.

## 2. Android static translation to reproduce or replace deliberately

| Layer | Stock evidence | Sable decision |
| --- | --- | --- |
| `.kl` | TitanKey-specific layout plus Generic mappings for generic/virtual devices | retain only mappings required by Sable; avoid stock shortcut semantics as hardware truth |
| `.kcm` | TitanKey character map plus Generic fallback on generic devices | preserve base character/modifier behavior; Sable IME policy remains replaceable |
| `.idc` | TitanKey/touch classification where present; InputReader classifies `touchPad` as TOUCHPAD | reproduce device classification needed for correct sources/axes |
| InputReader/vendor extensions | native `android::KeyboardInputMapper::aguiSetProgrammableKey(int)` synthesizes Android key code 404 for a vendor programmable-key path; `KeyboardInputMapper::processKey` and `InputDispatcher::notifyKey` special-case 404, while `PhoneWindowManager` / `AguiKeyboardShortcut` consume it | do not reproduce 404 as a hardware requirement; either map the underlying gesture directly in Sable or reproduce this vendor translation only for stock-behavior compatibility |
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

Vendor-boot inspection produced the first concrete `ff_key` owner candidate:

- `focaltech_fp.ko` contains the exact runtime name `ff_key` adjacent to
  `ff_register_device`, fingerprint-driver strings and
  `register gesture keycode:%d`. This strongly links the virtual `ff_key`
  input device to FocalTech fingerprint gesture reporting rather than to the
  keyboard matrix itself. A final symbol/disassembly pass should verify that
  `ff_register_device` assigns the input-device name and registers the
  observed key capabilities.
- generic `/dev/uinput` permissions and SELinux labels exist in stock
  userspace, but the deep userspace scan found no specific `ff_key` uinput
  creator. That makes the fingerprint kernel-module path substantially more
  plausible than a userspace synthetic-device owner.
- the first strict DEX-404 output is not yet suitable for attribution because
  the home-grown scanner failed to reset the DEX method index between direct
  and virtual method lists and walked code units without respecting
  instruction widths. The scanner has been corrected; prior method labels such
  as `EventLogTags.writeAmDestroyService` must not be treated as evidence.

The final attribution pass closes `ff_key` for keyboard-adapter purposes:

- the live `focaltech_fp` module is loaded, and that exact module contains the
  runtime name `ff_key`, FocalTech fingerprint source paths,
  `ff_register_device`, `register gesture keycode:%d`, and imports
  `input_allocate_device` / `input_register_device`. This is sufficient to
  attribute `ff_key` to the fingerprint gesture stack rather than the Titan
  physical keyboard stack.
- vendor init explicitly sets mode 0666 and owner `system` on
  `/sys/devices/platform/keypad_led/keyled_brightness`; system_ext SELinux
  labels the node `sysfs_agold`. The inability of the ADB shell to read it is
  therefore an SELinux-domain restriction, not a missing node or restrictive
  Unix mode.
- `set_pwm_duty` uses DT `min_brightness=8`: for nonzero requests below the
  minimum, the programmed effective level is raised to 8; an effective value
  at or above 100 is reduced to 99. The driver programs a complementary PWM
  timing pair `effective` and `101-effective`. An original request of zero
  subsequently disables the PWM channel. The public sysfs write path clamps
  input to 0..100.
- corrected DEX scanning places literal Android key code 404 in
  `PhoneWindowManager.interceptKeyBeforeQueueing` and, more specifically, in
  `AguiKeyboardShortcut.keyboardShortcutFunc`. The latter reads
  `KeyEvent.getKeyCode()/getAction()/getDeviceId()`, controls keyboard light,
  and calls `ShortcutInterceptKey`; this establishes a stock **consumer /
  policy intercept** for 404 but does not yet prove where the swipe-generated
  404 KeyEvent is created.

The policy-closeout pass resolves the remaining owner boundaries:

- `keyled_brightness` is labeled `sysfs_agold`. SELinux grants
  `system_server` read/write/ioctl/open access, grants `system_app`
  read/write access, and also permits the MediaTek light HAL domain to read and
  write it. This closes the authorization boundary for the keyboard-light
  backend.
- stock `services.jar` contains
  `com.agui.server.functional.KeyboardLightController`, the literal
  `/sys/devices/platform/keypad_led/keyled_brightness` path, and the
  `agui_keyboard_background_light` setting key. The live system log confirms
  that `AguiFunctionalService` starts a `KeyboardLightController` instance.
  Therefore the stock runtime writer/policy owner is the AGUI controller in
  `system_server`; Settings exposes policy/UI controls rather than owning the
  low-level hardware path.
- `AguiOtherSettings` exposes the keyboard-light
  `BrightnessPreference` and `persist.sys.keyboard_light_slide_on`;
  `MtkSettings` references `agui_keyboard_background_light`. These are
  replaceable stock policy surfaces.
- the native input stack closes Android key 404 synthesis:
  `android::KeyboardInputMapper::aguiSetProgrammableKey(int)` explicitly
  loads/returns `0x194` (404), and `KeyboardInputMapper::processKey`
  immediately recognizes that value. Downstream `InputDispatcher::notifyKey`
  also contains a dedicated 404 path. Java-side
  `PhoneWindowManager.interceptKeyBeforeQueueing` and
  `AguiKeyboardShortcut.keyboardShortcutFunc` are therefore consumers of an
  already-synthesized native key event, not the producer.
- the exact string predicate(s) inside `aguiSetProgrammableKey` were not
  decoded in this pass. That detail is optional unless Sable intentionally
  reproduces the stock gesture-to-404 compatibility behavior.

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
- required touchPad device association/classification;
- the `keypad_led` PWM backend itself. Stock `KeyboardLightController` is policy, not a unique hardware owner.

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

## 6. Remaining optional parity details

No remaining item blocks the first Sable keyboard adapter. The hardware owners,
input translation boundary, wake-relevant paths, and keyboard-light backend are
sufficiently mapped for implementation.

Optional follow-up only if stock UX parity is desired:

- instantaneous cached value of `/sys/devices/platform/keypad_led/keyled_brightness` on stock; the node, authorized domains, API range, scaling, and stock `system_server` controller are already known;
- exact Settings/controller mapping for automatic light, timeout, slide-to-light, and slider persistence;
- exact string predicate(s) inside native `KeyboardInputMapper::aguiSetProgrammableKey(int)` that choose the vendor 404 compatibility path.

Defer those details unless implementation testing shows that Sable needs exact
stock behavior rather than direct, cleaner Sable policy.
