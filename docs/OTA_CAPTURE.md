# US OTA Capture

**Status:** CLOSED  
**Observed handset:** US retail Titan 2 on `Titan 2_V01.00.13-20260210`  
**Offered target:** `Titan 2_V01.00.14-20260422`

## Result

The US handset's live OEM firmware-update path is **not Google Drive**.

Observed flow:

```text
com.agui.update
    -> ADUPS FOTA metadata service
    -> en-US / other channel
    -> VersionBean.deltaurl
    -> cloudflare.mayitek.com
    -> update.zip
```

Google Drive is relevant as a separate full-firmware distribution/archive path; it was not observed as the transport used by the stock US FOTA transaction.

## Distinguishing the two update UIs

Android's generic System Update activity resolves through Google Play Services:

```text
com.google.android.gms/.update.SystemUpdateActivity
```

The Titan 2 OEM updater is separate:

```text
package:   com.agui.update
activity:  com.agui.update/.GoogleOtaClient
APK:       /product/app/FotaApp/FotaApp.apk
overlay:   /product/overlay/FotaOverlay/FotaOverlay.apk
```

The class name `GoogleOtaClient` is misleading: APK analysis and live metadata show an AGUI/ADUPS FOTA implementation.

## FOTA properties

Stock properties included:

```text
ro.fota.app      = 5
ro.fota.battery  = 30
ro.fota.device   = Titan 2
ro.fota.oem      = agold_mt6878_16.0
ro.fota.platform = mt6878_16.0
ro.fota.type     = phone
ro.fota.version  = Titan 2_V01.00.13-20260210
```

## Metadata service

APK analysis found the ADUPS FOTA API:

```text
https://fota5p.adups.com
https://fota5p.adups.cn
/otainter-5.0/fota5/
detectSchedule.do
fullDetectSchedule.do
```

The cached FOTA `VersionBean` carries the actual package URL in `deltaurl`.

The observed target package was delivered from:

```text
cloudflare.mayitek.com
```

The full raw URL is deliberately not published. Its query string contained a per-device identifier.

## Offered update

The stock UI offered:

```text
source: Titan 2_V01.00.13-20260210
target: Titan 2_V01.00.14-20260422
displayed size: 876.29 MB
release date: 2026-04-22
security patch: 2026-03-05
```

The downloaded package is:

```text
bytes:  918861152
SHA256: 0b42b4d7a8f518335b5dee6aa03dc24e7265130544769aff0f8299e7d163c2dd
MD5:    62a626204ecf55be13cbc589f855a3d5
```

The UI's 876.29 figure corresponds to approximately 876.29 MiB even though the UI labels it MB.

## OTA structure

The package is a signed Android A/B OTA:

```text
ota-type=AB
pre-build=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.13:user/release-keys
post-build=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys
post-sdk-level=36
post-security-patch-level=2026-03-05
```

Top-level ZIP members:

```text
META-INF/com/android/metadata
META-INF/com/android/metadata.pb
apex_info.pb
care_map.pb
payload.bin
payload_properties.txt
META-INF/com/android/otacert
```

The payload is version 2, minor version 8, and is an incremental/delta payload requiring the V01.00.13 source images.

## Hidden FOTA diagnostic UI

Tapping the **System Update title** in the OEM updater opens a built-in diagnostic dialog.

Observed controls:

```text
DOWNLOAD LOG FILE
START LOG CAPTURE
END LOG CAPTURE
```

The first control invokes the updater's export path. It exports private updater state to external app storage, including:

```text
.../Android/data/com.agui.update/files/fota/firmware.txt
```

The exported `firmware.txt` supplied the cached update metadata used to retrieve the package reproducibly.

The raw export can contain device-specific identifiers. It remains private.

## Privacy boundary

Never publish or commit:

- the full `deltaurl`;
- the per-device query parameter;
- IMEI/serial values;
- FCM ID;
- MID or similar device identifiers;
- raw `firmware.txt`;
- unreviewed FOTA logs or screenshots containing identifiers.

Only the redacted host/path pattern, build metadata, package size, and cryptographic hashes belong in this repository.

## Acceptance

The original US OTA question is closed:

1. the actual updater package was identified;
2. the metadata service and delivery host were identified;
3. the exact offered OTA was retrieved from the live metadata;
4. its size, MD5, and SHA-256 matched the FOTA metadata;
5. the US live OTA transport was shown to be ADUPS + Mayitek/Cloudflare rather than Google Drive.

See [FIRMWARE_EQUIVALENCE.md](FIRMWARE_EQUIVALENCE.md) for the US/non-EEA full-firmware equivalence proof.
