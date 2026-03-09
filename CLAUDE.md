# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A custom [bootc](https://github.com/bootc-dev/bootc) (bootable container) image for a homelab mini-PC server, based on Fedora CoreOS. The OCI image is built via GitHub Actions and published to GHCR. The server runs Cockpit, Netbird, and Podman.

## Commands

All common operations are managed via `just` (requires `just` to be installed):

```bash
just build                  # Build container image with podman
just lint                   # Run shellcheck on all .sh files
just format                 # Run shfmt on all .sh files
just check                  # Check Justfile syntax
just fix                    # Fix Justfile syntax

just build-qcow2            # Build QCOW2 VM image (calls just build first)
just build-iso              # Build ISO image
just run-vm-qcow2           # Run a VM from the QCOW2 image
just spawn-vm               # Run VM using systemd-vmspawn
just clean                  # Remove build artifacts from output/
```

## Architecture

**Build flow:**
1. `Containerfile` defines the image — it uses `quay.io/fedora/fedora-coreos:stable` as the base.
2. `build_files/build.sh` runs inside the container during build to install packages (`netbird`, `cockpit`, `just`, `tmux`) and enable systemd units.
3. `system_files/etc/` is copied into the image's `/etc/` at build time. Currently contains only the Netbird yum repo definition.
4. `bootc container lint` runs at the end of the Containerfile to validate the image.

**CI/CD:**
- `build.yml`: Triggers on push to `main`, PRs, and daily at 10:05 UTC. Builds with `buildah`, signs with `cosign`, and pushes to `ghcr.io/<owner>/mitie-server-os`.
- `build-disk.yml`: Manual trigger or on changes to `disk_config/`. Produces `qcow2` and `anaconda-iso` using `bootc-image-builder`. Can optionally upload to S3.

**Key files:**
- `Containerfile` — image definition and build entry point
- `build_files/build.sh` — package installs and systemd unit enablement
- `system_files/etc/` — files overlaid onto `/etc/` in the image
- `disk_config/disk.toml` — filesystem config for VM/disk images (20 GiB root)
- `disk_config/iso.toml` / `iso-gnome.toml` / `iso-kde.toml` — ISO variants
- `cosign.pub` — public key for verifying signed images; `cosign.key` must **never** be committed

**Deploying to a running bootc system:**
```bash
sudo bootc switch ghcr.io/<owner>/mitie-server-os
```
