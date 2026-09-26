# Titan 2 Tier 2 stock functional baseline worksheet

Status: **active — automated stock runtime captured; manual K/J/I/L + bounded M/D2-lite remain**

The automated Tier 2 collector records framework/HAL/service state. This
worksheet captures user-visible behavior that static dumps cannot prove.

## Automated stock runtime evidence

Automated stock runtime baseline: **CAPTURED 2026-09-26**.

```text
label=stock-pre-n0
build=Titan 2_V01.00.13
incremental=V01.00.13
security_patch=2025-12-05
slot=_a
verified_boot=orange
flash_locked=0
selinux=Enforcing

captured groups:
  core       15 files
  vintf       6 files
  security    6 files
  telephony   6 files
  audio       4 files
  sensors     6 files
  power       7 files
  camera      1 file
  network     2 files
```

The collector was read-only and raw outputs remain private. This proves that the
automated evidence set was captured; it does **not** turn the manual functional
rows below into PASS results.

## Common session envelope

Carry this envelope into every normalized K/J/I/L result. The build/slot/lock
values below come from the saved stock baseline; set `MUTATION_LEVEL` to the
highest mutation level actually used by the manual test session.

```text
BUILD=Titan 2_V01.00.13
ACTIVE_SLOT=a
LOCK_STATE=unlocked
MUTATION_LEVEL=READ_ONLY|USER_SETTING_CHANGE|STATE_CHANGING
PRIVATE_IDENTIFIERS_REDACTED=YES
```

Mutation classification:

- `READ_ONLY`: observation/capture only;
- `USER_SETTING_CHANGE`: normal UI/radio/settings changes such as enabling NFC,
  Wi-Fi, Bluetooth, pairing, fingerprint enrollment, or changing an exposed
  battery setting;
- `STATE_CHANGING`: reboot/bootloader/fastboot/flash/wipe/partition-like state
  changes.

Do not record phone numbers, ICCIDs, IMSIs, APNs containing account data,
Wi-Fi identifiers, peer Bluetooth identifiers, GNSS traces that expose private
locations, or other private identifiers in committed notes.

## Execution order

Use the bounded stock-session order:

```text
1. K — fingerprint / sensors / NFC / GNSS / IR / USB OTG
2. J — audio / haptics (non-call paths)
3. I — telephony / IMS + in-call audio routes
4. L — power / thermal / suspend
```

Collect passive L charging/thermal/idle observations during K/J/I when useful,
but save any bounded sustained-load/throttling check for last. M connectivity
and D2-lite notification/attention are small supporting baselines, not new broad
research tracks.

## K. Fingerprint / sensors / NFC / GNSS / IR / USB OTG

Capture both user-visible behavior **and** the already-saved service/HAL identity
needed to interpret it.

| Test | Result | Notes |
| --- | --- | --- |
| fingerprint HAL/service inventory | PASS | FingerprintProvider sensor 5 present; post-enrollment count=1; 0 HAL deaths observed |
| fingerprint enroll | PASS | one fingerprint enrolled successfully on stock V01.00.13 |
| fingerprint unlock/authenticate | PASS | manual stock authentication/unlock verified |
| sensorservice inventory | PASS | accelerometer, magnetometer, gyroscope, ambient-light and proximity sensors enumerated |
| accelerometer | PASS | manual behavior verified |
| gyroscope | PASS | manual behavior verified |
| compass / magnetometer | PASS | manual behavior verified |
| proximity sensor | PASS | normal voice-call near-ear display-off / away display-on behavior verified in Tier 2 I |
| ambient-light sensor | PASS | manual behavior verified |
| NFC enable / tag read | PASS | stock NFC feature present; tag read verified |
| GNSS first fix | PASS | Factory Test -> YGPS exercised; private coordinates not committed |
| GNSS steady tracking | NOT_TESTED (environment) | indoor test location is not suitable for a reliable sustained-tracking qualification; first-fix/YGPS path is verified |
| IR transmit | PASS | android.hardware.consumerir advertised and manual transmit behavior verified |
| USB OTG storage | PASS | manual OTG storage behavior verified |
| USB OTG HID | PASS | manual OTG HID behavior verified |

The fingerprint `ff_key` gesture helper is already attributed to the FocalTech
kernel stack, but that does not substitute for biometric authentication testing.

Verified stock diagnostic entry on the tested retail unit:

```text
Dialer: *#*#3377#*#*
Factory Test -> YGPS
```

This is now retail-device evidence, not merely a community test lead. Use YGPS
for bounded GNSS observation without committing coordinates or route history.

Minimum normalized K detail:

