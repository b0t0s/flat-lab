---
title: Services
domain: docs
type: catalogue
status: active
tags: [services, catalogue, alternatives]
filed: 2026-07-22
related:
  - readme.md
  - decisions.md
---

# Services

One section per service that runs in `docker-compose.yml`.
Each entry: **Role** (what it is), **Why** (the trait that settled it), **Alternatives considered** (one bullet per rejected option, with a one-line reason).
The compose file is the single source for *what runs*; this file is the source for *why each one runs and not something else*.

## At a glance

| Cluster | Chosen | Rejected alternatives |
|---|---|---|
| Remote access | ZeroTier + ZTNCUI | WG-Easy, `wg-quick`, Pi-WireGuard, Tailscale, Headscale, Netbird, OpenVPN, Nebula |
| HTTP edge | Caddy | nginx + certbot, Traefik, HAProxy |
| DNS / ad-block | AdGuard Home | Pi-hole, Unbound, NextDNS, dnsmasq |
| Git + CI/CD | OneDev | Gitea, GitLab CE, Forgejo, SourceHut, Phabricator |
| Cloud storage | Seafile | Nextcloud, ownCloud, Syncthing, FileBrowser, MinIO + rclone |
| File share link | Pingvin Share | Nextcloud drop, Seafile link, Plik, go-file / Uguu, XBackBone |
| Web archive | ArchiveBox | SingleFile CLI, Wallabag, Pocket, Pinboard, Perma.cc, HTTrack |
| Inventory | Homebox | Snipe-IT, Grocy, HA `todo`, Notion / Obsidian DB, spreadsheet |
| eBook library | Calibre-Web | Calibre desktop, COPS, Booklore / Reader |
| Smart home | Home Assistant | Tuya cloud, openHAB, Domoticz, Hubitat, Node-RED |
| LAN monitor | NetAlertX | Fing, nmap + cron, nmap + Grafana, LibreNMS, NetBox |
| Local LLM | Ollama | llama.cpp raw, LocalAI, vLLM / TGI, LM Studio, GPT4All |
| Chat UI | Open WebUI | LibreChat, SillyTavern, HF Chat UI |
| yt-dlp UI | MeTube | yt-dlp CLI, Tube Archivist, Jellyfin YT plugin, Streama |
| Cloudflare bypass | FlareSolverr | 2Captcha, Anti-Captcha, cookies-only tools, different indexers |
| Indexer agg | Prowlarr | Jackett, Cardigann, single indexer UI |
| Torrent client | qBittorrent | Transmission, Deluge, rTorrent + ruTorrent, seedbox |
| Hash cracking | Phatcrack | Hashcat CLI, John the Ripper, online lookups, hashcat-web |
| Remote desktop | RustDesk | TeamViewer, AnyDesk, Apache Guacamole, MeshCentral, x11vnc / TigerVNC |
| Dev toolbox | IT-Tools | DevToys, CyberChef, bookmark to online, Hoppscotch / Carbide |
| Game server | Minecraft Leaf | Vanilla, Paper, Spigot, Purpur / Pufferfish, Fabric / Quilt, Aternos / Minehut |
| Dashboard | Homepage | Heimdall, Dashy, Organizr, hand-rolled `index.html`, Flame |
| Monitoring | Uptime Kuma | Prometheus + Alertmanager, Healthchecks.io, Statping, UptimeRobot |
| Container logs | Dozzle | `docker logs -f`, Portainer logs, Loki + Grafana |
| Auto-updates | Watchtower | manual `pull && up` on cron, Diun, Renovate / Dependabot |

# AdGuard Home

**Role.** LAN DNS resolver + ad-blocker.

**Why.** Single Web UI for blocklists, rewrite rules, and per-client overrides.

## Alternatives considered

- Pi-hole (less polished UI, weaker rewrite)
- Unbound (no filtering)
- NextDNS (hosted, account-tied)
- dnsmasq (too low-level)

# ArchiveBox

**Role.** Self-hosted web archive; multiple formats per URL (HTML, screenshot, PDF, WARC).

**Why.** Imports from Pocket / Pinboard / RSS; no third-party dependency.

## Alternatives considered

- SingleFile CLI (one format, no library)
- Wallabag (read-later, not archive)
- Pocket / Pinboard (hosted)
- Perma.cc (academic, hosted)
- HTTrack (site mirror, not per-URL)

# Caddy

**Role.** Single HTTP edge; terminates TLS via DuckDNS DNS-01, routes by host.

