---
title: Home Lab Decisions
domain: docs
type: decision
status: active
tags: [topology, docker-compose, caddy, zerotier, single-source]
filed: 2026-07-22
related:
  - architecture-notes.md
---

# Home Lab Decisions

Settled rules for flat-lab.
A change that contradicts an entry here names the decision it revokes and the reason, or leaves it alone.

## Topology

- **One router port: ZeroTier UDP/9993.** Nothing else is port-forwarded.
- **ZeroTier + ZTNCUI is the only remote-access path.** No WireGuard/WG-Easy/Pi-WireGuard, no Tailscale, no Headscale, no Netbird. The "convenient, secure, comfortable, no payments" target settled it.
- **Caddy is the only HTTP edge.** DNS-01 via DuckDNS for TLS. A new service gets a `caddy/Caddyfile` site block, never its own `ports: 80/443`.
- **`network_mode: host` is reserved for `home-assistant` and `netalertx`.** Both need raw L2/ARP visibility. Everything else is on `homelab_net`.

## Orchestration

- **`docker-compose.yml` is the single source.** If it should run, it is in there. No `docker run` outside compose.
- **Post-boot config = idempotent init container.** The Seafile auto-configurator is the pattern: wait, check, inject, restart. Never "exec in and hand-edit."

## Safety

- **Secrets are in `.env`, never in the compose file.** `.env` and `*.env` are gitignored.

## Drift

- **Readme service table must match `docker-compose.yml` and `caddy/Caddyfile`.** The readme is a derived view; the compose file is the truth. Update the table in the same change that touches either.