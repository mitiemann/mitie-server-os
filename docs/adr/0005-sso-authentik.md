# ADR-0005: SSO/IdP — Authentik with 2FA

**Date:** 2026-03-13
**Status:** Accepted

## Context

Multiple services (GitLab, Nextcloud, Jitsi, Cockpit, …) each require user
authentication. Managing separate accounts per service is operationally
expensive and a security liability. A single identity provider (IdP) with
centralised 2FA is preferred.

Options considered:

**Keycloak** — the de facto enterprise OIDC/SAML IdP. Mature, feature-rich,
widely supported. Drawbacks: heavy (JVM-based, high RAM), complex to configure,
slow startup. Over-engineered for a single-user homelab.

**Authelia** — lightweight SSO proxy focused on forward auth. Simple to set up,
low resource usage. Drawbacks: primarily a forward-auth proxy, not a full IdP;
limited native OIDC provider support; cannot act as a SAML IdP; fewer
integration options for GitLab-style OIDC client flows.

**Zitadel** — modern, Go-based IdP with OIDC, SAML, and passkey support.
More featureful than Authelia, lighter than Keycloak. Drawbacks: younger
project, smaller community, fewer ready-made integration guides.

**Authentik** — Python/Go-based open-source IdP. Supports OIDC, SAML, LDAP,
SCIM, and a proxy outpost mode for services that don't speak OIDC natively
(e.g. Cockpit). Active community, good documentation, official Compose
examples. Moderate resource usage (~512 MB RAM for server + worker).

## Decision

Use **Authentik** as the SSO identity provider.

Key capabilities used:
- **OIDC provider** for GitLab, Nextcloud, Jitsi, OpenCode.
- **Proxy outpost** (forward auth) for Cockpit — Authentik authenticates the
  user, Caddy passes `X-Forwarded-User` to Cockpit, which trusts the header
  from the local proxy.
- **2FA** via TOTP (authenticator app) and/or WebAuthn (hardware key /
  passkey). Enforced via Authentik flow policies.
- **Self-service** password and 2FA management at `auth.denkb.ox`.

## Cockpit integration note

Cockpit does not natively speak OIDC. The integration works as follows:
1. Caddy receives a request to `cockpit.denkb.ox`.
2. Caddy's `forward_auth` directive queries the Authentik outpost.
3. If the user is not authenticated, Authentik redirects to its login page.
4. After successful login + 2FA, Authentik passes `X-Authentik-Username` header.
5. Caddy forwards the request to Cockpit with `X-Forwarded-User: mitiemann`.
6. Cockpit is configured to trust that header from localhost (via
   `/etc/cockpit/cockpit.conf` `Origins` setting).

The local Unix user `mitiemann` must exist on the host (it does).

## Consequences

- Authentik requires PostgreSQL and Redis/Valkey — two additional containers.
- Total additional RAM: ~700 MB (Authentik server + worker + Postgres + Valkey).
- The Authentik bootstrap admin password must be set at first startup and
  stored securely (added to `.env` / `.env.template`).
- All OIDC client secrets (one per service) are generated in Authentik and
  stored in each service's Compose `.env` file — never committed to git.
- If Authentik is down, login to all SSO-protected services is blocked.
  Cockpit fallback: SSH is always available independently.
