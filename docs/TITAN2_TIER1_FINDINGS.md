# Titan 2 Tier 1 SableOS findings

Status: **active — Sections B/C core behavior characterized; Section D ownership in progress**

Stock baseline used for these findings:

- Titan 2 retail handset;
- Android 16 stock build `V01.00.13`;
- security patch `2025-12-05`;
- bootloader unlocked / AVB orange;
- evidence captured on 2026-09-24/25;
- raw dumps, serials and unreviewed diagnostics remain private under
  `artifacts/private/t2-tier1/`.

This document is the normalized/redacted result of issue #13. It intentionally
does not include device serials, modem identifiers, raw logs or private artifact
paths beyond generic locations.

## A. Physical keyboard event pipeline

### Linux/input topology

| Function | Linux input path | Evidence status |
| --- | --- | --- |
| physical keyboard matrix | `TitanKey` / event6 in the tested stock runtime | confirmed |
| keyboard capacitive touch surface | `touchPad` / event7 | confirmed |
| primary touchscreen | `synaptics_dsx_i2c` / event5 | confirmed |
| rear SubScreen touch | `sub_touch` / event4 | confirmed |
| Func1 upper red side key | PMIC key path / scan 249 | confirmed |
| Func2 lower red side key | gpio function-key path / scan 250 | confirmed |
| synthetic navigation helper | `ff_key` / event8 | present; semantics only partly characterized |

`TitanKey` uses `/system/usr/keylayout/TitanKey.kl` and
`/system/usr/keychars/TitanKey.kcm`. Generic programmable mappings include
scan 249 -> `FUNC1`, scan 250 -> `FUNC2`, and scan 253 -> `AGUI_SYM`.

### Android/app behavior

Confirmed Android key mappings include:

| Physical control | Android result |
| --- | --- |
| Space | `KEYCODE_SPACE`, scan 57 |
| Enter | `KEYCODE_ENTER`, scan 28 |
| left Shift | `KEYCODE_SHIFT_LEFT`, scan 42 |
| right Alt | `KEYCODE_ALT_RIGHT`, scan 100 |
| Sym | `KEYCODE_SYM`, scan 253 |

Representative text behavior with the stock IME:

| Input | Focused text result |
| --- | --- |
| Q | `q` |
| Shift+Q | `Q` |
| Alt+Q | `0` |
| Sym+Q | `q`; raw KeyEvent carries `META_SYM_ON` |
| double-Shift then Q | `Q` |
| held Q | normal Android repeat observed |
| held Backspace | repeated `KEYCODE_DEL` clears text |
| Space | inserts a literal space |
| Enter | no text change in the tested multiline field |

The double-Shift result demonstrates that some capitalization/lock state can be
maintained by the IME/text layer above the raw KeyEvent meta state.

### Programmable-key policy

Func1 and Func2 are intercepted by stock framework policy before ordinary app
delivery. The observed ownership chain is:

```text
Linux programmable-key input
  -> vendor InputReader keyCode mapping
  -> vendor PhoneWindowManager / shortcut policy
  -> stock shortcut configuration / SubScreen behavior
```

Func1 has dedicated SubScreen behavior. Func2 uses the general shortcut
configuration path.

### Context behavior

On a real credential/PIN lockscreen the Linux layer remains active for Q, Space,
Enter, Func1 and Func2.

With the displays off:

- Q/Space/Enter from `TitanKey` produced no raw events in the controlled test;
- Func1 remained active and woke the rear SubScreen;
- Func2 remained active but did not wake either display.

The reason the keyboard matrix becomes quiet while screen-off is not yet
attributed to a specific driver/power-policy mechanism.

### Remaining Section A gaps

Before Tier 1 closes, still normalize:

- Back/Home/Recents/navigation behavior;
- camera-shutter candidates;
- keyboard backlight backend/control path (UI owner identified; backend still pending).

## B. Keyboard touch surface / mouse mode

