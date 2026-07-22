---
title: Documentation Index
domain: docs
type: info
status: active
tags: [index, toc, homelab, raspberry-pi]
filed: 2026-07-22
---

# flat-lab Documentation

A single-node, self-hosted home lab on one Raspberry Pi 5 that reaches the internet through exactly one door.
Everything it does is declared in one `docker-compose.yml` and one `caddy/Caddyfile`.
Read those two files and you know the whole system.
This tree explains why the system is shaped the way it is, records the settled decisions, and gives one page per running service.

## The tree

| Folder | What's inside |
|---|---|
| (root) | Index, settled decisions, architecture rationale, services catalogue, future plans |
| [services.md](services.md) | One section per running service, with rationale and rejected alternatives |

## House style

**One line = one statement.** A new line starts a new statement about a different thing.
This rule applies to every text file in the repo: markdown, `docker-compose.yml` (comment lines), `caddy/Caddyfile` (comment lines), and every `Dockerfile` (comment lines).
Tables, code blocks, YAML frontmatter, list items with indented continuation, and headings keep their conventional multi-line shape.

When a change to the compose file or Caddyfile makes a doc stale, fix the doc in the same change -- a stale runbook is worse than none.