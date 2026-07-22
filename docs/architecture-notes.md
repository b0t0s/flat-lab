---
title: Architecture Notes
domain: docs
type: info
status: active
tags: [topology, single-arm-vpn, caddy, raspberry-pi]
filed: 2026-07-22
related:
  - decisions.md
---

# Architecture Notes

The long form of [decisions.md](decisions.md): one paragraph per choice, what the constraint buys.

## Single-Arm VPN Gateway

One open port (ZeroTier UDP/9993), one HTTP edge (Caddy), one bridge network (`homelab_net`).
The attack surface of a home lab is the number of weak services the internet can touch; collapsing that number to one hardened VPN endpoint means a vulnerability in Seafile or OneDev is not a vulnerability the internet can reach.
Trade-off: the Pi is a single point of failure for remote access until a second node exists.
WireGuard-based stacks (WG-Easy, `wg-quick`, Pi-WireGuard) were rejected because each new client needs a hand-written peer config shipped out of band, with no central UI to manage membership.
Tailscale and Headscale were rejected because Tailscale needs a hosted control plane and Headscale adds a service to operate in exchange for nothing the lab actually needs.
See [services/zerotier.md](services/zerotier.md) for the per-rejection reason.

## Caddy as the Sole Ingress

One Caddy container terminates TLS (DuckDNS DNS-01), applies headers, and reverse-proxies by host.
DNS-01 issues certificates without an inbound HTTP challenge, which is what keeps the one-open-port rule intact.
The `*.{$DUCKDNS_DOMAIN}` site block is a single wildcard with named host matches; new services get a named match, never their own TLS.
Trade-off: Caddy down means all web access down; `restart: unless-stopped` plus a future second node is the answer.

## Compose as the System's Form

One `docker-compose.yml` declares every container, network, and volume.
Any container that exists outside the compose file works until the next rebuild and then vanishes with no record.
Trade-off: a single growing file; `include:` is the scale answer.

## Config-as-Code via Idempotent Init Containers

Post-boot config a service cannot express through env vars is applied by a small init container that waits, checks, injects, and restarts.
The Seafile auto-configurator is the reference implementation.
The check-then-write shape is what makes it safe to re-run on every boot.