#!/usr/bin/env bash
# preview.sh — invoked by fzf --preview to show descriptions for the
# currently-highlighted category or service. Runs as a separate process
# because fzf uses `sh -c` for preview commands, which doesn't see bash
# functions defined in the parent script.
#
# Usage: fzf --preview='./scripts/preview.sh category {line}'
# Where {line} is fzf's `{}` placeholder, the currently-highlighted row.
# Stdin is also accepted (some fzf versions pipe the line that way).
# Output: a multi-line description.

set -uo pipefail

KIND="${1:-category}"

# Prefer the second arg (fzf {}), fall back to stdin.
if [ -n "${2-}" ]; then
  LINE="$2"
elif [ ! -t 0 ]; then
  LINE="$(cat)"
else
  LINE=""
fi

# Extract the relevant token from the input line.
# Format: "<marker> <name>  (<rest>)"  — $2 is always the name.
name="$(printf '%s\n' "$LINE" | awk '{print $2}')"

if [ -z "$name" ]; then
  # fzf sent us an empty line during startup (before any cursor settles).
  # Show a friendly placeholder so the pane isn't blank.
  printf '\033[2m(highlight a category to see what it contains)\033[0m\n'
  exit 0
fi

# Self-contained hint tables. Keep in sync with the scripts that use them.
category_hints() {
  cat <<'HINTS'
system	Core infra: caddy, adguard, dozzle, watchtower, uptime-kuma. Always-on.
dashboard	Dashboards: homepage, glance. Operator landing pages.
network	Networking: zerotier (VPN), rustdesk (remote desktop), upsnap (WoL).
media	Media: jellyfin, navidrome, kavita, calibre-web, qbittorrent + *arr.
photos	Photos: pigallery2, immich (ML disabled). Image library management.
knowledge	Knowledge: memos, ghost, archivebox, paperless-ngx, changedetection.
secrets	Encrypted sharing (shhh, hemmelig), pastebin (opengist), password managers (vaultwarden, passbolt, aliasvault, psono), secrets mgmt (infisical).
finance	Personal finance: actual-budget, wallos, solidtime.
productivity	Productivity: super-productivity, managemeals, twofauth.
dev	Developer tools: code-server, onedev, olivetin.
smarthome	Smart home: home-assistant, homebox, node-red.
family	Family: gramps-web (genealogy).
medical	Medical: openemr. HIPAA-scoped, off by default, ZeroTier-only.
chat	Chat: snikket (XMPP), conversejs, movim. Requires snikket.conf.
paas	Platform-as-a-Service: seafile, ollama, phatcrack, minecraft.
bookmarks	Bookmarks: linkwarden (archive), meilisearch.
tools	Tools: stirling-pdf, searxng. Utility services.
monitor	Monitoring: beszel (metrics), ntfy (notifications).
HINTS
}