The keyboard touch surface is a separate physical Linux multitouch device
(`touchPad`, event7). Its kernel stream remains ABS_MT-based whether the stock
mouse mode is OFF or ON.

The stock mouse-mode control changes Android secure setting
`accessibility_mouse_keys_enabled`. When enabled, Android creates a separate
virtual `Mouse Keys Virtual Mouse` cursor device associated with the primary
display; disabling the setting removes that virtual device.

Therefore stock mouse mode is a framework Mouse Keys feature layered above the
physical touch surface, not a kernel mode switch of event7.

The separate `touchpad_scroll_assistant` quick-settings feature should not be
conflated with mouse mode.

**Section B core architecture: closed.**

## C. Display and input topology

### Primary display

Normalized stock characteristics:

- native 1440x1440 at 60 Hz;
- runtime logical viewport approximately 1436x1440 with the observed stock
  override;
- density 400 dpi;
- no display cutout;
- rounded-corner geometry present.

### Rear SubScreen

The rear panel is a real separate internal display subsystem:

- 410x502 at 60 Hz;
- physical display port 3;
- stock runtime density 200 dpi (base density 400 dpi);
- separate display group/power behavior;
- private/trusted/secure own-content display semantics;
- does not host arbitrary tasks through the ordinary default-display model.

Do **not** bind the device adapter to transient runtime display ID `2`. Use the
rear display's stable physical/display association (including port and unique
display relationship) and the `sub_touch` association.

### Rear touch lifecycle

`sub_touch` is the rear touchscreen and is display-associated.

Rear OFF:

- InputReader retains the device/display association;
- rear viewport is inactive;
- touch mapper is `DISABLED`;
- `EnableForInactiveViewport=false`;
- controlled tap/swipe produced no raw event4 touch stream.

Rear ON:

- same display association;
- rear viewport becomes active;
- touch mapper becomes `DIRECT`;
- event4 emits normal `BTN_TOUCH` + ABS_MT coordinates;
- raw axes correspond to the 410x502 rear panel.

This is a viewport-lifecycle relationship, not a second generic touchscreen that
should remain dispatch-active while the rear display is off.

### Wake and power coupling

Observed stock behavior:

- single tap on dark rear screen: no wake;
- double tap on dark rear screen: no wake in the tested state;
- Func1: wakes the rear SubScreen;
- turning the main/display power state off while rear is active also leaves the
  rear display non-interactive.

The stock SubScreen package nevertheless declares wake-related actions,
including double-tap/display-wakeup actions, so unsupported/disabled wake
configurations should not be inferred solely from manifest capabilities.

### Rotation

The rear stock UI visibly autorotates to remain upright at normal, 90-degree and
180-degree physical orientations. InputReader keeps the rear touch association
orientation-aware. Some snapshots caught the rear viewport after timeout, so
visual behavior is the authoritative result for those steps.

### Brightness

The stock rear UI exposes an independent rear brightness control. Changing it
visibly changes the rear panel while leaving the main display brightness
unchanged.

The exact storage/backend is not yet identified. Standard
`system/secure/global` settings and readable `/sys/class/backlight` output
did not expose a clean dedicated rear-brightness value in the current capture.

The stock SubScreen launcher has granted
`android.permission.CONTROL_DISPLAY_BRIGHTNESS`, making it a strong ownership
candidate; Section D should attribute the implementation layer without assuming
the UI setting maps directly to ordinary `screen_brightness`.

### Notifications

The stock SubScreen settings expose a per-app notification allow-list.

Controlled test using the installed `org.sableos.research.inputprobe` app:

- app BLOCKED: notification did not wake the rear display and was absent from
  the rear notification UI;
- app ALLOWED: the same app notification woke rear power group 1 with
  application wake reason `sub screen notification wakeup`;
- the stock SubScreen launcher resumed and displayed its notification-details
  UI on the rear display;
- the rear clock/home view showed the configured red notification indicator;
- swiping down on the rear screen revealed the full Input Probe notification.

