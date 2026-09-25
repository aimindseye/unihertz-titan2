# Titan 2 Tier 2 / first Sable N0 runbook

Status: **ACTIVE — preflight and stock baselines may run; first flash remains gated on the actual Sable artifact + reviewed AVB/LP plan**

Target: Titan 2 stock V01.00.13, unlocked/orange, initially preserving the
stock MediaTek kernel/vendor stack.

This runbook starts where Tier 1 closed. It does not reopen broad keyboard or
SubScreen reverse engineering.

## Safety rules

- Always use explicit Titan serials. The Pixel 7 may be attached at the same
  time.
- Raw reports remain under `artifacts/private/t2-tier2/`.
- Do not commit serials, subscriber/carrier identifiers, network identifiers,
  raw logs, partition images, firmware, or extracted proprietary binaries.
- No script in the preflight set flashes, resizes, wipes, unlocks, relocks, or
  switches slots.
- Do not run a userdata wipe as an implicit part of bring-up. If a wipe is
  eventually required, it must be a separate explicit destructive step.
- Do not flash while a Virtual A/B snapshot update is active.
- Do not infer fastbootd state from the UI. Require
  `getvar is-userspace: yes`.

### Report naming convention

Every Tier 2 helper writes a uniquely named report containing the UTC timestamp
and analysis label, for example:

```text
REPORT-20260925T220000Z-stock-pre-n0-runtime.txt
REPORT-20260925T220500Z-restore-verify.txt
REPORT-20260925T221000Z-bootloader-fastboot-preflight.txt
```

This avoids collisions when reports are downloaded or attached outside their
already-unique artifact directories. Use the exact report path printed by the
script rather than assuming a generic `REPORT.txt` filename.

## Deliverables

| Deliverable | Tool / document | Result |
| --- | --- | --- |
| E restore-source verification | `tools/t2-tier2-restore-verify.sh` | hashes and proves the minimum stock recovery set is reachable |
| E bootloader/fastbootd state | `tools/t2-tier2-fastboot-preflight.sh` | records product, slot, unlocked state, snapshot status, super/logical sizing |
| E candidate Sable artifact manifest | `tools/t2-tier2-n0-artifact-preflight.sh` | hashes image, determines sparse logical size, compares to current system allocation, performs no flash |
| F/G/I–L stock runtime evidence | `tools/t2-tier2-runtime-baseline.sh` | VINTF/HAL, security, telephony, audio, sensors, power, camera, Wi-Fi/Bluetooth dumps |
| N0 smoke evidence | `tools/t2-tier2-n0-smoke.sh` | first-boot/ADB/display/input/service/log evidence after Sable boot |
| F stock-vs-Sable comparison | `tools/t2-tier2-compare-runtime.sh` | per-subsystem diffs between saved runtime captures |
| N0 matrix | `docs/TITAN2_N0_ACCEPTANCE_MATRIX.md` | stock evidence vs first-Sable acceptance tracking |
| manual stock parity worksheet | `docs/TITAN2_TIER2_STOCK_BASELINE_WORKSHEET.md` | functional observations that dumps cannot prove |

## Phase 1 — stock runtime baseline

With Android stock booted:

```bash
cd /srv/data/sable-build/titan2/repo
git pull --ff-only

export TITAN_SERIAL="$Titan2"

bash tools/t2-tier2-runtime-baseline.sh stock-pre-n0
```

The script is read-only and saves the full output rather than flooding the
terminal.

It captures:

- stock identity / build / slot / verified-boot state;
- input and display topology;
- VINTF trees, `lshal`, AIDL/HAL service inventory and APEX inventory;
- SELinux and security-service inventory;
- KeyMint/Gatekeeper/biometric/StrongBox-related feature evidence where exposed;
- telephony/IMS/carrier service state;
- audio policy / AudioFlinger;
- sensors, NFC, GNSS/location, USB and IR feature evidence;
- battery, thermal, idle, wake-source and power data;
- camera service;
- Wi-Fi and Bluetooth service state.

The telephony/network files are especially private.

## Phase 2 — stock restore verification

Run on the host:

```bash
bash tools/t2-tier2-restore-verify.sh
```

Required first-experiment recovery set:

```text
boot
init_boot
vendor_boot
dtbo
vbmeta
vbmeta_system
vbmeta_vendor
system
system_ext
product
vendor
vendor_dlkm
odm_dlkm
system_dlkm
```

The script also inventories important MTK firmware images and verifies the
documented V01.00.13 `init_boot.img` SHA-256.

**Gate E0:** `RESTORE_SET=PASS`.

## Phase 3 — bootloader fastboot state

Move the Titan to bootloader fastboot explicitly. A reboot is state-changing
but non-destructive, so keep it operator-controlled:

```bash
adb -s "$Titan2" reboot bootloader
fastboot devices
```

