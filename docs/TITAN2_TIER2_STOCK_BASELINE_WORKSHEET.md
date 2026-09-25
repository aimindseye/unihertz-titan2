# Titan 2 Tier 2 stock functional baseline worksheet

Status: **to be completed before corresponding N0 parity claims**

The automated Tier 2 collector records framework/HAL/service state. This
worksheet captures user-visible behavior that static dumps cannot prove.

Record the date, stock build, active carrier/SIM context where relevant, and
whether a step changed device state. Keep phone numbers, ICCIDs, IMSIs, APNs
containing account data, Wi-Fi identifiers and other private values out of
committed notes.

## I. Telephony / IMS

Context:

```text
date:
stock build:
SIM topology:
carrier(s):
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

## J. Audio / haptics

| Test | Result | Notes |
| --- | --- | --- |
| media loudspeaker | PENDING | |
| earpiece | PENDING | |
| primary microphone recording | PENDING | |
| secondary/noise-cancel microphone behavior | PENDING | |
| camera video audio | PENDING | |
| Bluetooth media | PENDING / N/A | |
| Bluetooth call audio | PENDING / N/A | |
| USB audio output | PENDING / N/A | |
| USB audio input | PENDING / N/A | |
| FM radio path | PENDING / N/A | |
| vibration / haptics | PENDING | |
| route change speaker -> BT -> speaker | PENDING / N/A | |

## K. Fingerprint / sensors / NFC / GNSS / IR / USB OTG

| Test | Result | Notes |
| --- | --- | --- |
| fingerprint enroll | PENDING | |
| fingerprint unlock/authenticate | PENDING | |
| accelerometer | PENDING | |
| gyroscope | PENDING | |
| compass / magnetometer | PENDING | |
| proximity sensor | PENDING | |
| ambient-light sensor | PENDING | |
| NFC enable / tag read | PENDING / N/A | |
| GNSS location fix | PENDING | |
| GNSS accuracy/steady tracking | PENDING | |
| IR transmit | PENDING / N/A | |
| USB OTG host/device detection | PENDING | |

The fingerprint `ff_key` gesture helper is already attributed to the
FocalTech kernel stack, but that does not substitute for biometric
authentication testing.

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
| thermal zones readable | PENDING automated capture | |
| sustained load throttling behavior | PENDING | bounded test only |
| battery / Health HAL service inventory | PENDING automated capture | |

## Stock baseline completion rule

A section is ready for Sable comparison when:

1. the automated Tier 2 runtime baseline for the same build has been saved;
2. the relevant manual rows above are recorded;
3. private identifiers have not been copied into committed documentation;
4. any unavailable test is marked N/A with the reason rather than silently
   treated as PASS.
