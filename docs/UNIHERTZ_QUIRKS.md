# Titan 2 / Unihertz Quirks and Lab Notes

This file records small device-specific behaviors that are easy to forget and expensive to rediscover.

## 1. Fastboot text is extremely small

On the Titan 2 display, bootloader-fastboot status and the unlock confirmation UI are rendered as tiny text near the edge of the screen.

The phone can appear to show little more than a normal boot logo or a tiny `FASTBOOT mode...` line even though a confirmation prompt is active.

Do not assume there is no prompt just because it is difficult to read.

## 2. Bootloader unlock has a short auto-reject window

Running:

```bash
fastboot flashing unlock
```

opens a confirmation prompt on the handset.

The observed prompt indicates that the "No" path automatically exits after about five seconds.

If no button is pressed, the bootloader remains locked.

Critically, host-side fastboot can still report:

```text
OKAY
Finished.
```

after the timeout/rejection.

Therefore **never use the host-side OKAY line as proof of unlock success**.

Always verify:

```bash
fastboot getvar unlocked
fastboot getvar secure
```

## 3. Volume Up confirmed unlock on the tested US handset

On the tested US/non-EEA Titan 2, pressing **Volume Up** during the short unlock confirmation window accepted the unlock.

Successful state:

```text
unlocked: yes
secure: no
```

The earlier no-button attempt timed out and left:

```text
unlocked: no
secure: yes
```

Treat the empirically observed Volume Up behavior as authoritative for this handset.

## 4. Unlock resets userdata

The normal bootloader unlock flow triggers the expected Android factory reset/userdata wipe.

The test handset had not been set up, so no valuable user data was at risk.

Any future device should still be treated as destructive-unlock unless its data has been backed up.

## 5. `fastboot boot` is not implemented

The bootloader will accept the image-transfer stage:

```text
Sending 'boot.img' ... OKAY
```

but then fails the temporary boot operation:

```text
Booting ... FAILED (remote: 'unknown command')
```

This does **not** flash the image.

Do not plan a Titan 2 bring-up workflow around RAM-only `fastboot boot`.

## 6. fastbootd works normally

```bash
fastboot reboot fastboot
```

successfully enters userspace fastbootd.

Verify with:

```text
is-userspace: yes
```

The fastbootd screen is otherwise similar to conventional Android devices.

## 7. Dynamic-partition queries need the materialized slot-qualified name

In fastbootd, queries such as:

```text
is-logical:system
partition-size:system
```

failed.

The active logical partition name was:

```text
system_a
```

and similarly for `product_a`, `vendor_a`, `system_ext_a`, and the DLKM partitions.

While slot A was active, the corresponding `*_b` names were not openable through fastbootd even though `lpdump --slot 1` described them.

This is Virtual A/B behavior, not evidence that the device lacks two boot slots.

## 8. COW partitions can exist with no active snapshot update

Fastbootd exposed logical partitions such as:

```text
system_a-cow
product_a-cow
vendor_a-cow
...
```

while:

```text
snapshot-update-status: none
```

Do not infer an in-progress OTA solely from the presence of COW logical partitions, and do not manually erase them as "leftovers" during early bring-up work.

## 9. Bootloader-mode and fastbootd variables differ

Bootloader fastboot initially returned an empty value for some dynamic-partition-oriented variables such as `super-partition-name` and did not resolve bare logical names.

Fastbootd correctly reported:

```text
super-partition-name: super
partition-size:super: 0x240000000
dynamic-partition: true
```

Use fastbootd or `lpdump` for dynamic-partition topology.

## 10. Mac mini USB behavior was cable/path-sensitive

During bootloader enumeration, one USB-C cable/port path on the Mac mini failed to expose the Titan 2 to fastboot. Switching the cable/path immediately resolved the issue.

This was treated as a **host/cable interoperability issue**, not a Titan 2 fastboot limitation.

