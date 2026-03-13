# ADR-0002: Container orchestration — Compose now, evaluate Quadlet later

**Date:** 2026-03-13
**Status:** Accepted

## Context

All homelab services (Authentik, GitLab, Nextcloud, Jitsi, Caddy, …) run as
Podman containers on the bootc host. Two main options exist for declaring and
managing these containers:

**Podman Compose** uses `compose.yaml` files (compatible with Docker Compose
syntax). Containers are started via `podman-compose` or `docker-compose`. It is
widely documented, most upstream projects ship example Compose files, and the
developer is already familiar with it.

**Quadlet** is the systemd-native approach for Podman. Each container, volume,
network, and pod is declared as a `.container` / `.volume` / `.network` unit
file under `/etc/containers/systemd/`. Systemd manages lifecycle, restarts,
logging, and dependencies. This is the idiomatic approach for bootc/CoreOS
systems: no Compose daemon is needed, units integrate with `journalctl` and
`systemctl` directly, and the definitions can live in the image's
`system_files/` tree.

**Kubernetes (k3s / k8s)** was considered but rejected as over-engineered for a
single-node homelab.

## Decision

Use **Podman Compose** for the initial service rollout. Investigate migrating to
Quadlet in the future.

Rationale:
- The developer is unfamiliar with Quadlet; Compose allows faster iteration and
  quicker recovery when things go wrong.
- Most upstream services (Authentik, GitLab, Nextcloud, Jitsi) publish and
  maintain official Compose examples, reducing adaptation work.
- Compose files are portable and easy to test locally before deploying.

## Alternatives considered

| Option | Reason not chosen now |
|---|---|
| Quadlet | Unfamiliar; steeper initial learning curve |
| k3s / Kubernetes | Over-engineered for a single node |
| Bare RPM packages | Not available for all services; harder to version-pin |

## Consequences

- `podman-compose` must be installed on the host (add to `build.sh`).
- Compose files and their `.env` overrides live under
  `/var/lib/mitie-services/<service>/` on the host (writable `/var`).
- Service definitions are **not** baked into the image — they are deployed
  separately (e.g. via a `just deploy-services` recipe or checked into a
  companion repo).
- No automatic restart on boot without a wrapper systemd unit per service; a
  single `podman-compose up -d` call in a oneshot unit is the practical solution.

## Future: Quadlet investigation

Before migrating, evaluate:
- How Quadlet handles multi-container stacks (pods vs. individual units).
- Whether baking `.container` files into the image makes sense vs. keeping them
  in `/etc/containers/systemd/` as mutable config.
- Whether upstream projects provide Quadlet examples or if manual translation
  from Compose is required.