Set the fastboot serial explicitly and capture:

```bash
export TITAN_FASTBOOT_SERIAL="<Titan fastboot serial>"
bash tools/t2-tier2-fastboot-preflight.sh bootloader
```

Required pass conditions:

- product = `g71v78c2k_dfl_tee` in bootloader fastboot;
- `is-userspace=no`;
- bootloader reports unlocked;
- no active snapshot update.

**Gate E1:** bootloader preflight PASS.

## Phase 4 — fastbootd / LP state

Enter userspace fastboot using the explicit Titan serial:

```bash
fastboot -s "$TITAN_FASTBOOT_SERIAL" reboot fastboot
```

Then:

```bash
bash tools/t2-tier2-fastboot-preflight.sh fastbootd
```

This records `super`, active slot, snapshot state, logical partition sizes and
logical-partition flags.

Fastboot product identity is mode-specific on the tested Titan 2: bootloader
fastboot reports `g71v78c2k_dfl_tee`, while fastbootd reports `Titan_2`. The
preflight script validates the appropriate identity for each mode.

**Gate E2:** fastbootd preflight PASS.

Do not delete COW partitions merely because they are visible. Treat Virtual A/B
snapshot state as authoritative.

Return to stock Android after capture:

```bash
fastboot -s "$TITAN_FASTBOOT_SERIAL" reboot
```

## Phase 5 — Sable system artifact preflight

When the exact first Sable artifact exists:

```bash
bash tools/t2-tier2-n0-artifact-preflight.sh /absolute/path/to/system.img
```

The report records:

- SHA-256;
- host file size and type;
- Android sparse/raw status;
- sparse logical size when applicable;
- current system logical-partition size from the latest fastbootd capture;
- `avbtool info_image` output when available;
- whether the artifact fits the current system allocation.

It performs **no flash**.

**Gate E3:** exact artifact hash known and size decision recorded.

## Phase 6 — final flash plan (intentionally not automated yet)

A flash executor is deliberately withheld until Phases 1–5 are complete.

The final plan must state, before any write:

```text
ARTIFACT_SHA256=
ARTIFACT_LOGICAL_BYTES=
ACTIVE_SLOT=
SNAPSHOT_UPDATE_STATUS=none
SYSTEM_CURRENT_BYTES=
LP_ACTION=direct-flash | reviewed-resize
AVB_ACTION=
USERDATA_POLICY=preserve | explicit-wipe-approved
RESTORE_REPORT=
BOOTLOADER_PREFLIGHT=
FASTBOOTD_PREFLIGHT=
```

At that point review the exact command sequence before creating/running a
write-capable script.

The first experiment should keep the stock kernel/vendor/firmware dependencies
unchanged unless the artifact proves that a different dependency is required.

## Phase 7 — first Sable N0 boot capture

Once the reviewed flash has been performed and ADB becomes available:

```bash
export TITAN_SERIAL="$Titan2"

# Static smoke capture:
bash tools/t2-tier2-n0-smoke.sh

# Optional bounded physical-key event capture:
T2_N0_GETEVENT_SECONDS=25 bash tools/t2-tier2-n0-smoke.sh

# Full subsystem baseline, same schema as stock:
bash tools/t2-tier2-runtime-baseline.sh sable-n0
```

During the optional `getevent` window press:

```text
Q
Space
Enter
Shift
Alt
Sym
Func1
Func2
```

Do not make the first N0 success criterion "everything works." The first
milestone is:

1. userspace boot completes;
2. ADB works;
3. primary display works;
4. TitanKey appears and produces input;
5. touchPad appears;
6. rear display state can be characterized;
7. then triage HAL/service and peripheral differences.

## Phase 8 — stock vs Sable compatibility diff

After both runtime captures exist:

```bash
bash tools/t2-tier2-compare-runtime.sh \
  /path/to/stock-pre-n0-runtime \
  /path/to/sable-n0-runtime
```

The saved diffs are the basis for Tier 2 F and the acceptance matrix.

## Tier 2 manual baselines

Service dumps do not prove user-visible functionality. Before claiming stock
parity, complete the manual worksheet for:

- telephony/IMS;
- audio and routing;
- fingerprint/sensors/NFC/GNSS/IR/USB OTG;
- charging/suspend/thermal behavior.

Do not call emergency services as a test.

## Stop / recovery conditions

Stop and recover instead of stacking more changes if any of these occurs:

- target identity is ambiguous;
- restore verification fails;
- fastboot mode is not the requested mode;
- bootloader unexpectedly reports locked;
- snapshot-update state is not `none`;
- the artifact hash or size differs from the reviewed plan;
- LP sizing requires an unreviewed resize/delete operation;
- the first boot cannot reach ADB and there is no bounded reason to continue.

The recovery path uses the verified stock image set from the restore report;
exact restore commands should match the partitions actually modified by the
first experiment.
