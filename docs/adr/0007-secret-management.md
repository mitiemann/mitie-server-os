---
status: proposed
date: 2026-03-15
---

# ADR-0007: Secret Management Strategy

## Context

The project requires runtime secrets (database passwords, secret keys) for deployed services. These secrets must be available on the server at deploy time but must never be committed to git in plaintext.

Currently, secrets are stored in a root-level `.env` file (gitignored) and rsynced to the server by `just deploy-service`. This requires manually syncing `.env` across development machines, which is error-prone and does not scale well.

The mid-term goal is to commit secrets securely to the repository so that any development machine can deploy without out-of-band secret sharing.

## Decision

For now: keep the root `.env` / `just deploy-service` approach. It is simple, already working, and sufficient for a single developer on a single server.

Revisit when any of the following is true:
- Working from more than one machine becomes a regular friction point
- A second server is added
- A second person needs to deploy

## Alternatives Considered

### sops + age

`sops` encrypts only the secret *values* in a file, leaving keys readable in git. `age` provides the encryption key (a single keypair per developer, stored outside the repo). Decryption is one command; Just recipes can transparently decrypt before deploying.

**Pros:** lightweight, no new runtime dependencies, integrates directly into the existing Just workflow, secrets safely committed to git.
**Cons:** requires distributing the age private key out-of-band (once, per developer machine); slightly more tooling.

This is the recommended path when secret-in-git becomes necessary.

### Ansible + ansible-vault

Ansible encrypts files or individual variables with a vault password. Playbooks replace Just recipes for all provisioning and deployment tasks.

**Pros:** vault is built-in, idempotent tasks, works well for multi-server setups, dry-run mode.
**Cons:** significant complexity increase (inventory, playbook structure, Python dependency); overkill for one server managed by one person. Worth revisiting if the number of managed hosts grows to ≥3 or if a second operator needs to run deployments safely.

### External secret store (Vault, Infisical, Doppler)

Secrets stored in a dedicated service; the server pulls them at deploy or runtime.

**Pros:** full audit trail, fine-grained access control, rotation support.
**Cons:** introduces an external dependency that must itself be available and secured. Not appropriate for a homelab where availability of the secret store cannot be guaranteed.

## Consequences

- `.env` remains gitignored; developers must sync it manually across machines for now.
- When the pain of manual syncing becomes real, migrate to `sops` + `age`: encrypt `.env` to `.env.enc`, add a `just decrypt-env` recipe, commit `.env.enc`.
- Ansible is on the table for the future if multi-host management is needed, but should not be adopted solely for secret management.