The stock owner is strongly identified as
`com.agui.subdisplay.launcher`, including its
`.notification.NotificationService`, `.ui.activity.SecondaryLauncher` and
`.ui.activity.NotificationDetailsActivity`.

The allow-list did not appear in the normalized standard Android Settings diff;
it may be held in app-private preferences/database/provider state.

**Section C core topology and user-visible lifecycle: closed.**
Deep implementation/storage attribution continues in Section D.

## D. Stock implementation ownership — current classification

### Keyboard backlight ownership

The stock keyboard-backlight UI is owned by
`com.agui.settings/.touchpad.KeyboardLEDSettingsActivity`, launched from the
Settings flow. The observed stock page exposes:

- `Automatic keyboard light` (environment-dependent automatic mode);
- `Keyboard backlight duration` (observed value: 5 seconds);
- `Backlight brightness` as a slider.

There is no simple keyboard-backlight on/off control in this page. The first
ownership helper therefore treated the minimum slider position as the practical
"off/minimum" endpoint; that test should not be described as a true OFF -> ON
boolean transition.

The stock package/service evidence strongly identifies `com.agui.settings` as
the presentation/configuration owner. During the interaction, vendor log output
showed `AguiUtilsTools: <writeDataToFile>` with changing numeric values,
suggesting the UI writes through a vendor file-backed control path. The current
capture did not expose the target path, and no useful standard
`system/secure/global` Settings diff, `/sys/class/leds` diff, or
`dumpsys lights` diff was produced.

SystemUI has `MONITOR_KEYBOARD_BACKLIGHT`, but the user-facing configuration
screen is the vendor `com.agui.settings` activity. A small targeted
minimum-vs-maximum slider trace is still needed to identify the lower-level
backend and value range.


| Behavior | Current primary classification | Evidence / caveat |
| --- | --- | --- |
| base physical keyboard matrix | kernel/input-driver + Android input configuration | TitanKey input device plus .kl/.kcm; ordinary key delivery does not require a vendor UI app |
| IME text composition / caps state | replaceable app/IME policy | stock default IME is Kika-derived; text-layer state can differ from raw KeyEvent meta |
| Func1/Func2 programmable policy | vendor framework/service capability | vendor InputReader/PhoneWindowManager interception; shortcut configuration app supplies policy |
| Func1 rear wake | vendor framework + SubScreen app lifecycle | power-group wake plus SubScreen launcher action |
| keyboard touch surface | kernel/input-driver capability | separate event7 multitouch device |
| mouse mode | Android framework capability | secure Mouse Keys setting creates/removes virtual mouse |
| rear display lifecycle/presentation | vendor framework + privileged stock SubScreen app | separate display/power group plus `com.agui.subdisplay.launcher` |
| rear touch association | Android input/display framework capability coordinated with SubScreen lifecycle | `sub_touch` follows rear viewport active state |
| rear notifications | replaceable privileged presentation policy atop platform notification service | per-app allow-list + SubScreen NotificationListenerService |
| rear brightness | privileged SubScreen presentation/control; exact backend pending | independent behavior; launcher has `CONTROL_DISPLAY_BRIGHTNESS` |
| keyboard backlight | privileged vendor Settings UI + lower-level backend pending | stock `com.agui.settings/.touchpad.KeyboardLEDSettingsActivity` owns the UI; controls are automatic mode, duration and brightness slider rather than a simple on/off toggle |
| shortcut configuration storage | app/vendor policy; exact storage partly pending | `com.agui.shortcutsettings` identified |
| notification allow-list storage | app-private/vendor policy likely; exact storage pending | standard Settings diff empty |

Static package/service/overlay ownership is now substantially captured. The next targeted Section D step is a minimal keyboard-backlight brightness trace (minimum vs maximum) to identify the lower-level backend. After that, return to the remaining Section A navigation/Home/Back/Recents and shutter-candidate acceptance rows before closing Tier 1.
