# scripts

Helper scripts for managing the flat-lab compose stack.

## compose-tui.sh

Interactive TUI for selecting and operating on services across the 18 `compose-*.yml` files.

### Flow

1. **Categories** — pick one or more categories with SPACE. ENTER to confirm. Right pane shows a one-line description of the highlighted category.
2. **Services** — pick one or more services inside the selected categories with SPACE. ENTER to confirm. Right pane shows the service's description.
3. **Status preview** — the TUI prints `[RUN] / [STOP] / [ABSENT] / [HEALTH]` for each selected service so you see what you're about to touch. `docker compose ps` powers this.
4. **Action** — pick one of `up / down / restart / ps / logs / pull / rm`. ENTER to run.
5. The TUI runs `docker compose -f docker-compose.yml <action> <service1> <service2>`. The wrapper `docker-compose.yml` uses `include:` to pull in each `compose-*.yml`.

ESC backs up one step at any menu. Empty selection at categories exits.

### Persistence

The last selection (categories + services) is saved to `~/.config/flat-lab-tui/state` after every successful run. On the next launch, the same items are pre-toggled — press ENTER to skip re-selecting.

- Reset: `./scripts/compose-tui.sh --clear-state`

### Quick start

```bash
# One-time install on the Pi (uses apt, not brew)
sudo apt install fzf

# First-time setup wizard — checks .env, network, fzf
./scripts/compose-tui.sh --setup

# Populate .env with fresh secrets for any missing required vars
./scripts/compose-tui.sh --audit-generate

# Launch the menu
./scripts/compose-tui.sh

# Or run a single action non-interactively
./scripts/compose-tui.sh up jellyfin navidrome
./scripts/compose-tui.sh down
./scripts/compose-tui.sh ps
./scripts/compose-tui.sh logs --tail=50

# Category-level shortcut: pass a category name to act on every service in it
./scripts/compose-tui.sh up system
./scripts/compose-tui.sh up system network
./scripts/compose-tui.sh restart smarthome

# Mixed: category + specific service
./scripts/compose-tui.sh up system caddy

# Cross-category shortcuts
./scripts/compose-tui.sh ps-all         # status of every category, grouped
./scripts/compose-tui.sh up-all        # start everything
./scripts/compose-tui.sh down-all      # stop everything

# Admin actions
./scripts/compose-tui.sh --validate    # parse-check every compose file
./scripts/compose-tui.sh --audit       # show missing env vars
./scripts/compose-tui.sh --clear-state # reset saved menu selection

# Help
./scripts/compose-tui.sh --help
```

The first time it runs, it creates the external `homelab_net` Docker network if missing.

### Why fzf

fzf is the only common tool that natively supports space-as-toggle for multi-select (`--bind space:toggle --multi`). `whiptail` and `dialog` only support Tab/Enter for checkbox lists. fzf is in Debian's apt repo (`apt install fzf`, ~2 MB).

## audit-env.sh

One-shot script that scans every `compose-*.yml` and reports which environment variables are referenced. For each `__PLACEHOLDER_*__` value still present in `.env`, it flags the line. Use this when a service crashes with "POSTGRES_PASSWORD not set" or "MEILI_MASTER_KEY too short".

```bash
./scripts/audit-env.sh
```

Useful for:

- Onboarding: which secrets do I need before I can boot a category?
- After adding a new service: did the new compose file introduce vars that aren't in `.env.example`?
- Pre-commit: catch missing env vars before `docker compose up` fails on the Pi.

With `--generate` the script writes fresh random secrets to `.env` (backing the original up first):

```bash
./scripts/audit-env.sh --generate
```

Exit codes:

- `0` — all required vars are set (placeholders may still exist but only in `.env.example`, not `.env`)
- `1` — at least one required secret is unset in `.env`
- `2` — `.env` is missing entirely (copy from `.env.example` first)

## preview.sh

Helper invoked by `compose-tui.sh` whenever fzf shows the right-hand preview pane. Runs as a separate process because fzf invokes `--preview` via `sh -c`, which can't see bash functions defined in the parent script. The hint tables live here so they're editable in one place without touching the TUI.

You generally don't call this directly — `compose-tui.sh` does it. If you want to test or extend the hint list, edit the `category_hints` and `service_hints` heredocs.