```text
fingerprint_enroll_unlock=PASS|FAIL
fingerprint_hal_inventory=PASS|FAIL
sensorservice_inventory=PASS|FAIL
accelerometer_behavior=PASS|FAIL
gyro_behavior=PASS|FAIL
compass_behavior=PASS|FAIL
proximity_behavior=PASS|FAIL
ambient_light_behavior=PASS|FAIL
nfc_tag_read=PASS|FAIL|NOT_AVAILABLE
gnss_first_fix=PASS|FAIL
gnss_steady_tracking=PASS|FAIL
ir=PASS|FAIL|NOT_PRESENT|UNKNOWN
usb_otg_storage=PASS|FAIL|NOT_TESTED
usb_otg_hid=PASS|FAIL|NOT_TESTED

TITAN2_TIER2_K_STOCK_BASELINE=PASS|PARTIAL
```

Current normalized K status (2026-09-26):

```text
fingerprint_enroll_unlock=PASS
fingerprint_hal_inventory=PASS
sensorservice_inventory=PASS
accelerometer_behavior=PASS
gyro_behavior=PASS
compass_behavior=PASS
proximity_behavior=PASS
ambient_light_behavior=PASS
nfc_tag_read=PASS
gnss_first_fix=PASS
gnss_steady_tracking=NOT_TESTED_ENVIRONMENT
ir=PASS
usb_otg_storage=PASS
usb_otg_hid=PASS

TITAN2_TIER2_K_STOCK_BASELINE=PARTIAL

BUILD=Titan 2_V01.00.13
ACTIVE_SLOT=a
LOCK_STATE=unlocked
MUTATION_LEVEL=USER_SETTING_CHANGE
PRIVATE_IDENTIFIERS_REDACTED=YES
```

K remains PARTIAL only because sustained GNSS tracking was not run in a suitable RF environment. Proximity behavior is now closed by the Tier 2 I normal-call test. The GNSS gap is an evidence limitation, not a recorded device failure.

## J. Audio / haptics

Test non-call audio here. Actual in-call earpiece/loudspeaker/Bluetooth routing
is recorded under I so the route result is tied to the same carrier/IMS call.

| Test | Result | Notes |
| --- | --- | --- |
| media loudspeaker | PASS | manual playback verified |
| earpiece outside call if meaningfully testable | N/A | in-call receiver behavior is owned by Tier 2 I; stock Factory Test exposes a Receiver check |
| primary microphone recording | PASS | manual recording / stock Factory Test Microphone1 verified |
| secondary/noise-cancel microphone behavior | PASS | stock Factory Test Microphone2 verified |
| camera video audio | PASS | manual camera-video audio verified |
| Bluetooth media | PASS | paired Bluetooth speaker media playback verified |
| USB audio output | PASS | manual USB audio output verified |
| USB audio input | PASS | manual USB audio input verified |
| FM radio path | PASS | manual FM path verified |
| vibration / haptics | PASS | manual behavior / stock Factory Test Vibrator verified |
| route change speaker -> BT -> speaker | PASS | media route transition verified |

Minimum normalized J detail:

```text
media_loudspeaker=PASS|FAIL
primary_microphone=PASS|FAIL
secondary_microphone=PASS|FAIL|NOT_TESTED
camera_video_audio=PASS|FAIL
bluetooth_media=PASS|FAIL|NOT_AVAILABLE|NOT_TESTED
usb_audio_output=PASS|FAIL|NOT_AVAILABLE|NOT_TESTED
usb_audio_input=PASS|FAIL|NOT_AVAILABLE|NOT_TESTED
fm_radio=PASS|FAIL|NOT_AVAILABLE|NOT_TESTED
haptics=PASS|FAIL
media_route_switch=PASS|FAIL|NOT_AVAILABLE|NOT_TESTED

TITAN2_TIER2_J_STOCK_BASELINE=PASS|PARTIAL
```

Current normalized J status (2026-09-26):

```text
media_loudspeaker=PASS
primary_microphone=PASS
secondary_microphone=PASS
camera_video_audio=PASS
bluetooth_media=PASS
usb_audio_output=PASS
usb_audio_input=PASS
fm_radio=PASS
haptics=PASS
media_route_switch=PASS

TITAN2_TIER2_J_STOCK_BASELINE=PASS

BUILD=Titan 2_V01.00.13
ACTIVE_SLOT=a
LOCK_STATE=unlocked
MUTATION_LEVEL=USER_SETTING_CHANGE
PRIVATE_IDENTIFIERS_REDACTED=YES
```

Stock diagnostic compatibility evidence: dialing `*#*#3377#*#*` opens the
retail Factory Test suite. Its Single Test surface exposes dedicated checks for
Vibrator, LoudSpeaker, Receiver, Microphone1, Microphone2, Gravity Sensor, Gyro,
Compass, TouchPanel, TouchPad, LCD, BackLED, keyboard light and other hardware.
SableOS should preserve an equivalent local diagnostic capability; see the
build-target plan for the compatibility requirement.

