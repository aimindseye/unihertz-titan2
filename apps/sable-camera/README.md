# Sable Camera MVP

Normal-app Camera2 implementation for Titan 2 issue #8.

This first backend deliberately uses only standard Camera2 APIs for the proven public-camera paths:

- rear camera: conventional JPEG, 8192×6144 JPEG, 4096×3072 RAW/DNG;
- front camera: conventional JPEG, 6560×4928 JPEG;
- camera 2/3 system-camera access remains deferred.

No MediaTek/AGOLD vendor request is required for the baseline high-resolution modes.

## Build on ai-g732

```bash
cd apps/sable-camera
./build.sh
```

## Install only on Titan 2

```bash
export TITAN_SERIAL=<titan-serial>
./install-titan2.sh
```

The helper refuses to install unless the selected adb serial reports model `Titan 2`.

## Current controls

- Rear / Front camera
- Normal / High JPEG
- JPEG / RAW mode (RAW only when the selected camera advertises it)
- Shutter button
- Enter, Space, D-pad Center, or Camera hardware key triggers shutter

Captured files are written through MediaStore under `DCIM/SableCamera`.

This branch is an MVP. Telephoto/logical-camera privilege, MediaTek vendor features, computational modes, and cross-device profiles come later.
