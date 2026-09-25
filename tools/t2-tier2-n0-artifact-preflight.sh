#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG="${1:-}"
if [[ -z "$IMG" || ! -f "$IMG" ]]; then
  echo "usage: $0 /absolute/path/to/sable-system.img" >&2
  exit 2
fi
IMG="$(readlink -f "$IMG")"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/artifacts/private/t2-tier2/$STAMP-n0-artifact-preflight"
REPORT="$OUT/REPORT.txt"
mkdir -p "$OUT"

sha="$(sha256sum "$IMG" | awk '{print $1}')"
bytes="$(stat -c %s "$IMG")"
desc="$(file -b "$IMG" 2>/dev/null || true)"

read -r sparse logical_bytes block_size total_blocks < <(
python3 - "$IMG" <<'PY'
import struct, sys
p=sys.argv[1]
with open(p,'rb') as f:
    h=f.read(28)
if len(h)>=28 and struct.unpack_from('<I',h,0)[0]==0xed26ff3a:
    _,maj,minv,hdr,chunk,blk,total_blks,total_chunks,checksum=struct.unpack('<I4H4I',h)
    print("yes", blk*total_blks, blk, total_blks)
else:
    import os
    n=os.stat(p).st_size
    print("no", n, 0, 0)
PY
)

LATEST_FB="$(ls -1dt "$ROOT"/artifacts/private/t2-tier2/*-fastbootd-fastboot-preflight 2>/dev/null | head -n1 || true)"
system_bytes=""
if [[ -n "$LATEST_FB" && -f "$LATEST_FB/logical-partitions.txt" ]]; then
  hex="$(grep -A4 -m1 '^===== system_[ab] =====' "$LATEST_FB/logical-partitions.txt" | sed -n -E 's/.*partition-size:system_[ab]:[[:space:]]*(0x[0-9A-Fa-f]+).*/\1/p' | head -n1)"
  if [[ -n "$hex" ]]; then
    system_bytes="$((hex))"
  fi
fi

{
  echo "Titan 2 Sable N0 artifact preflight"
  echo "timestamp_utc=$STAMP"
  echo "image=$IMG"
  echo "sha256=$sha"
  echo "file_bytes=$bytes"
  echo "file_type=$desc"
  echo "android_sparse=$sparse"
  echo "logical_image_bytes=$logical_bytes"
  echo "sparse_block_size=$block_size"
  echo "sparse_total_blocks=$total_blocks"
  echo "latest_fastbootd_preflight=${LATEST_FB:-<none>}"
  echo "current_system_partition_bytes=${system_bytes:-<unknown>}"
  echo
  echo "===== AVBTOOL ====="
  if command -v avbtool >/dev/null 2>&1; then
    avbtool info_image --image "$IMG" 2>&1 || true
  else
    echo "avbtool not found"
  fi
  echo
  echo "===== SIZE DECISION ====="
  if [[ -n "$system_bytes" ]]; then
    if (( logical_bytes <= system_bytes )); then
      echo "SIZE_FIT=YES"
      echo "The image logical size fits the currently reported system logical partition."
      echo "This does NOT authorize flashing; AVB/snapshot strategy still must be explicit."
    else
      echo "SIZE_FIT=NO"
      echo "The image is larger than the currently reported system logical partition."
      echo "A reviewed LP/super reallocation plan is required before flashing."
    fi
  else
    echo "SIZE_FIT=UNKNOWN"
    echo "Run the fastbootd preflight first so current system logical-partition size is recorded."
  fi
  echo
  echo "FLASH_ACTION=NONE"
  echo "This script never flashes or resizes a partition."
} > "$REPORT"

(
  cd "$OUT"
  sha256sum REPORT.txt > SHA256SUMS
)

echo "N0 artifact preflight written:"
echo "  $REPORT"
echo "  sha256=$sha"
echo "  logical_bytes=$logical_bytes"
echo "No flash action was performed."
