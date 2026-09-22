# T2-R0 Factory Baseline

**Status:** not yet captured  
**Target handset:** Titan 2, US variant  
**Rule:** collect evidence before modifying the device.

Run:

```bash
./tools/t2-r0-collect.sh snapshot
```

The generated `artifacts/private/` directory is intentionally ignored. Raw diagnostics stay local; only reviewed, redacted observations belong here.

## Capture sessions

| UTC time | Stock build | Collector commit | Notes |
|---|---|---|---|
| pending | pending | pending | Factory handset not yet observed |

## Exact device identity

| Field | Evidence |
|---|---|
| Manufacturer / model | pending |
| Product / device / board | pending |
| SoC / board platform | pending |
| Android release / SDK | pending |
| Build ID / fingerprint | pending |
| Security patch level | pending |
| Kernel | pending |
| Vendor API level | pending |
| Treble | pending |
| A/B / virtual A/B | pending |
| Dynamic partitions | pending |

## Boot / partition architecture

| Field | Evidence |
|---|---|
| Active slot | pending |
| `super` / logical partitions | pending |
| `boot` | pending |
| `init_boot` | pending |
| `vendor_boot` | pending |
| `dtbo` | pending |
| `vbmeta*` | pending |
| Recovery arrangement | pending |
| AVB / verified boot state | pending |
| Bootloader lock state | pending |

## Titan-specific baseline

| Area | Evidence |
|---|---|
| Physical keyboard input devices | pending |
| Keylayout files | pending |
| Primary display | pending |
| Secondary display | pending |
| Touch | pending |
| Fingerprint | pending |
| Camera / audio / sensors | defer unless needed for R0 |
| Modem / IMS | defer unless needed for R0 |

## Stock OTA / firmware

| Field | Evidence |
|---|---|
| Region/build channel | pending |
| Current stock version | pending |
| Updater package/service | pending |
| Update metadata endpoint | pending |
| OTA download host | pending |
| OTA filename / build mapping | pending |
| Google Drive involved for US variant? | **unproven** |

Use [OTA_CAPTURE.md](OTA_CAPTURE.md) for the first observation pass.

## R0 completion

R0 is complete only when the factory state is documented well enough to proceed to firmware preservation and recovery work without relying on guesses.
