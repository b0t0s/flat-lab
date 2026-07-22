# syntax=docker/dockerfile:1
#
# House style: one comment line = one statement.
# A new line starts a new statement about a different thing.
# Multi-line soft-wrapped prose is not used in this file.
# The same rule applies to docker-compose.yml and caddy/Caddyfile.
# See docs/services/README.md ("House style") for the long version.
#
# Containerised ZeroTier One for Docker-only Linux hosts (Pi, etc.).
# Updated to debian:bullseye-slim to resolve upstream repository 404 errors (Buster EOL).
#
# Listens on UDP 9993 for planet/moon traffic.
# Requires NET_ADMIN and /dev/net/tun on the host (compose grants both).

FROM debian:bullseye-slim AS builder

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl gnupg ca-certificates \
 && curl -fsSL https://raw.githubusercontent.com/zerotier/ZeroTierOne/main/doc/contact%40zerotier.com.gpg \
    | gpg --dearmor -o /usr/share/keyrings/zerotier.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/zerotier.gpg] http://download.zerotier.com/debian/bullseye bullseye main" \
    > /etc/apt/sources.list.d/zerotier.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends zerotier-one \
 && rm -rf /var/lib/apt/lists/*

FROM debian:bullseye-slim

LABEL description="Containerized ZeroTier One for use on Docker-only Linux hosts (Pi)."

# ZeroTier control plane / peer traffic
EXPOSE 9993/udp

# The daemon's own HTTP control socket (used by ztncui and the CLI)
EXPOSE 9993/tcp

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates iproute2 \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/lib/zerotier-one

COPY --from=builder /usr/sbin/zerotier-one   /usr/sbin/zerotier-one
COPY --from=builder /usr/sbin/zerotier-cli    /usr/sbin/zerotier-cli
COPY --from=builder /usr/sbin/zerotier-idtool /usr/sbin/zerotier-idtool

# Tiny wrapper that runs the daemon in the foreground.
# Keeps the container alive and exposes the CLI on $PATH for exec-in.
RUN printf '#!/bin/sh\nexec /usr/sbin/zerotier-one "$@"\n' > /usr/local/bin/zerotier-entrypoint.sh \
 && chmod 0755 /usr/local/bin/zerotier-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/zerotier-entrypoint.sh"]
CMD []