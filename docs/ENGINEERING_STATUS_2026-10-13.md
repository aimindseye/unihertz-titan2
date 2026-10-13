# SableOS Titan 2 engineering coordination — 2026-10-13

> Documentation-only review candidate. Does not change this repository's code, accepted images, production status, signing, or deployment authority.

**This repository:** `aimindseye/unihertz-titan2`.

**Role and boundary:** Titan 2 research handoff; old N0 no-flash wording is dated history; do not substitute research for live image qualification.

## Current shared engineering status

- A private Titan 2 Android 16 N1F October 11 experimental runtime was observed booting, but its exact written hybrid-super artifact is not yet cryptographically bound to the session. No October 11 image identity is assumed from a separate offline reference.
- An October 13 full M4 `system_a` write succeeded at the transport layer, but the resulting Android boot failed into Recovery. Flash `OKAY` is **not** boot qualification. The operator reports an unsuccessful factory-reset attempt and subsequent return to fastbootd. No recovery log is available.
- Accepted engineering correction: IMS APK/JAR/XML and any admitted five native libraries belong in **embedded `/system/system_ext` inside a derived `system.img`**, retaining the known `skip_mount.cfg` behavior. A complete parent-matched `super.img` may be assembled **offline only** for metadata/byte-control review, not for automatic physical flashing.
- Targeted acceptance gates remain unresolved: **G1** final installed image composition, **G2** effective APK signing/classpath/privileges/SELinux, **G3** complete native recursive provider/symbol/version and privileged IMS linker-namespace access.
- The October 3 physically booted N1F image is an independently sealed *fallback control*, not interchangeable with the unbound October 11 hybrid.
- The private integration project has retired its earlier October 11/CW1 research PR **#339 (closed, unmerged)** and opened **#342 (draft)** as the sole new evidence-reconciliation/integration planning PR. Those private GitHub links may not be accessible to public visitors.
- Device contact, source mutation, build, partition extraction, reboot, reset, AVB/slot changes, flashing, production signing, PR merge and public release are **not authorized by this status notice**.

## Repository-specific disposition

Titan 2 research handoff; old N0 no-flash wording is dated history; do not substitute research for live image qualification. Preserve prior milestone receipts as dated history. Do not infer Titan 2 physical qualification from historical build/module mock tests, nor alter unrelated device/product branches.

```text
DATE=2026-10-13
TITAN2_M4_IMAGE_WRITE=PASS
TITAN2_M4_ANDROID_BOOT=FAIL_RECOVERY
TITAN2_DEVICE_MODE=FASTBOOTD_OPERATOR_REPORTED
OCT11_EXACT_FLASH_ARTIFACT=UNBOUND
NEW_PRIVATE_ENGINEERING_PR=342_DRAFT
HISTORICAL_PRIVATE_RESEARCH_PR=339_CLOSED_UNMERGED
HOST_EVIDENCE_RECONCILIATION=NEXT
OFFLINE_HYBRID_SUPER=DESIGN_ONLY
G1=OPEN
G2=OPEN_FINAL_IMAGE
G3=OPEN
PUBLIC_BUILD_FLASH=NOT_AUTHORIZED
PRODUCTION_RELEASE=NOT_AUTHORIZED
```

This notice supersedes dated October 12 Titan 2 milestones as the current status, without rewriting or invalidating their underlying evidence.
