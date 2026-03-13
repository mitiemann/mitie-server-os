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

## DNS implementation

`denkb.ox` is a **virtual Netbird domain** — not a real registered domain.
Netbird's managed DNS server automatically resolves peer FQDNs
(`mitie-server.denkb.ox`, `pikvm.denkb.ox`, etc.) but cannot be configured to
serve custom service subdomains.

**Netbird Reverse Proxy (Beta) was investigated and rejected:**
- The "Services" feature routes traffic through Netbird's cloud infrastructure
  (not self-hosted). Unacceptable.
- The "Custom Domains" feature requires adding a CNAME to an external DNS
  registrar to prove domain ownership. `denkb.ox` has no external DNS zone.

**Chosen approach: CoreDNS container on the server + Netbird Nameserver Group.**

1. Run a CoreDNS container on the server listening on the Netbird interface
   (`100.83.166.105:53`).
2. CoreDNS config: return `100.83.166.105` for all `*.denkb.ox` service
   subdomains; forward all other `denkb.ox` queries (peer FQDNs) upstream to
   the original Netbird DNS server.
3. In the Netbird admin console, add a Nameserver Group pointing to
   `100.83.166.105` for the `denkb.ox` domain, scoped to only the user's
   devices (not all network peers).

This means:
- Service subdomains resolve for the user's devices only.
- Peer FQDN resolution (`mitie-server.denkb.ox`, etc.) continues to work
  normally via CoreDNS's upstream forwarding.
- If the server is down, service subdomains do not resolve — acceptable, since
  the services themselves are also unavailable.
- Other machines in the Netbird network are unaffected (nameserver group is
  scoped to the user's peer group).

## Consequences

- Clients on the Netbird VPN can reach all services via friendly hostnames.
- Off-VPN access requires connecting to Netbird first (acceptable for a
  personal homelab).
- If any service needs to be publicly accessible (e.g. Jitsi for guests), a
  separate public subdomain and firewall rule must be added at that time.
- The Caddy root CA certificate (ADR-0003) must be trusted on all client
  devices for the `*.denkb.ox` TLS certs to validate without warnings.