service_hints() {
  cat <<'HINTS'
adguardhome	DNS sinkhole + ad blocker. Replaces router DNS.
archivebox	Web page archiver. Saves HTML, screenshots, PDFs of bookmarks.
adventurelog	Travel journal with itinerary builder, photos, places.
actualbudget	Personal finance with envelope budgeting, multi-currency.
beszel-agent	Server metrics agent (CPU, mem, disk, net). Talks to beszel-hub.
beszel-hub	Central dashboard for beszel-agent metrics history.
caddy	Reverse proxy with auto-TLS via DuckDNS.
changedetection	Web page change monitor. Alerts on diffs.
code-server	VS Code in browser. Dev IDE accessible from anywhere.
conversejs	XMPP web client. Browser-based chat.
calcom	Scheduling infrastructure. Calendly alternative.
calcom-db	Postgres backend for calcom.
calcom-redis	Redis cache for calcom.
radicale	CalDAV/CardDAV server. Calendar + contacts sync.
grocy	Household inventory + shopping list + meal planning.
keila	Newsletter platform.
keila-db	Postgres backend for keila.
monica	Personal CRM. Remember everything about friends and family.
monica-db	MariaDB backend for monica.
kimai	Time tracking + invoicing. Freelancer-focused.
miniflux	Minimalist feed reader. Fast, written in Go.
miniflux-db	Postgres backend for miniflux.
outline	Team wiki / docs platform. Fast markdown editor.
outline-db	Postgres backend for outline.
outline-redis	Redis cache for outline.
bookstack	Wiki + manual platform. PHP/MySQL.
bookstack-db	MariaDB backend for bookstack.
kutt	URL shortener with custom domain + API.
kutt-db	Postgres backend for kutt.
kutt-redis	Redis cache for kutt.
livekit	WebRTC SFU. Audio/video conferencing infrastructure.
livekit-redis	Redis backend for livekit.
ergochat	Modern IRC server with web client.
lemmy	Federated Reddit alternative (ActivityPub).
lemmy-db	Postgres backend for lemmy.
perplexica	AI search engine (Perplexity clone).
docker-pruner	Auto-remove dangling images and stopped containers weekly.
dawarich	Location timeline. Imports Google Maps Timeline JSON.
dozzle-init	One-shot init: creates the dozzle admin user.
dozzle	Real-time docker log viewer with multi-container filtering.
filebrowser-quantum	Web file manager. Browse, upload, download, edit files.
faved	Minimal bookmark manager with private/public collections.
glances	System monitor (CPU, RAM, disk, net, processes) in TUI or web.
glance	Personal dashboard with widgets (weather, RSS, bookmarks, todos).
gramps-db	Postgres backend for gramps-web.
gramps-web	Collaborative genealogy viewer and editor.
ghost-db	MySQL backend for Ghost blog.
ghost	Headless Node.js blog/CMS platform.
hemmelig	Encrypted secret sharing. Burn-after-read.
home-assistant	Home automation hub. Integrates with thousands of devices.
homebox	Household inventory tracker. QR labels, items, photos.
homepage	Personal dashboard. Auto-discovers services via docker labels.
homepage-auto-config	Watches docker labels and updates homepage config.
immich-server	Google Photos replacement. Web UI + mobile apps.
immich-postgres	Postgres backend for Immich.
immich-redis	Redis cache for Immich.
immich-typesense	Search engine for Immich photo metadata.
it-tools	Developer utilities toolbox. 80+ tools (JSON, encoding, hashing).
jellyfin	Media server: movies, TV shows, music, photos. DLNA + Chromecast.
vaultwarden	Password manager (Bitwarden-compatible). Rust, Pi-friendly (<50MB RAM).
affine	Local-first Notion + Miro. Block-based editor. Go+TypeScript.
affine-db	Postgres backend for AFFiNE.
documenso	Document signing. DocuSign alternative.
documenso-db	Postgres backend for documenso.
documenso-redis	Redis cache for documenso.
docuseal	E-signatures. Ruby on Rails. Single container.
plausible	Privacy-focused web analytics.
plausible-db	Postgres backend for Plausible.
plausible-events	Background event processing for Plausible.
plausible-clickhouse	ClickHouse backend for Plausible analytics.
karakeep	Bookmark manager with full-page archival.
karakeep-db	Postgres backend for karakeep.
karakeep-redis	Redis cache for karakeep.
karakeep-meilisearch	Meilisearch backend for karakeep.
synapse	Matrix homeserver. E2E encrypted chat + federation.
synapse-db	Postgres backend for Synapse.
synapse-init	One-shot init: generates homeserver.yaml.
element-web	Element web client for Matrix.
excalidraw	Virtual whiteboard. Hand-drawn diagrams.
siyuan	Privacy-first note-taking. Block-based. Go binary.
rsshub	RSS feed generator (works with miniflux).
passbolt	Team password manager with GPG encryption. OpenPGP + audit logs.
passbolt-db	MariaDB backend for passbolt.
aliasvault	Privacy-first password manager + email aliasing. E2E encrypted.
psono-db	MariaDB backend for psono.
psono-server	Enterprise password + secret sharing. Supports offline clients.
infisical	Secrets management for devs. Vault/Doppler alternative. PKI + dynamic secrets.
infisical-db	Postgres backend for infisical.
infisical-redis	Redis cache for infisical.
kavita	Manga/comics/book reader with library management.
linkwarden-db	Postgres backend for linkwarden.
linkwarden-meilisearch	Search engine for linkwarden bookmarks.
linkwarden	Bookmark manager with full-page archival. Self-hosted.
memos	Lightweight notes + microblog. Markdown, tagging, sharing.
metube	Self-hosted YouTube downloader. yt-dlp + web UI.
movim-db	Postgres backend for movim.
movim	XMPP social network. Microblogging, groups, file sharing.
netalertx	Network scanner + device tracker with alerts.
navidrome	Music streaming server. Subsonic-compatible.
ntfy	Push notification server. Subscribe via app, send via HTTP API.
ollama	Local LLM runner. Llama, Mistral, Phi, etc.
olivetin	Web button panel for shell commands. Safe admin actions.
onedev	Git + CI/CD + Kanban. Self-hosted GitHub alternative.
opengist	Git-backed pastebin. Code snippets with version history.
openemr-db	MariaDB backend for OpenEMR.
openemr	Electronic medical records system. HIPAA-aware.
open-webui	ChatGPT-style web UI for ollama and other LLMs.
paperless-db	Postgres backend for paperless-ngx.
paperless-redis	Redis broker for paperless-ngx.
paperless-ngx	Document management with OCR. Tags, correspondents, search.
phatcrack-db	Postgres backend for phatcrack.
phatcrack-api	Hashcat web service. Distributed GPU hash cracking.
phatcrack-frontend	Web UI for phatcrack.
pigallery2	Photo gallery. Fast directory-first viewer.
pingvin-share	File sharing service. Share files with anyone via link.
prowlarr	Indexer manager for *arr suite. Aggregates torrent indexers.
qbittorrent	Torrent client with web UI.
qbittorrent-init	One-shot init: configures qbittorrent.
rustdesk-hbbs	RustDesk relay server (ID/relay).
rustdesk-hbbr	RustDesk relay server (relay only).
solidtime	Time tracking for freelancers and teams.
shhh	Encrypted secret sharing with simple UI.
searxng	Metasearch engine. Aggregates Google, Bing, DuckDuckGo without tracking.
searxng-redis	Redis broker for searxng result caching.
seafile-memcached	Memcached for seafile.
seafile-db	MariaDB backend for seafile.
seafile-auto-config	Post-deploy config bootstrap for seafile.
seafile	File sync, share, and collaboration. Seafile-pro compatible.
stirling-pdf	PDF toolkit. 50+ operations: merge, split, convert, OCR.
super-productivity	Task tracker with time-blocking, tags, integrations.
twofauth	2FA TOTP token manager. Self-hosted Authy/Google Authenticator.
upsnap	Wake-on-LAN with web UI.
wallos	Subscription tracker with currency support.
watchtower	Auto-updates running containers to latest image.
whois	WHOIS / RDAP lookup web UI.
zerotier-init	One-shot init: writes local zerotier config.
zerotier	Mesh VPN client. Joins network from ZEROTIER_NETWORK_ID.
uptime-kuma	Uptime monitor. HTTP/TCP/ping checks with status page.
nodered	Node-RED. Visual wiring for IoT automations (mqtt, http, gpio).
nodered-init	One-shot init: chowns Node-RED data dir to match runtime user.
snikket-server	Snikket XMPP server (Prosody). Personal messaging for the household.
snikket-proxy	Snikket web reverse-proxy. ACME HTTP-01 challenges + TLS termination.
snikket-portal	Snikket web portal. Self-service account creation/invite UI.
snikket-certs	Snikket ACME cert manager. Renews Let's Encrypt certs.
flaresolverr	Cloudflare challenge solver. Proxy for *arr / web scrapers.
calibre-web	Calibre content server. Browse/read epub library in browser.
radarr	Movie collection manager. Watches *arr and triggers qbittorrent.
sonarr	TV series collection manager. Watches *arr and triggers qbittorrent.
minecraft	Minecraft Java/Bedrock server. Multi-version, easy config via env.
managemeals	Meal-planning + recipe + grocery list. Multi-user household.
myspeed	Self-hosted speedtest with rolling history and per-server graph.
convertx	Self-hosted file converter. ffmpeg / pandoc / image / pdf / etc.
HINTS
}

# Look up the hint. Print "(no description)" when unknown.
if [ "$KIND" = "category" ]; then
  hint="$(category_hints | awk -F'\t' -v n="$name" '$1 == n { sub(/^[^\t]+\t/, ""); print; exit }')"
elif [ "$KIND" = "service" ]; then
  hint="$(service_hints | awk -F'\t' -v n="$name" '$1 == n { sub(/^[^\t]+\t/, ""); print; exit }')"
else
  hint="(unknown kind: $KIND)"
fi

if [ -z "$hint" ]; then
  hint="(no description for '$name')"
fi

# Highlight the name in the output for visual clarity.
printf '\033[1m%s\033[0m\n%s\n' "$name" "$hint"