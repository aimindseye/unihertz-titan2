# Titan 2 host layout on ai-g732

Status: active canonical layout as of 2026-09-25.

The Titan 2 working set is consolidated on the 3.6 TiB WD_BLACK NVMe mounted at
`/srv/data/sable-build`.

```text
/srv/data/sable-build/titan2/
  repo/       Git working tree for aimindseye/unihertz-titan2
  artifacts/  private stock firmware, OTA captures, reconstruction products,
              research evidence and other non-publishable device data
  deep-work/  large temporary extraction, kernel, DEX and decompilation work
  scratch/    disposable ad-hoc research work
```

Compatibility symlinks:

```text
/srv/data/sable-build/unihertz-titan2
  -> /srv/data/sable-build/titan2/repo

/srv/data/sable-build/artifacts/titan2
  -> /srv/data/sable-build/titan2/artifacts
```

Use the canonical paths in new tooling and documentation. The compatibility
symlinks exist only so historical runbooks, commands and private evidence paths
continue to resolve.

The mounted `/mnt/sable-src-root` and `/mnt/sable-src-data` trees are not
Titan 2 research destinations; they were observed read-only and should not be
used for new Titan 2 writes without a separate storage-health investigation.

## Privacy boundary

Do not commit raw firmware, partition images, extracted proprietary binaries,
device identifiers, or raw private capture trees. Keep them under the canonical
private artifact/deep-work locations above. Commit only scripts, normalized
findings, hashes and reviewed/redacted documentation.
