# ADR-0004: Domain strategy — *.denkb.ox, Netbird-VPN-only

**Date:** 2026-03-13
**Status:** Accepted

## Context

Services need to be reachable via human-friendly hostnames with valid TLS.
The primary access model is the developer and trusted users connecting over
the Netbird VPN mesh.

Options considered:

**Subpath routing on a single domain** (e.g. `server.denkb.ox/gitlab`,
`server.denkb.ox/nextcloud`) — simpler DNS setup, but many applications
(especially GitLab and Nextcloud) have partial or broken support for subpath
installs and require extra configuration. OIDC redirect URIs become harder to
manage.

**Subdomain per service on `*.denkb.ox`** — each service gets its own
subdomain (`gitlab.denkb.ox`, `nextcloud.denkb.ox`, `auth.denkb.ox`, …).
This is the standard deployment model for all target services; upstream
Compose examples and OIDC callback URIs assume subdomain-based routing.

**Public domain with auth** — expose services to the internet behind
Authentik's forward auth. Increases attack surface; not needed given Netbird
VPN provides access from all relevant client devices.

**Separate public domain for some services** (e.g. Jitsi for external guests)
— deferred; can be added later if needed.

## Decision

All services are deployed on **subdomains of `denkb.ox`**, accessible
exclusively over the **Netbird VPN** (interface `wt0`, firewalld netbird zone).

Planned subdomain assignments:

| Service | Subdomain |
|---|---|
| Caddy (proxy) | — (termination only) |
| Authentik | `auth.denkb.ox` |
| GitLab | `gitlab.denkb.ox` |
| Nextcloud | `nextcloud.denkb.ox` |
| Jitsi | `meet.denkb.ox` |
| Cockpit | `cockpit.denkb.ox` (via Authentik proxy outpost) |
| OpenCode / kilo.ai | TBD |

DNS for `denkb.ox` must resolve these subdomains to the Netbird IP of the
server (`100.83.166.105`). This can be done via:
- A wildcard `*.denkb.ox → 100.83.166.105` record in the `denkb.ox` DNS zone, or
- Netbird's built-in DNS nameserver (if configured for the `denkb.ox` domain).

## Consequences

- Clients on the Netbird VPN can reach all services via friendly hostnames.
- Off-VPN access requires connecting to Netbird first (acceptable for a
  personal homelab).
- If any service needs to be publicly accessible (e.g. Jitsi for guests), a
  separate public subdomain and firewall rule must be added at that time.
- The Caddy root CA certificate (ADR-0003) must be trusted on all client
  devices for the `*.denkb.ox` TLS certs to validate without warnings.
