# ADR-0003: TLS strategy — internal CA via Caddy

**Date:** 2026-03-13
**Status:** Accepted

## Context

All homelab services are exposed via a reverse proxy on subdomains of `denkb.ox`
and are only reachable over the Netbird VPN. TLS is required to avoid plaintext
credentials and browser mixed-content warnings, and to allow Authentik's OIDC
flows (which require HTTPS redirect URIs).

Several TLS options were considered:

**Let's Encrypt (public ACME)** requires the domain to be publicly resolvable
for HTTP-01 challenges, or requires a DNS-01 challenge (needs API access to the
DNS provider). The `denkb.ox` subdomains are internal/VPN-only, making HTTP-01
impractical. DNS-01 is feasible but adds operational complexity.

**Internal CA via Caddy** — Caddy has a built-in ACME server and CA
(`caddy pki`) that issues short-lived certificates for any domain. Browsers and
clients must trust the Caddy root CA certificate, which is a one-time setup per
client device. No external dependencies or DNS provider API keys are needed.

**Per-service self-signed certificates** — each service generates its own cert.
No shared CA; every client must trust every cert individually. Unmanageable at
scale.

**Step CA / smallstep** — a dedicated internal CA product. More featureful than
Caddy's built-in CA (e.g. ACME, SCEP, SSH cert support), but adds another
service to run and maintain.

## Decision

Use **Caddy's built-in internal CA** (`tls internal` directive) for all services.

Caddy acts as both the reverse proxy and the ACME CA. It issues and auto-renews
certificates for all `*.denkb.ox` subdomains. Clients need to trust the Caddy
root CA once (distributed manually or via Netbird's peer configuration).

## Consequences

- All HTTP traffic to services goes through Caddy; no service should expose TLS
  directly to the outside.
- The Caddy root CA certificate must be distributed to all client devices
  (laptop, tueai, …) and added to the system trust store.
- If Caddy is replaced in the future, certificates will need to be reissued from
  a new CA and clients re-configured.
- `tls internal` uses Caddy's local ACME server; the CA key is stored in
  `/data/caddy/pki/` inside the Caddy container volume — this must be backed up
  to survive a server reflash.

## Future consideration

If SSH certificate auth (for Netbird peer verification or server SSH) is ever
needed, migrate to **smallstep CA** which supports both TLS and SSH certificate
issuance from a single root.