## I. Telephony / IMS

Context:

```text
date:
stock build:
SIM topology:
carrier(s): <redacted/generalized>
LTE/5G coverage available:
```

| Test | Result | Notes |
| --- | --- | --- |
| SIM recognized | PASS | active SIM recognized |
| mobile data | PASS | manual data connectivity verified |
| LTE registration | PASS | manual LTE registration verified |
| 5G NSA (if available) | NOT_TESTED | mode not qualified in this session |
| 5G SA (if available) | NOT_TESTED | mode not qualified in this session |
| outgoing normal voice call | PASS | normal non-emergency call verified |
| incoming normal voice call | PASS | verified |
| SMS send / receive | PASS | verified |
| MMS send / receive | PASS | verified |
| IMS registered | PASS | verified |
| VoLTE | PASS | verified |
| VoWiFi | PASS | verified |
| dual-SIM data/voice behavior | NOT_TESTED | one-SIM test session |
| call audio earpiece | PASS | verified during normal call |
| call audio loudspeaker | PASS | verified during normal call |
| call audio Bluetooth | PASS | call-capable Bluetooth route verified |

Do **not** use emergency services as a test target.

Minimum normalized I detail:

```text
sim_recognized=PASS|FAIL
mobile_data=PASS|FAIL
lte_registration=PASS|FAIL
5g_nsa=PASS|FAIL|NOT_AVAILABLE
5g_sa=PASS|FAIL|NOT_AVAILABLE
outgoing_voice=PASS|FAIL
incoming_voice=PASS|FAIL
sms=PASS|FAIL
mms=PASS|FAIL
ims_registered=PASS|FAIL
volte=PASS|FAIL
vowifi=PASS|FAIL|NOT_AVAILABLE
dual_sim=PASS|FAIL|NOT_AVAILABLE|NOT_TESTED
call_audio_earpiece=PASS|FAIL
call_audio_loudspeaker=PASS|FAIL
call_audio_bluetooth=PASS|FAIL|NOT_AVAILABLE|NOT_TESTED

TITAN2_TIER2_I_STOCK_BASELINE=PASS|PARTIAL
```

Current normalized I status (2026-09-26):

```text
sim_recognized=PASS
mobile_data=PASS
lte_registration=PASS
5g_nsa=NOT_TESTED
5g_sa=NOT_TESTED
outgoing_voice=PASS
incoming_voice=PASS
sms=PASS
mms=PASS
ims_registered=PASS
volte=PASS
vowifi=PASS
dual_sim=NOT_TESTED
call_audio_earpiece=PASS
call_audio_loudspeaker=PASS
call_audio_bluetooth=PASS
proximity_behavior=PASS

TITAN2_TIER2_I_STOCK_BASELINE=PARTIAL

BUILD=Titan 2_V01.00.13
ACTIVE_SLOT=a
LOCK_STATE=unlocked
MUTATION_LEVEL=USER_SETTING_CHANGE
PRIVATE_IDENTIFIERS_REDACTED=YES
```

The tested single-SIM LTE/IMS path is healthy. I remains PARTIAL because 5G
NSA/SA mode qualification and dual-SIM behavior were not exercised; those are
untested capabilities, not failures.

## L. Power / thermal / suspend

| Test | Result | Notes |
| --- | --- | --- |
| USB charging | PARTIAL | USB power input observed while battery was already at 100%; a below-full charge-rise test is still needed for a clean functional PASS |
| fast/alternate charging mode if exposed | PENDING / N/A | |
| 80% / battery-health policy if exposed | PENDING / N/A | |
| screen-off idle enters expected suspend/deep idle | PASS | phone was unplugged for >20 minutes; post-idle ADB capture was taken after USB reconnect, so current mCharging=true reflects capture-time state. DeviceIdle history records a deep-idle event ~31m55s before capture, consistent with the unplugged interval. |
| expected wake via Power | PENDING | |
| expected wake via Func1 | PASS baseline already characterized | rear-display policy |
| Func2 screen-off behavior | PASS baseline already characterized | active without visible display wake |
| TitanKey screen-off behavior | PASS baseline already characterized | matrix non-waking on stock DT |
| rear SubScreen idle/wake cost observation | PARTIAL | quantify only if needed |
| thermal zones readable | PASS | thermal HAL returned CPU/GPU/NPU/SOC/skin/battery/USB/PA temperatures and thresholds with Thermal Status 0 |
| sustained load throttling behavior | NOT_TESTED | bounded load test intentionally deferred |
| battery / Health HAL service inventory | PASS | saved stock power runtime evidence plus current battery/charging state captured |

Minimum normalized L detail:

