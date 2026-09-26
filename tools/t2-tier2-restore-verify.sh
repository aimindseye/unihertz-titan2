#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EQ_ROOT="${T2_EQ_ROOT:-/srv/data/sable-build/titan2/artifacts/stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier2/$STAMP-restore-verify"
REPORT="$OUT/REPORT-${STAMP}-restore-verify.txt"
HASHES="$OUT/RESTORE_SHA256SUMS.txt"
mkdir -p "$OUT"
: > "$HASHES"

SEARCH_DIRS=(
  "$EQ_ROOT/TEE13-source"
  "$EQ_ROOT/TEE13-small-source"
  "$EQ_ROOT/TEE13-large-source"
)

# Minimum set required to recover the initial Sable system/framework experiment.
REQUIRED=(
  boot.img init_boot.img vendor_boot.img dtbo.img
  vbmeta.img vbmeta_system.img vbmeta_vendor.img
  system.img system_ext.img product.img vendor.img
  vendor_dlkm.img odm_dlkm.img system_dlkm.img
)

# Important firmware partitions that should remain reachable even though the
# first Sable experiment is not expected to modify them.
FIRMWARE=(
  lk.img preloader_raw.img tee.img modem.img
  apusys.img ccu.img connsys_bt.img connsys_gnss.img connsys_wifi.img
  dpm.img gpueb.img gz.img logo.img mcf_ota.img mcupm.img
  pi_img.img scp.img spmfw.img sspm.img vcp.img
)

find_image() {
  local name="$1" d p
  for d in "${SEARCH_DIRS[@]}"; do
    p="$d/$name"
    if [[ -f "$p" ]]; then printf '%s\n' "$p"; return 0; fi
  done
  return 1
}

missing=0
{
  echo "Titan 2 stock restore verification"
  echo "timestamp_utc=$STAMP"
  echo "eq_root=$EQ_ROOT"
  echo
  echo "===== REQUIRED RECOVERY SET ====="
  for name in "${REQUIRED[@]}"; do
    if p="$(find_image "$name")"; then
      size="$(stat -c %s "$p")"
      sha="$(sha256sum "$p" | awk '{print $1}')"
      printf 'PASS  %-22s %12s  %s  %s\n' "$name" "$size" "$sha" "$p"
      printf '%s  %s\n' "$sha" "$p" >> "$HASHES"
    else
      printf 'MISS  %s\n' "$name"
      missing=1
    fi
  done

  echo
  echo "===== IMPORTANT STOCK FIRMWARE ====="
  for name in "${FIRMWARE[@]}"; do
    if p="$(find_image "$name")"; then
      size="$(stat -c %s "$p")"
      sha="$(sha256sum "$p" | awk '{print $1}')"
      printf 'PASS  %-22s %12s  %s  %s\n' "$name" "$size" "$sha" "$p"
      printf '%s  %s\n' "$sha" "$p" >> "$HASHES"
    else
      printf 'INFO  not present in reconstructed search set: %s\n' "$name"
    fi
  done

  echo
  echo "===== KNOWN BASELINE CHECK ====="
  if p="$(find_image init_boot.img)"; then
    actual="$(sha256sum "$p" | awk '{print $1}')"
    expected="aa2d07bfb03b87401cedef7c318c59cb286b02eb47a1309ee0f2561a6141b223"
    if [[ "$actual" == "$expected" ]]; then
      echo "PASS V01.00.13 init_boot.img matches documented SHA-256"
    else
      echo "FAIL init_boot.img SHA mismatch"
      echo "expected=$expected"
      echo "actual=$actual"
      missing=1
    fi
  fi

  echo
  echo "===== RESULT ====="
  if (( missing == 0 )); then
    echo "RESTORE_SET=PASS"
    echo "The minimum first-experiment restore image set is reachable and hashed."
  else
    echo "RESTORE_SET=FAIL"
    echo "Do not flash a non-stock image until missing/mismatched restore artifacts are resolved."
  fi
} > "$REPORT"

sort -u "$HASHES" -o "$HASHES" 2>/dev/null || true
(
  cd "$OUT"
  sha256sum "$(basename "$REPORT")" RESTORE_SHA256SUMS.txt > SHA256SUMS
)

echo "Restore verification written:"
echo "  $REPORT"
echo "  $HASHES"
echo "  result=$([[ $missing -eq 0 ]] && echo PASS || echo FAIL)"
exit "$missing"
