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


## Research script output convention

For any collector or analysis helper that may produce more than a small
terminal page, the full result must be written to a file under the gitignored
private artifact tree, for example:

```text
repo/artifacts/private/t2-tier1/<timestamp>-<analysis>/REPORT.txt
```

Terminal output should be limited to:

- completion status;
- report path;
- line/byte counts;
- a very small human-readable summary when useful.

Do not rely on copying large terminal output into chat because terminal/UI
clipping can silently remove the beginning or middle of evidence. Prefer
attaching the generated report file, or run a subsequent summary helper against
that saved artifact.

A helper may provide an explicit opt-in environment variable such as
`T2_SUMMARY_STDOUT=1` for full stdout when interactive viewing is actually
wanted.
