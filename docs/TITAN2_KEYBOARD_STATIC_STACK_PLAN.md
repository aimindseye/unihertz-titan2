# Titan 2 keyboard static-stack plan

Status: **next session / read-only**

This plan replaces further broad stock-UX key testing with a static-stack-first
investigation. Runtime tests remain useful only where static evidence cannot
answer a hardware or framework-boundary question.

## Why the methodology changes here

The Tier 1 runtime work has already established the important layer boundaries:

```text
hardware
  -> Linux input device / scan code / ABS stream
  -> Android .kl / .kcm / .idc
  -> InputReader / vendor framework extensions
  -> system policy / configurable stock apps
  -> IME / application
```

Several observed behaviors are configuration-dependent above the Linux input
layer. Therefore another sweep of every configurable stock assignment is not a
good way to define the SableOS hardware contract.

The next goal is to identify the stable implementation contract at each layer,
especially the kernel/sysfs binding and Android static input configuration.

## Tomorrow's first command

From the repository root:

```bash
export TITAN_SERIAL="$Titan2"
bash tools/t2-keyboard-static-map.sh
```

The collector is read-only and writes raw evidence only under
`artifacts/private/t2-tier1/`.

Then run:

```bash
bash tools/t2-keyboard-static-summary.sh
```

The summary helper automatically selects the newest
`*-keyboard-static-map` capture and prints a reviewed subset suitable for
sharing in the research issue.

## Questions to answer

### 1. Kernel/input ownership

For each known input device, identify:

| Function | Known runtime name |
| --- | --- |
| physical key matrix | `TitanKey` |
| keyboard capacitive surface | `touchPad` |
| synthetic navigation/helper | `ff_key` |
| upper programmable side key | PMIC key path |
| lower programmable side key | `gpio_key-func` |
| main hardware keys | `gpio-keys` / `mtk-pmic-keys` |

For each device capture:

- event node;
- sysfs device path;
- driver symlink if exposed;
- subsystem/bus;
- modalias/uevent;
- physical path;
- wakeup/power attributes;
- Linux event capabilities.

Do not assume that the event number is stable across boots.

### 2. Static Android translation

Normalize the exact files that translate Linux input into Android:

- `TitanKey.kl`;
- `TitanKey.kcm`;
- `TitanKey.idc` if present;
- relevant `Generic.kl` entries;
- any vendor/odm/product overlays that supersede those files.

The target output is a table of:

```text
Linux device
  -> Linux code
  -> .kl key name
  -> Android key code / source
  -> .kcm character behavior where applicable
```

### 3. Vendor-framework ownership

Use static package/service/overlay evidence to map:

- Func1/Func2 interception;
- vendor synthetic key 404;
- shortcut policy;
- keyboard-light policy;
- touchPad-to-framework behavior;
- stock IME dependencies.

Classify each behavior as:

```text
kernel/input-driver capability
vendor framework/service capability to preserve
replaceable stock app/IME policy
Sable-owned presentation behavior
```

### 4. Suspend/wake boundary

The runtime tests already showed that the TitanKey matrix becomes quiet while
screen-off whereas the programmable side-key paths remain alive.

Static inspection should now look for evidence of why:

- sysfs wakeup state;
- parent-device power state;
- bound driver/module;
- device-tree wakeup properties if exposed.

Only if static inspection cannot resolve this should another targeted
screen-off runtime test be added.

## Explicit non-goals

Do not spend the next session exhaustively retesting:

- user-configurable shortcut assignments;
- launcher-specific Home/Recents behavior;
- Kika-specific text policy already demonstrated;
- Mouse Mode pointer behavior already closed in Section B;
- notification allow-list behavior already closed in Section C.

Those can be revisited only if they block the SableOS adapter contract.

## Deliverable

Produce `docs/TITAN2_KEYBOARD_ADAPTER_CONTRACT.md` from the static capture with
three layers clearly separated:

1. **must preserve from vendor/kernel**;
2. **must reproduce in the SableOS device adapter/framework**;
3. **stock UX policy that SableOS may replace**.

The contract should avoid transient event numbers, transient display IDs, and
stock-app implementation details unless they are the only owner of a hardware
capability.

## Follow-up after the first static map

The first static capture identified strong kernel-module candidates:

- `TitanKey` at I2C `6-0058` -> `aw9523_key` candidate;
- `touchPad` at I2C `2-0020` -> `hynitron_touchpad` candidate;
- keyboard illumination -> loaded `keypad_led` using MediaTek PWM;
- PMIC side-key path -> loaded `mtk_pmic_keys`;
- display-state integration -> `mtk_disp_notify` referenced by keyboard/touch/light modules.

Resolve the remaining exact bindings and exported control nodes with:

```bash
export TITAN_SERIAL="$Titan2"
bash tools/t2-keyboard-driver-inspect.sh
```

This follow-up remains read-only. It inspects exact bus-driver symlinks, parent
power/wakeup state, module metadata/strings, likely keyboard-light sysfs nodes,
and exposed device-tree candidates. It pulls only the small already-loaded
keyboard-related kernel modules into the existing gitignored private artifact
tree for host-side metadata inspection.


## OTA / firmware pivot

The live-device driver mapping is now sufficient to identify the main keyboard
owners:

- `TitanKey` -> I2C driver `TitanKey` -> kernel module `aw9523_key`;
- `touchPad` -> I2C driver `synaptics_dsx_pad` -> kernel module
  `synaptics_1403_touch`;
- `mtk-pmic-keys` -> kernel module `mtk_pmic_keys`;
- standard `gpio-keys` appears built-in or does not expose a module symlink.

The remaining questions are better answered from the **existing validated
firmware/reconstruction corpus**, not by re-scanning or re-extracting the raw
3.5 GiB archives.

Known private corpus on `ai-g732`:

```text
/srv/data/sable-build/artifacts/titan2/stock-firmware/lichtmetzger-20260920/
  Firmware/Android 16/TEE/
    2026021022_g71v78c2k_dfl_tee.zip
    2026042212_g71v78c2k_dfl_tee.zip
  OTA/Android 16/TEE/
    2026021022_g71v78c2k_dfl_tee-ota.zip
    2026042212_g71v78c2k_dfl_tee-ota.zip

/srv/data/sable-build/artifacts/titan2/stock-firmware/unihertz-device-fota-20260922/
  inspection/bit-equivalence/
```

The repository firmware-equivalence work established that the non-EEA
`_tee` V01.00.13 full images are the exact source expected by the observed US
V01.00.13 -> V01.00.14 incremental OTA, and that the non-EEA V01.00.14 full
images are the exact target for all 34 OTA-managed partitions. The private
`inspection/bit-equivalence` tree was created during that reconstruction /
comparison work and should be reused before touching the raw archives.

For keyboard analysis, first resolve the already-extracted image/subdirectory
names with **shallow directory listings only**. Do not run broad `find`,
`du`, recursive grep, payload extraction, or whole-image `strings` while
another resource-intensive build is active.

Once the exact existing image paths are identified, inspect only the partitions
needed for the keyboard stack:

- `vendor_dlkm` / `system_dlkm` for kernel modules;
- `dtbo`, `vendor_boot`, and any extracted DTB for device-tree properties;
- `vendor`, `system_ext`, and `product` only for targeted vendor
  framework/APK/JAR ownership;
- static `.kl/.kcm/.idc` files if already unpacked.

`tools/t2-ota-keyboard-inspect.sh` remains available for a later isolated
analysis pass, but it should not be pointed at a raw multi-gigabyte OTA while
the Pixel build is resource-sensitive.

Raw OTA images, payloads, extracted partitions and module binaries stay only in
the private artifact tree on `ai-g732`. Commit only normalized conclusions.

