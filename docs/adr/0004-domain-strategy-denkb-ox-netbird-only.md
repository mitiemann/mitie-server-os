# ADR-0004: Domain strategy — port-based access on mitie-server.denkb.ox

**Date:** 2026-03-13
**Status:** Accepted (supersedes initial CoreDNS/subdomain approach)

## Context

Services need to be reachable via human-friendly URLs with valid TLS.
The primary access model is the developer and trusted users connecting over
the Netbird VPN mesh.

Options considered:

**Subpath routing on a single domain** (e.g. `mitie-server.denkb.ox/gitlab`,
`mitie-server.denkb.ox/nextcloud`) — many applications (GitLab, Nextcloud)
have partial or broken subpath support; OIDC redirect URIs become harder to
manage.

**Subdomain per service on `*.denkb.ox`** — the standard deployment model
for all target services. Requires custom DNS resolution for the service
subdomains, since Netbird's built-in DNS only resolves peer FQDNs. Initially
pursued via CoreDNS container + Netbird Nameserver Group (see "Rejected
approaches" below).

**Port-based access on `mitie-server.denkb.ox`** — each service gets a
distinct port. `mitie-server.denkb.ox` already resolves to the server's
Netbird IP (`100.83.166.105`) via Netbird's built-in DNS with no additional
configuration. OIDC redirect URIs use `https://mitie-server.denkb.ox:<port>`.
TLS is terminated by Caddy using the internal CA (ADR-0003).

**Public domain with auth** — increases attack surface; not needed given
Netbird VPN provides access from all relevant client devices.

## Decision

All services are deployed at **distinct ports on `mitie-server.denkb.ox`**,
accessible exclusively over the **Netbird VPN** (interface `wt0`, firewalld
netbird zone). No additional DNS infrastructure is needed.

Port assignments:

| Service | URL |
|---|---|
| Cockpit | `https://mitie-server.denkb.ox:9090` (native, no proxy) |
| Authentik | `https://mitie-server.denkb.ox:9443` |
| GitLab | `https://mitie-server.denkb.ox:8443` |
| Nextcloud | `https://mitie-server.denkb.ox:8444` |
| Jitsi | `https://mitie-server.denkb.ox:8445` |

Caddy listens on the Netbird interface for ports 9443, 8443, 8444, 8445 and
terminates TLS with the internal CA. Cockpit continues to handle its own TLS
on port 9090 for now; it can be moved behind Caddy later when the Authentik
proxy outpost is set up.

## Rejected approaches

**CoreDNS container + Netbird Nameserver Group** — this was initially
implemented but removed. It required:
- A CoreDNS container running on the server, baked into the image.
- A Nameserver Group configured in the Netbird admin console pointing
  `denkb.ox` queries to the server's Netbird IP.
- Risk: if the server is down, DNS also stops working for the user's devices,
  potentially disrupting other `denkb.ox` peer resolution.
- The Nameserver Group scoping question (not all peers should have their DNS
  affected) added operational complexity.
- Eliminated by the port-based approach, which requires zero DNS configuration
  beyond what Netbird already provides.

**Netbird Reverse Proxy (Beta)** — investigated and rejected:
- The "Services" feature routes traffic through Netbird's cloud (not
  self-hosted). Unacceptable.
- The "Custom Domains" feature requires a CNAME in an external DNS registrar.
  `denkb.ox` has no external DNS zone.

## Consequences

- No CoreDNS container, no Nameserver Group, no extra firewall rules for DNS.
- `mitie-server.denkb.ox` resolves automatically for all Netbird peers.
- OIDC redirect URIs include the port (e.g.
  `https://mitie-server.denkb.ox:9443/source/oauth/callback`), which is
  standard and supported by all target services.
- If a service ever needs a cleaner URL (no port), adding a subdomain at that
  time requires only a Nameserver Group change in Netbird — no image rebuild.
- Off-VPN access requires connecting to Netbird first (acceptable for a
  personal homelab).
- The Caddy root CA certificate (ADR-0003) must be trusted on all client
  devices for TLS certs to validate without warnings.