**Why.** One file owns TLS, headers, and routing; DNS-01 keeps the single-open-port rule.

## Alternatives considered

- nginx + certbot (DNS-01 path is awkward)
- Traefik (config scatters across labels)
- HAProxy (no clean TLS-by-domain)

# Calibre-Web

**Role.** Web reader for the Calibre library.

**Why.** Surfaces the Calibre DB to a browser; OPDS feed for e-readers.

## Alternatives considered

- Calibre desktop (single-machine only)
- COPS (older, ugly)
- Booklore / Reader (smaller user bases)

# Dozzle

**Role.** Live container log viewer in the browser; per-container stream + search.

**Why.** Smallest surface for "show me the live logs of every container."

## Alternatives considered

- `docker logs -f` (one container at a time)
- Portainer log viewer (Docker-management UI side-feature)
- Loki + Grafana (heavier, needs Promtail)

# FlareSolverr

**Role.** Sidecar that solves Cloudflare challenges for Prowlarr.

**Why.** Self-hosted, no payments, the only Prowlarr-integrated option in active development.

## Alternatives considered

- 2Captcha (paid, brittle)
- Anti-Captcha (paid, brittle)
- Cookies-only manual tools (no automation)
- A different indexer (smaller pool)

# Home Assistant

**Role.** Smart home hub (Tuya / Smart Life); automations, dashboards, integrations.

**Why.** Largest integration library; self-hosted; one UI for the household.

## Alternatives considered

- Tuya / Smart Life cloud (no real automations)
- openHAB (older, smaller community)
- Domoticz (dated UI)
- Hubitat (closed-source, hub hardware)
- Node-RED + ad-hoc dashboard (no household UI)

# Homebox

**Role.** Household inventory: serial numbers, warranties, attached receipts.

**Why.** Data model shaped for a home, not a stockroom; document attachments.

## Alternatives considered

- Snipe-IT (IT-fleet shape)
- Grocy (food / chores shaped)
- HA `todo` (no schema)
- Notion / Obsidian (drifts)
- A spreadsheet (no attachments)

# Homepage

**Role.** Self-hosted dashboard / start page with live service widgets.

**Why.** Config-as-YAML, no DB, themable; the best mix of live data and low maintenance.

## Alternatives considered

- Heimdall (older)
- Dashy (heavier, SQLite settings)
- Organizr (VFS-shaped, not start-page)
- Hand-rolled `index.html` (no live status)
- Flame (newer, smaller community)

# IT-Tools

**Role.** Browser-only collection of developer utilities (JSON, base64, regex, JWT, cron, color, …).

**Why.** One self-hosted page replaces 12 bookmarked sites; no telemetry.

## Alternatives considered

- DevToys (desktop only)
- CyberChef (steep learning curve)
- Bookmark to online tools (third-party cookies)
- Hoppscotch / Carbide (API / HTTP only)

# MeTube

**Role.** yt-dlp Web UI; paste URL, pick format, download.

**Why.** Smallest surface for one-off downloads; the de-facto yt-dlp frontend.

## Alternatives considered

- yt-dlp CLI (no UI)
- Tube Archivist (heavier)
- Jellyfin YT plugin (wrong shape)
- Streama (abandoned)

# Minecraft Leaf

**Role.** Minecraft server (Leaf, a high-performance Paper fork).

**Why.** Paper's plugin API + extra performance work; `itzg/minecraft-server` image handles the boilerplate.

## Alternatives considered

- Vanilla (no plugins / perf)
- Paper (less perf than Leaf)
- Spigot / CraftBukkit (older)
- Purpur / Pufferfish (other forks)
- Fabric / Quilt (mod loader, not server software)
- Aternos / Minehut (hosted)

# NetAlertX

**Role.** LAN device monitor (ARP, ping, vendor lookups); alerts on new / missing devices.

**Why.** Self-hosted Web UI for the device graph + history.

## Alternatives considered

- Fing mobile (closed, no history)
- nmap + cron (no UI / alerting)
- nmap + Grafana (heavier)
- LibreNMS (SNMP-oriented, overkill)
- NetBox (source-of-truth, not live monitor)

# Ollama

**Role.** Local LLM runtime; OpenAI-compatible HTTP API on :11434.

**Why.** Runs on a Pi (small models); clean model catalogue; single binary.

## Alternatives considered