Before debugging drivers or bootloader state, try:

- a known-good data cable;
- a different physical port;
- avoiding a hub/dock;
- checking whether the OS sees the USB device before debugging fastboot itself.

## 11. Multiple Android devices: always specify the serial

The Titan 2 research host may also have a Pixel connected for SableOS work.

When more than one Android device is present, always use:

```bash
adb -s <titan-serial> ...
fastboot -s <titan-serial> ...
```

Never rely on an unqualified `adb` command when another development handset is attached.

Do not publish the device serial in repository documentation or logs.

## 12. `GoogleOtaClient` is not Google's firmware updater

The Titan OEM FOTA activity is:

```text
com.agui.update/.GoogleOtaClient
```

Despite the class name, live behavior and APK analysis show an AGUI/ADUPS updater.

The generic Android System Update activity resolves separately through Google Play Services.

Do not conflate the two update paths.

## 13. Hidden FOTA diagnostics are behind the System Update title

Tapping the **System Update title** in the OEM updater opens a diagnostic dialog.

Observed buttons:

```text
DOWNLOAD LOG FILE
START LOG CAPTURE
END LOG CAPTURE
```

This is separate from the normal three-dot menu.

The normal overflow menu includes ordinary updater actions such as local update/settings/exit; it is not the debug-entry mechanism.

## 14. "DOWNLOAD LOG FILE" exports sensitive updater metadata

The diagnostic export writes files under the app's external files area, including `firmware.txt`.

That cached metadata includes the OTA `deltaurl`.

The observed URL contained a per-device identifier in its query string.

Treat exported FOTA metadata as private even if the ZIP URL itself looks ordinary.

## 15. The US live OTA path is ADUPS, not Google Drive

Observed live transaction:

```text
AGUI FotaApp
-> ADUPS fota5p metadata
-> en-US/other channel
-> cloudflare.mayitek.com
-> update.zip
```

Google Drive is a separate full-firmware distribution/archive source.

## 16. The displayed OTA "MB" value is effectively MiB

The updater showed approximately:

```text
876.29 MB
```

for a package of:

```text
918861152 bytes
```

which is approximately 876.29 MiB.

Do not use the UI label as a decimal-MB byte count.

## 17. `_tee` is the non-EEA/global lineage used by the US handset

The public Drive labels the branch `None_EEA`; its archive names use `_tee`.

The US retail bootloader reports:

```text
product: g71v78c2k_dfl_tee
```

The firmware-equivalence work further proved the tested US OTA lineage against those non-EEA/`_tee` full images.

## 18. Recovery lives inside `vendor_boot`

The stock `vendor_boot` v4 image contains a vendor ramdisk fragment:

```text
type: 0x2
name: recovery
```

No standalone recovery image was observed in the OTA-managed set.

Recovery planning should therefore account for `vendor_boot`, not assume a conventional `recovery_a/recovery_b` image.

## 19. Root AVB signing key changed between V01.00.13 and V01.00.14

The top-level `vbmeta` key SHA-1 changed across the update even though the subordinate boot/system/vendor chain keys remained stable.

Do not hard-code the assumption that Unihertz uses one top-level AVB signing key for every release.

## 20. Some V01.00.14 vbmeta property strings look stale

V01.00.14 vbmeta contains `com.android.build.*` property strings referencing V01.00.13 and Android-14-era component fingerprints.

Use the signed hash/hashtree descriptors and actual partition hashes for integrity/equivalence work; do not identify image contents solely from those property strings.

## 21. DSU is not exposed on the tested stock firmware

The stock build did not expose a usable Dynamic System Updates shell path:

```text
cmd dynamic_system help
-> No shell command implementation.
```

Relevant GSI/GSID properties were empty and no Dynamic System feature was reported.

Combined with unsupported `fastboot boot`, this means first SableOS experiments must be designed around recoverable flashing rather than temporary boot mechanisms.
