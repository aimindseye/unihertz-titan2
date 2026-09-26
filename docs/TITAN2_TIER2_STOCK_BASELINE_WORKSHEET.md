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
| fingerprint HAL/service inventory | PENDING | correlate with saved security/sensor runtime evidence |
| fingerprint enroll | PENDING | |
| fingerprint unlock/authenticate | PENDING | |
| sensorservice inventory | PENDING | correlate with saved sensor runtime evidence |
| accelerometer | PENDING | |
| gyroscope | PENDING | |
| compass / magnetometer | PENDING | |
| proximity sensor | PENDING | |
| ambient-light sensor | PENDING | |
| NFC enable / tag read | PENDING / NOT_AVAILABLE | |
| GNSS first fix | PENDING | redact private location data |
| GNSS steady tracking | PENDING | record behavior, not private route history |
| IR transmit | PENDING / NOT_PRESENT / UNKNOWN | |
| USB OTG storage | PENDING / NOT_TESTED | |
| USB OTG HID | PENDING / NOT_TESTED | |

The fingerprint `ff_key` gesture helper is already attributed to the FocalTech
kernel stack, but that does not substitute for biometric authentication testing.

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

## J. Audio / haptics

Test non-call audio here. Actual in-call earpiece/loudspeaker/Bluetooth routing
is recorded under I so the route result is tied to the same carrier/IMS call.

| Test | Result | Notes |
| --- | --- | --- |
| media loudspeaker | PENDING | |
| earpiece outside call if meaningfully testable | PENDING / N/A | |
| primary microphone recording | PENDING | |
| secondary/noise-cancel microphone behavior | PENDING | |
| camera video audio | PENDING | |
| Bluetooth media | PENDING / N/A | |
| USB audio output | PENDING / N/A | |
| USB audio input | PENDING / N/A | |
| FM radio path | PENDING / N/A | |
| vibration / haptics | PENDING | |
| route change speaker -> BT -> speaker | PENDING / N/A | |

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
| SIM recognized | PENDING | |
| mobile data | PENDING | |
| LTE registration | PENDING | |
| 5G NSA (if available) | PENDING / N/A | |
| 5G SA (if available) | PENDING / N/A | |
| outgoing normal voice call | PENDING | use a normal non-emergency number |
| incoming normal voice call | PENDING | |
| SMS send / receive | PENDING | |
| MMS send / receive | PENDING | |
| IMS registered | PENDING | |
| VoLTE | PENDING | |
| VoWiFi | PENDING / N/A | |
| dual-SIM data/voice behavior | PENDING / N/A | |
| call audio earpiece | PENDING | |
| call audio loudspeaker | PENDING | |
| call audio Bluetooth | PENDING / N/A | |

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

## L. Power / thermal / suspend

| Test | Result | Notes |
| --- | --- | --- |
| USB charging | PENDING | |
| fast/alternate charging mode if exposed | PENDING / N/A | |
| 80% / battery-health policy if exposed | PENDING / N/A | |
| screen-off idle enters expected suspend/deep idle | PENDING | |
| expected wake via Power | PENDING | |
| expected wake via Func1 | PASS baseline already characterized | rear-display policy |
| Func2 screen-off behavior | PASS baseline already characterized | active without visible display wake |
| TitanKey screen-off behavior | PASS baseline already characterized | matrix non-waking on stock DT |
| rear SubScreen idle/wake cost observation | PARTIAL | quantify only if needed |
| thermal zones readable | AUTOMATED CAPTURED | saved power/thermal runtime group |
| sustained load throttling behavior | PENDING | bounded test only |
| battery / Health HAL service inventory | AUTOMATED CAPTURED | saved power runtime group |

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
