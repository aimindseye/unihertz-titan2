# Titan 2 N0 acceptance matrix

Status: **stock evidence partially populated; all first-Sable N0 results pending**

This matrix is the working acceptance record for Tier 2 bring-up. "Stock"
means the documented Titan 2 V01.00.13 baseline. "First Sable N0" remains
unproven until an actual Sable artifact is deployed.

| Area | Stock evidence | First Sable N0 | Device adapter needed | Common Sable change needed |
| --- | --- | --- | --- | --- |
| boot / ADB | **PASS baseline** — stock boots, ADB works, unlocked/orange state documented | **PENDING** | TBD after first boot | TBD |
| display / primary touch | **PASS baseline** — 1440x1440 primary display, touch/input topology characterized | **PENDING** | likely Titan display/input profile only if generic stack misclassifies | TBD |
| physical keyboard | **PASS baseline** — TitanKey matrix, KL/KCM, modifiers/repeat, side-key ownership and wake boundaries mapped | **PENDING** | **YES** — Titan keyboard profile / explicit wake and side-key policy | only if common input abstractions cannot represent hardware cleanly |
| keyboard pointer / touch surface | **PASS baseline** — separate Synaptics ABS_MT touchPad; stock Mouse Keys is framework policy | **PENDING** | **YES** — classify/preserve touchPad independently | TBD |
| IME / text entry | **PASS baseline** — base character/modifier behavior known; Kika-specific composition is replaceable | **PENDING** | device keymap/KCM may be needed; Kika dependency must not be required | TBD |
| rear SubScreen | **PASS baseline** — 410x502 display, rear touch, lifecycle, wake, rotation, brightness independence and security/group behavior mapped | **PENDING** | **YES** — Titan-specific secondary-display/presentation profile | TBD |
| Wi-Fi | **AUTOMATED CAPTURED** — final stock runtime network/service state saved; functional behavior not promoted to PASS by this capture alone | **PENDING** | TBD | TBD |
| Bluetooth | **AUTOMATED CAPTURED** — final stock runtime network/service state saved; functional behavior not promoted to PASS by this capture alone | **PENDING** | TBD | TBD |
| cellular data | **PASS tested LTE baseline** — SIM recognized, mobile data and LTE registration verified; 5G NSA/SA modes not qualified in this session | **PENDING** | TBD | TBD |
| voice / IMS | **PASS tested single-SIM baseline** — incoming/outgoing voice, IMS, VoLTE, VoWiFi and earpiece/loudspeaker/Bluetooth call routes verified; dual-SIM not tested | **PENDING** | TBD | TBD |
| SMS / MMS | **PASS stock baseline** — SMS and MMS send/receive verified | **PENDING** | TBD | TBD |
| audio | **PASS stock non-call baseline** — loudspeaker, microphones, camera-video audio, Bluetooth media/route switching, USB audio input/output, FM and haptics verified; in-call routes remain tracked with telephony/IMS | **PENDING** | TBD | TBD |
| camera | **PASS normal-app baseline** — public rear/front, high-res JPEG and rear DNG proven; hidden tele/logical topology known | **PENDING** | likely camera device profile; privileged hidden-camera path only if adopted | TBD |
| fingerprint | **PASS stock baseline** — FocalTech ownership known; FingerprintProvider sensor 5 present; enrollment and manual unlock/authentication verified; 0 HAL deaths observed in captured state | **PENDING** | TBD | TBD |
| sensors | **PASS tested stock baseline** — inventory plus accelerometer, gyroscope, compass, ambient-light and normal-call proximity behavior verified | **PENDING** | TBD | TBD |
| NFC | **PASS stock baseline** — NFC features advertised and manual tag-read behavior verified | **PENDING** | TBD | TBD |
| GNSS | **PARTIAL** — stock Factory Test/YGPS path verified and first fix recorded; sustained steady-tracking interval remains pending | **PENDING** | TBD | TBD |
| suspend / power | **PARTIAL** — keyboard/SubScreen wake behavior known; Doze/auto-suspend path visible, but latest idle capture remained USB-powered so natural unplugged deep idle is still unqualified | **PENDING** | likely explicit Titan wake policy | TBD |
| charging / health / thermal | **PARTIAL** — thermal HAL/threshold inventory and Health/battery state captured cleanly; below-full charging progression, alternate charging, battery-health policy and bounded throttling remain unqualified | **PENDING** | TBD | TBD |

## N0 minimum success gate

The first N0 experiment is successful enough to continue if all of the
following are true:

- userspace reaches `sys.boot_completed=1`;
- ADB is reachable through the explicitly selected Titan;
- the primary display produces usable output;
- primary touch remains usable;
- `TitanKey` is enumerated and basic key events are observable;
- `touchPad` is enumerated;
- there is a bounded recovery path back to stock.

Rear SubScreen, fingerprint, camera, audio, modem/IMS and sensor parity do not
all need to be fixed before declaring the first userspace boot successful.
They become subsequent N0 parity work.

## Evidence rule

Every First Sable N0 PASS must point to a saved private capture or a normalized
committed conclusion. Do not upgrade a row based only on "looks okay."
