# Session Context (delete before merging to main)

## Current Branch
`improve-installer-and-pikvm-push`

## Server State
The server is currently sitting at the **Anaconda error shell** (option 2).
Partitions are formatted and mounted at `/mnt/sysimage`. The ostree deploy
completed successfully but **steps 6–9 below have NOT been run yet**.

## What Was Done This Session
- Confirmed root cause of UTF-8 installer failure (see below)
- Ran `ostree admin init-fs --modern /mnt/sysimage`
- Ran `ostree admin os-init --sysroot=/mnt/sysimage default`
- Ran `LANG=C.UTF-8 LC_ALL=C.UTF-8 ostree container image deploy ...` — **succeeded**
- Fixed `push-iso` recipe: replaced `rsync` with `scp -C` (rsync not on PiKVM)

## Immediate Next Steps (on the server, in the Anaconda shell)

```bash
# 6. Install bootloader
chroot /mnt/sysimage grub2-install \
  --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=fedora
chroot /mnt/sysimage grub2-mkconfig -o /boot/grub2/grub.cfg

# 7. Create user (kickstart %post never ran)
chroot /mnt/sysimage useradd -G wheel -p '!' mitiemann

# 8. Set bootc registry origin
chroot /mnt/sysimage bootc switch --mutate-in-place \
  --transport registry ghcr.io/mitiemann/mitie-server-os:latest

# 9. Reboot
reboot
```

After reboot: SSH in as `mitiemann` using laptop or tueai key and verify services.

## Root Cause of UTF-8 Installer Failure
`LANG=en_US.UTF-8` is set in the Anaconda environment, but the **locale database
is not installed** in the minimal installer environment. glibc falls back to
ASCII-only. `C.UTF-8` works because it is a glibc built-in requiring no database.

## Permanent Fix (NOT YET IMPLEMENTED — do after server is up)
Add to `disk_config/iso.toml`:
```toml
[customizations.kernel]
append = "LANG=C.UTF-8"
```
BIB confirmed to support this. Sets locale via GRUB cmdline before Anaconda starts.
Then rebuild ISO, push to PiKVM, test automated install end-to-end.

## After Permanent Fix Is Verified
- Delete this file
- Open PR from `improve-installer-and-pikvm-push` → `main`