```text
usb_charging=PASS|FAIL
alternate_charging=PASS|FAIL|NOT_AVAILABLE
battery_health_policy=PASS|FAIL|NOT_AVAILABLE
suspend_deep_idle=PASS|FAIL
power_button_wake=PASS|FAIL
func1_wake=PASS
func2_screen_off_behavior=PASS
titankey_screen_off_behavior=PASS
thermal_inventory=PASS
bounded_throttling=PASS|FAIL|NOT_TESTED
health_hal_inventory=PASS

TITAN2_TIER2_L_STOCK_BASELINE=PASS|PARTIAL
```

Current normalized L status (2026-09-26):

```text
usb_charging=PENDING_BELOW_FULL_TEST
alternate_charging=PENDING
battery_health_policy=PENDING
suspend_deep_idle=PASS
power_button_wake=PENDING
func1_wake=PASS
func2_screen_off_behavior=PASS
titankey_screen_off_behavior=PASS
thermal_inventory=PASS
bounded_throttling=NOT_TESTED
health_hal_inventory=PASS

TITAN2_TIER2_L_STOCK_BASELINE=PARTIAL

BUILD=Titan 2_V01.00.13
ACTIVE_SLOT=a
LOCK_STATE=unlocked
MUTATION_LEVEL=USER_SETTING_CHANGE
PRIVATE_IDENTIFIERS_REDACTED=YES
```

The phone was unplugged for more than 20 minutes before the post-idle capture. USB power and `mCharging=true` in the saved post-idle dump reflect reconnecting the cable to run ADB. DeviceIdle history contains a deep-idle event about 31m55s before capture, consistent with that unplugged interval, so natural stock deep-idle entry is accepted as PASS. Below-full charging progression remains unqualified because the charging snapshots were taken at 100%.

## M. Wi-Fi / Bluetooth connectivity baseline

This small track fills acceptance-matrix connectivity evidence without expanding
into a broad networking investigation.

| Test | Result | Notes |
| --- | --- | --- |
| Wi-Fi scan | PENDING | redact network identifiers |
| Wi-Fi connect | PENDING | |
| Wi-Fi reconnect after radio toggle / short sleep | PENDING | |
| Wi-Fi roam between known APs if naturally available | PENDING / NOT_TESTED | |
| Bluetooth pair | PENDING | redact peer identifier |
| Bluetooth reconnect | PENDING | |
| Bluetooth media | cross-link J | |
| Bluetooth HID | PENDING / NOT_TESTED | |
| hotspot / tethering | DEFERRED unless needed | |

## D2-lite. Notification / attention baseline

Keep this bounded to normalized user-visible behavior relevant to keyboard-first
notification triage and Sable Hub.

| Capability / behavior | Result | Notes |
| --- | --- | --- |
| lockscreen notification redaction | PENDING | |
| notification dismiss | PENDING | |
| notification reply where supported | PENDING / N/A | |
| keyboard reachability in notification shade | PENDING | |
| notification.output.secondary_display | PENDING | |
| notification.output.haptic | PENDING | |
| notification.output.audio | PENDING | |
| notification.output.keyboard_backlight | PENDING / NOT_PRESENT | |
| notification.output.status_led | PENDING / NOT_PRESENT | |
| notification.output.always_on_display | PENDING / NOT_PRESENT | |

Do not reopen broad SubScreen/vendor-framework reverse engineering for D2-lite.

## Final minimum normalized output

At the end of the K/J/I/L work, emit **at least** this machine-readable summary:

```text
TITAN2_TIER2_K_STOCK_BASELINE=PASS|PARTIAL
TITAN2_TIER2_J_STOCK_BASELINE=PASS|PARTIAL
TITAN2_TIER2_I_STOCK_BASELINE=PASS|PARTIAL
TITAN2_TIER2_L_STOCK_BASELINE=PASS|PARTIAL

BUILD=<stock build>
ACTIVE_SLOT=<a/b>
LOCK_STATE=<locked/unlocked>
MUTATION_LEVEL=READ_ONLY|USER_SETTING_CHANGE|STATE_CHANGING
PRIVATE_IDENTIFIERS_REDACTED=YES
```

Use `PASS` only when all required available tests for that section have
evidence and unavailable capabilities are explicitly classified. Use
`PARTIAL` when required testing remains, a capability is still `UNKNOWN`, or
a test was deliberately left `NOT_TESTED`.

## Stock baseline completion rule

A section is ready for Sable comparison when:

1. the automated Tier 2 runtime baseline for the same build has been saved;
2. the relevant manual rows above are recorded;
3. the normalized section status is emitted;
4. private identifiers have not been copied into committed documentation;
5. any unavailable test is explicitly classified rather than silently treated
   as PASS.