- llama.cpp raw (no API / concurrency)
- LocalAI (broader but rougher)
- vLLM / TGI (datacentre GPUs)
- LM Studio (desktop)
- GPT4All (smaller ecosystem)

# OneDev

**Role.** Self-hosted Git + CI/CD + Kanban in one Java service.

**Why.** Smallest surface that covers code, automate, and track in one container.

## Alternatives considered

- Gitea + Drone (two services for the same job)
- GitLab CE (too heavy for a Pi)
- Forgejo (same as Gitea)
- SourceHut (no GUI)
- Phabricator (abandoned)

# Open WebUI

**Role.** Chat UI for Ollama.
Multi-user, conversation history, document upload.

**Why.** The de-facto Ollama frontend; self-hosted, no account.

## Alternatives considered

- LibreChat (heavier stack, smaller community)
- SillyTavern (roleplay-shaped)
- HF Chat UI (HF-tied)

# Phatcrack

**Role.** Web UI + job queue around Hashcat.

**Why.** Self-hosted, no payments, the most mature hashcat frontend.

## Alternatives considered

- Hashcat CLI (no queue / UI)
- John the Ripper (older, weaker GPU kernels)
- Online hash lookups (hosted)
- hashcat-web (smaller projects)

# Pingvin Share

**Role.** Self-hosted file share link (WeTransfer alternative).

**Why.** Modern UI, expiration, password protection; one container.

## Alternatives considered

- Nextcloud drop (heavier stack)
- Seafile share (desktop-shaped UI)
- Plik (CLI-first)
- go-file / Uguu (dated)
- XBackBone (media-shaped)

# Prowlarr

**Role.** Indexer aggregator for the *arr suite; one place to manage indexers, hands off to qBittorrent and the *arr apps.

**Why.** Native to the *arr stack; first-class FlareSolverr integration.

## Alternatives considered

- Jackett (older, deprecated in favour of Prowlarr)
- Cardigann (Jackett internals)
- Single indexer UI (drift)

# qBittorrent

**Role.** Torrent client with Web UI; pairs with Prowlarr.

**Why.** Open source, no ads, no "pro" tier; the polished self-hosted option.

## Alternatives considered

- Transmission (lighter, weaker UI)
- Deluge (daemon / UI split)
- rTorrent + ruTorrent (older)
- Seedbox (hosted, paid)

# RustDesk

**Role.** Self-hosted relay for the RustDesk remote-desktop client (hbbs + hbbr).

**Why.** Open source, polished clients, no payments.

## Alternatives considered

- TeamViewer / AnyDesk (closed, paid for commercial)
- Apache Guacamole (clientless, heavier)
- MeshCentral (fleet-oriented)
- x11vnc / TigerVNC (no client for non-technical users)

# Seafile

**Role.** Self-hosted cloud storage with desktop / mobile sync clients.

**Why.** Polished clients, end-to-end encryption, no per-user fees.

## Alternatives considered

- Nextcloud (heavier; only worth it for calendar / office)
- ownCloud (older clients)
- Syncthing (peer-to-peer, no UI)
- FileBrowser (no sync)
- MinIO + rclone (S3-shaped, not Dropbox-shaped)

# Uptime Kuma

**Role.** Per-service up/down checks + alerts; status page.

**Why.** Single-binary Web UI, alerting channels out of the box (Telegram, email, ntfy, …).

## Alternatives considered

- Prometheus + Alertmanager + Grafana (heavier; right when metrics are needed)
- Healthchecks.io (cron-only, hosted free tier)
- Statping-ng (abandoned)
- UptimeRobot free (hosted, capped)

# Watchtower

**Role.** Auto-updates labelled containers; daily 04:00 schedule, prunes old images.

**Why.** Single container, label-gated; the standard self-hosted updater.

## Alternatives considered

- `docker compose pull && up` on cron (manual, easy to forget)
- Diun (notify only)
- Renovate / Dependabot (compose-file lint, not runtime)
- Hosted update services (out of scope)

# ZeroTier

**Role.** The single remote-access path.
UDP/9993 from the router, ZTNCUI controller UI on the bridge.

**Why.** Self-hosted mesh + Web UI for membership.
No accounts, no payments, no third-party coordination.

## Alternatives considered

- WG-Easy / `wg-quick` (hand-written per-client configs)
- Pi-WireGuard (same problem, hand-rolled)
- Tailscale (hosted control plane)
- Headscale / Netbird (only worth the cost with many nodes)
- OpenVPN (older, heavier)
- Nebula (no controller UI)