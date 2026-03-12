# ADR-0001: Fix SELinux context for /etc/ssh/authorized_keys.d/ in image

**Date:** 2026-03-12
**Status:** Proposed

## Context

The image ships authorized SSH keys for user `mitiemann` at
`/etc/ssh/authorized_keys.d/mitiemann` (both laptop and tueai keys), and
`/etc/ssh/sshd_config.d/99-local.conf` extends `AuthorizedKeysFile` to include
that path:

```
AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
```

During ISO installation the Anaconda kickstart uses a single `sshkey` directive
to write the laptop key to `~mitiemann/.ssh/authorized_keys`. After the first
install, SSH from `mitiemann@mitie-tueai` (whose key is only in
`/etc/ssh/authorized_keys.d/mitiemann`) was silently rejected with
`Permission denied (publickey)` — sshd never prompted a password, so the file
was being ignored rather than not found.

Attempting to add a second `sshkey` directive in the kickstart caused Anaconda
to crash with:

```
AnacondaError: set_user_ssh_key: home directory for mitiemann ...
```

Anaconda does not support multiple `sshkey` directives for the same user.

## Root Cause

Fedora CoreOS runs SELinux in enforcing mode. When `build.sh` calls
`restorecon -rv /etc/ssh/`, it assigns `etc_t` to files under
`/etc/ssh/authorized_keys.d/`. The sshd SELinux policy domain (`sshd_t`) is
allowed to read user-authorized-keys files with context `ssh_home_t`, but not
arbitrary `etc_t` files. As a result, sshd silently skips the file at runtime —
no AVC denial is logged at the `info` level because the policy uses `dontaudit`
for this path.

To verify on the installed system:
```bash
ls -Z /etc/ssh/authorized_keys.d/mitiemann   # likely shows etc_t
ausearch -c sshd --raw | grep AVC            # may be empty due to dontaudit
```

## Decision

Set the correct SELinux file context for `/etc/ssh/authorized_keys.d/` in
`build.sh` so that sshd can read it at runtime on the deployed system.

Add to `build_files/build.sh` after the existing `restorecon` call:

```bash
# Set ssh_home_t on authorized_keys.d so sshd_t (SELinux enforcing) can read
# these files as AuthorizedKeysFile entries. restorecon alone assigns etc_t,
# which sshd silently skips.
semanage fcontext -a -t ssh_home_t '/etc/ssh/authorized_keys.d(/.*)?'
restorecon -rv /etc/ssh/authorized_keys.d/
```

The `semanage` command is available in the build container via `policycoreutils-python-utils`,
which may need to be installed (check if already present in the Fedora CoreOS base image).
If `semanage` is not available, use `chcon` as a fallback:

```bash
chcon -R -t ssh_home_t /etc/ssh/authorized_keys.d/
```

Note: `chcon` sets the context directly; `semanage` + `restorecon` persists the
policy mapping so future `restorecon` calls (e.g. during updates) don't revert it.
Prefer `semanage` if available.

## Consequences

- Both SSH keys (laptop and tueai) will work immediately after installation
  without any kickstart workarounds.
- The kickstart stays clean with a single `sshkey` directive (laptop key) for
  the initial authorized_keys seed; the image-level keys serve as the
  authoritative and immutable source for all allowed keys.
- Future key additions only require rebuilding the image, not modifying the
  kickstart or touching the installed system.

## Implementation Checklist

- [ ] Check if `policycoreutils-python-utils` (provides `semanage`) is available
      in the build container, or add it as a build-time-only install in `build.sh`
- [ ] Add `semanage fcontext` + `restorecon` (or `chcon` fallback) to `build.sh`
- [ ] Remove the second `sshkey` line from `disk_config/iso.toml` (currently
      present but crashes Anaconda — revert to single laptop key only)
- [ ] Build and test: install from new ISO, verify `ssh mitiemann@<ip>` works
      from both laptop and tueai
- [ ] Verify with `ls -Z /etc/ssh/authorized_keys.d/mitiemann` on installed system
      that context is `ssh_home_t`
