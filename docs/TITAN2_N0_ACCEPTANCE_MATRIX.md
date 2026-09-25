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
| Wi-Fi | service state capture pending final stock Tier 2 baseline | **PENDING** | TBD | TBD |
| Bluetooth | service state capture pending final stock Tier 2 baseline | **PENDING** | TBD | TBD |
| cellular data | **PENDING stock functional baseline** | **PENDING** | TBD | TBD |
| voice / IMS | **PENDING stock functional baseline** | **PENDING** | TBD | TBD |
| SMS / MMS | **PENDING stock functional baseline** | **PENDING** | TBD | TBD |
| audio | **PENDING stock functional baseline** | **PENDING** | TBD | TBD |
| camera | **PASS normal-app baseline** — public rear/front, high-res JPEG and rear DNG proven; hidden tele/logical topology known | **PENDING** | likely camera device profile; privileged hidden-camera path only if adopted | TBD |
| fingerprint | **PARTIAL stock baseline** — FocalTech driver/gesture helper ownership known; full auth/HAL behavior capture pending | **PENDING** | TBD | TBD |
| sensors | **PENDING stock functional baseline** | **PENDING** | TBD | TBD |
| NFC | **PENDING stock functional baseline** | **PENDING** | TBD | TBD |
| GNSS | **PENDING stock functional baseline** | **PENDING** | TBD | TBD |
| suspend / power | **PARTIAL stock baseline** — keyboard/SubScreen screen-off/wake behavior known | **PENDING** | likely explicit Titan wake policy | TBD |
| charging / health / thermal | **PENDING stock functional baseline** | **PENDING** | TBD | TBD |

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
