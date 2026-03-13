# ADR-0006: Persistent data storage — use /var for now, dedicated partition deferred

**Date:** 2026-03-13
**Status:** Accepted

## Context

Reflashing the server (installing a new bootc image via ISO) wipes the root
filesystem. Container volumes with persistent data (databases, file storage,
git repos, …) must survive reflashes to avoid data loss.

On a bootc/CoreOS system, `/var` is a **separate, writable OSTree stateroot**
that is preserved across `bootc upgrade` operations. However, a full ISO
reinstall (`clearpart --all`) wipes `/var` along with everything else.

Options considered:

**Use `/var/lib/containers/volumes/` as-is** — Podman stores named volumes here
by default. Data survives `bootc upgrade` but not a full reflash. Acceptable
for initial setup; recovery from reflash requires restoring from backup.

**Dedicated data partition** — add a separate partition (e.g. `/dev/nvme0n1p4`)
that is formatted once and mounted at `/var/lib/mitie-data/` or similar. The
kickstart `clearpart` directive excludes this partition. Container volumes are
bind-mounted from this partition. Data survives both `bootc upgrade` and
reflash.

**External NAS / network storage** — mount an NFS/SMB share for persistent
data. No single-machine dependency, but adds network latency and another
failure point. Over-engineered for now.

**S3-compatible object storage** — for some services (e.g. GitLab object
storage, Nextcloud primary storage). Possible future enhancement.

## Decision

**Defer** the dedicated data partition. Use **`/var/lib/containers/volumes/`**
(Podman default) for all persistent container data for now.

Rationale:
- The partition layout change requires modifying `disk_config/iso.toml` and the
  Anaconda kickstart, and testing that the partition is correctly excluded from
  `clearpart`. This is non-trivial work.
- For initial service rollout, the priority is getting services running. Data
  loss risk during setup is low (no production data yet).
- A backup strategy (e.g. restic to S3 or another host) should be implemented
  regardless of partition layout.

## Consequences

- A full reflash currently requires restoring all service data from backup.
- Before implementing the dedicated partition, establish a backup strategy.
- When the dedicated partition is implemented, update `disk_config/iso.toml`
  to add the partition and exclude it from `clearpart`, and update Compose
  volume definitions to use bind mounts to the dedicated path.

## Future implementation sketch

```
# disk_config/iso.toml kickstart additions:
part /boot/efi --fstype=efi  --size=600
part /boot      --fstype=ext4 --size=1024
part /          --fstype=btrfs --grow
part /var/lib/mitie-data --fstype=ext4 --size=51200 --ondisk=nvme0n1 --noformat --nopart  # preserve
```

The `--noformat --nopart` flags (or equivalent) tell Anaconda not to touch an
existing partition. Container Compose files would then use:

```yaml
volumes:
  db_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /var/lib/mitie-data/postgres
```
