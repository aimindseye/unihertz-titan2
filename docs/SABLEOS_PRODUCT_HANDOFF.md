# SableOS product handoff

This repository records Titan 2 device evidence. SableOS product implementation must consume that evidence through explicit capability gates rather than assuming every stock manual feature is automatically portable.

## Design / implementation references

```text
PLATFORM_SABLE_PR_31=Toolbox / Hardware Utilities / Remote / Radio UX
PLATFORM_SABLE_PR_32=Private Space / Dual Apps / Work Profile / App Lock / Secure Vault UX
PLATFORM_SABLE_PR_33=Sub-screen / Shortcut Keys / Keyboard Gestures UX
PLATFORM_SABLE_PR_34=Mobile Manager / App Controls / Student Mode UX
PLATFORM_SABLE_PR_35=Connectivity / OTG / NFC / Cast / Compatibility UX
PLATFORM_SABLE_PR_36=Mobile Manager Network Authority Clarification
AIMINDSEYE_SABLEOS_HANDOFF=docs/TITAN2_MANUAL_PRODUCT_HANDOFF.md
```

## Network Manager rule

Titan 2 Mobile Manager research mentions per-app cellular/WLAN style controls, but SableOS implementation must not duplicate the already implemented Panther/R9 Settings-owned Sable Network Manager.

```text
MOBILE_MANAGER_REUSES_SABLE_NETWORK_MANAGER=YES
NETWORK_CONTROL_AUTHORITY=SETTINGS_OWNED_SABLE_NETWORK_MANAGER
NETWORK_CONTROL_IMPLEMENTATION=REVOCABLE_ANDROID_PERMISSION_INTERNET
ALL_NETWORK_TOGGLE=YES
DUPLICATE_NETWORK_BLOCKER=NO
DUPLICATE_NETWORK_POLICY_STORE=NO
PER_APP_CELLULAR_TOGGLE=NO_UNLESS_PLATFORM_ENFORCEMENT_PROVEN
PER_APP_WIFI_TOGGLE=NO_UNLESS_PLATFORM_ENFORCEMENT_PROVEN
```

## Titan 2 capability handoff

```text
TOOLBOX=DEVICE_EVIDENCE_REQUIRED
IR_REMOTE=SUPPORTED_BY_MANUAL_AND_DEVICE_VALIDATION_REQUIRED
FM_RADIO=DO_NOT_ENABLE_UNLESS_TUNER_HAL_VENDOR_PATH_PROVEN
PRIVATE_SPACE=MANUAL_FILE_VAULT_CONCEPT
DUAL_APPS=MANUAL_CLONED_APP_CONCEPT
SUBSCREEN=CURATED_COMPANION_SURFACE_NOT_GENERAL_APP_MIRROR
USB_OTG_NFC_CAST=ANDROID_BOUNDARY_PRESERVED
```

## Cross-device rule

Titan 2 evidence does not prove Titan 2 Elite or Q27 capability.

```text
TITAN2_PROFILE=PRIMARY_EVIDENCE
TITAN2_ELITE_PROFILE=INDEPENDENT_VALIDATION_REQUIRED
Q27_PROFILE=RETAIL_HARDWARE_EVIDENCE_REQUIRED
PROFILE_PASS_INHERITANCE=NO
```
