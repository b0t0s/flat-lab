#!/usr/bin/env bash
# compose-tui.sh — flat-lab compose manager
# SPACE=toggle, ENTER=confirm, ESC=back, Q=quit
# Two-level selection: categories first, then services within selected.
# Runs docker compose with explicit service names.
set -euo pipefail

# ---------- CONFIG ----------
COMPOSE_DIR="${COMPOSE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
COMPOSE_PREFIX="compose-"
NETWORK_NAME="homelab_net"
ACTION="${1:-menu}"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/flat-lab-tui"
STATE_FILE="$STATE_DIR/state"
# Resolve scripts dir to absolute path so fzf's preview pane can find
# preview.sh regardless of the operator's current working directory.
# fzf runs preview commands via sh -c; if the user is in /tmp but the
# script is in ~/repos/flat-lab/scripts, a relative './preview.sh' fails.
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------- HELPERS ----------
die() { echo "ERROR: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
info() { echo "[TUI] $*" >&2; }

# Discover categories: every compose-*.yml at repo root.
discover_categories() {
  find "$COMPOSE_DIR" -maxdepth 1 -name "${COMPOSE_PREFIX}*.yml" -printf "%f\n" \
    | sed "s/^${COMPOSE_PREFIX}//; s/\.yml$//" \
    | sort
}

# Count services per category. Only counts top-level keys inside `services:`.
count_services() {
  local cat="$1"
  local file="$COMPOSE_DIR/${COMPOSE_PREFIX}${cat}.yml"
  [ -f "$file" ] || { echo 0; return; }
  awk '
    /^services:[[:space:]]*$/ { in_svc=1; next }
    in_svc && /^[^[:space:]]/ { in_svc=0 }
    in_svc && /^  [a-z][a-z0-9_-]*:[[:space:]]*$/ { count++ }
    END { print count+0 }
  ' "$file"
}

# List services in a category. Excludes networks/volumes top-level keys.
list_services() {
  local cat="$1"
  local file="$COMPOSE_DIR/${COMPOSE_PREFIX}${cat}.yml"
  [ -f "$file" ] || return 0
  awk '
    /^services:[[:space:]]*$/ { in_svc=1; next }
    in_svc && /^[^[:space:]]/ { in_svc=0 }
    in_svc && /^  [a-z][a-z0-9_-]*:[[:space:]]*$/ {
      # Capture the service name (letters, digits, hyphen, underscore).
      # The leading two-space indent is matched by the regex but not part of the name.
      match($0, /[a-z][a-z0-9_-]*/)
      print substr($0, RSTART, RLENGTH)
    }
  ' "$file"
}

ensure_fzf() {
  if ! have fzf; then
    die "fzf not installed. Run: apt install fzf"
  fi
}

# ---------- STATE PERSISTENCE ----------
# Two-line file: line 1 = selected categories (space-separated), line 2 = services (space-separated).
# On selection, we save so the next launch can pre-toggle them.
load_state() {
  STATE_CATS=""
  STATE_SERVICES=""
  [ -f "$STATE_FILE" ] || return 0
  STATE_CATS=$(awk 'NR==1' "$STATE_FILE")
  STATE_SERVICES=$(awk 'NR==2' "$STATE_FILE")
}

save_state() {
  mkdir -p "$STATE_DIR"
  {
    printf '%s\n' "$1"
    printf '%s\n' "$2"
  } > "$STATE_FILE"
}

# ---------- NETWORK ----------
ensure_network() {
  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    info "creating external network $NETWORK_NAME"
    docker network create "$NETWORK_NAME" >/dev/null
  fi
}

# ---------- UI: pick categories ----------
# Format: "<marker> <cat> (N services)" — first field is marker, second is the category.
# Marker is "-" for unselected, "X" for pre-selected (from saved state).
# Args: $1 = space-separated list of categories to pre-select.
pick_categories() {
  local preselect="$1"
  local tmpfile="$COMPOSE_DIR/.tui-categories.tmp"
  : > "$tmpfile"
  while IFS= read -r cat; do
    local count
    count=$(count_services "$cat")
    local marker="-"
    if [ -n "$preselect" ] && printf '%s\n' "$preselect" | grep -qw -- "$cat"; then
      marker="X"
    fi
    printf '%s %s (%s services)\n' "$marker" "$cat" "$count" >> "$tmpfile"
  done < <(discover_categories)

  # Pre-select mechanism: we use `--multi` with no pre-selection. Earlier
  # versions of this script used `--bind 'start:transform:...'` to pre-toggle
  # items based on saved state, but fzf 0.35+ on some platforms rejects the
  # transform action with "unknown action: transform:" even when given a valid
  # expression. We disable pre-selection; the operator space-toggles to pick.
  # The trade-off is no auto-restore on launch (use --clear-state to wipe the
  # old state file). The menu still works.

  local result
  result=$(fzf --multi \
      --prompt="categories > " \
      --header=$'SPACE=toggle  ENTER=confirm  ESC=quit' \
      --bind='space:toggle' \
      --marker='X' \
      --tac \
      --no-sort \
      --preview="$SCRIPTS_DIR/preview.sh category {}" \
      --preview-window='right:50%:wrap' \
      < "$tmpfile" \
    | awk '{print $2}') || true
  rm -f "$tmpfile"
  printf '%s' "$result"
}

# ---------- UI: pick services within categories ----------
# Format: "<marker> <svc>  (<cat>)" — first field is marker, second is service name.
# Marker is "-" for unselected, "X" for pre-selected.
# Preselect mechanism: fzf's `--bind 'start:transform:'` runs an awk over
# the tmpfile on startup and emits "+select+down" for every line starting
# with "X", then "+first" to put the cursor back at the top.
# Args: $1 = space-separated list of selected categories,
#       $2 = space-separated list of services to pre-select.
pick_services() {
  local selected_cats="$1"
  local preselect="$2"
  local tmpfile="$COMPOSE_DIR/.tui-services.tmp"
  : > "$tmpfile"
  for cat in $selected_cats; do
    while IFS= read -r svc; do
      [ -z "$svc" ] && continue
      local marker="-"
      if [ -n "$preselect" ] && printf '%s\n' "$preselect" | grep -qw -- "$svc"; then
        marker="X"
      fi
      printf '%s %s  (%s)\n' "$marker" "$svc" "$cat" >> "$tmpfile"
    done < <(list_services "$cat")
  done

  # Pre-select disabled — see pick_categories for rationale. fzf 0.35+ on
  # some platforms rejects start:transform. We use plain --multi; operator
  # space-toggles to pick. The saved state file is still useful (so the
  # operator can see last session in ~/.config/flat-lab-tui/state) but it
  # isn't auto-restored on next launch.

  local result
  result=$(fzf --multi \
      --prompt="services > " \
      --header=$'SPACE=toggle  ENTER=confirm  ESC=back' \
      --bind='space:toggle' \
      --marker='X' \
      --with-nth='2..' \
      --delimiter=' ' \
      --preview="$SCRIPTS_DIR/preview.sh service {}" \
      --preview-window='right:50%:wrap' \
      < "$tmpfile" \
    | awk '{print $2}') || true
  rm -f "$tmpfile"
  printf '%s' "$result"
}

# ---------- SERVICE & CATEGORY HINTS ----------
# Hint tables live in a separate script (scripts/preview.sh) so fzf's preview
# pane — which runs each command via `sh -c` — can find them. Inlining the
# lookup into a single `awk` pipeline would also work, but two files keeps
# the hint data editable without touching the TUI dispatch logic.

pick_action() {
  printf '%s\n' \
    "up      start selected services" \
    "down    stop selected services" \
    "restart restart selected services" \
    "ps      list selected services status" \
    "logs    tail logs of selected services" \
    "pull    pull images for selected services" \
    "rm      remove stopped containers" \
  | fzf --prompt="action > " \
        --header=$'ENTER=confirm  ESC=back' \
        --no-multi \
  | awk '{print $1}'
}

# ---------- STATUS PREVIEW ----------
# Show running/stopped/absent state for the given services. For running
# containers we also show the health status (when docker knows it) and the
# image version so the operator can spot outdated or broken deployments
# before pulling the trigger.
# Args: one or more service names. Output: human-friendly report to stderr.
# Returns: 0 always (errors from `docker compose ps` are swallowed).
show_status() {
  local -a flags
  while IFS= read -r line; do flags+=("$line"); done < <(build_compose_flags)

  # docker compose ps returns one line per service with --format Service|State|Health.
  # We collect them into an assoc array for lookup.
  local -A state_map
  local -A health_map
  local -A image_map
  while IFS=$'\t' read -r n s h img; do
    [ -z "$n" ] && continue
    state_map["$n"]="$s"
    health_map["$n"]="$h"
    image_map["$n"]="$img"
  done < <(docker compose "${flags[@]}" ps --format 'table {{.Service}}\t{{.State}}\t{{.Health}}\t{{.Image}}' 2>/dev/null | tail -n +2 || true)

  local -a selected=("$@")
  local running=0 stopped=0 missing=0 unhealthy=0
  echo "=== current state ===" >&2
  for s in "${selected[@]}"; do
    local state="${state_map[$s]:-not created}"
    local health="${health_map[$s]:-}"
    local image="${image_map[$s]:-}"
    case "$state" in
      running|running*|healthy)
        # Show [RUN] / [HEALTHY] / [STARTING] depending on health status.
        case "$health" in
          healthy)
            printf '  [HEALTH] %-30s  %s\n' "$s" "$image" >&2
            running=$((running+1))
            ;;
          starting|"")
            printf '  [RUN]    %-30s  %s\n' "$s" "$image" >&2
            running=$((running+1))
            ;;
          unhealthy)
            printf '  [SICK]   %-30s  %s\n' "$s" "$image" >&2
            unhealthy=$((unhealthy+1))
            ;;
          *)
            printf '  [RUN:%s] %-30s  %s\n' "$health" "$s" "$image" >&2
            running=$((running+1))
            ;;
        esac
        ;;
      exited|exited*|stopped|dead)
        printf '  [STOP]   %s\n' "$s" >&2
        stopped=$((stopped+1))
        ;;
      *)
        printf '  [ABSENT] %s\n' "$s" >&2
        missing=$((missing+1))
        ;;
    esac
  done
  echo "  total: ${#selected[@]}  running: $running  stopped: $stopped  absent: $missing  sick: $unhealthy" >&2
}

# ---------- DOCKER INVOCATION ----------
# Build the flag list for docker compose. We pass only the wrapper file
# (docker-compose.yml) which uses `include:` to pull in each compose-*.yml.
# We also pass `--profile <cat>` for each selected category so the TUI works
# regardless of whether the operator has set COMPOSE_PROFILES in .env.
#
# Each flag and value is emitted on its own line. When `run_docker` reads
# the output into the flags array, each line becomes one element so that
# docker compose receives them as separate arguments (e.g. "-f" and the path
# as two args, "--profile" and the category name as two args).
# Args: $@ = category names (one or many)
build_compose_flags() {
  printf -- '%s\n' \
    "-f" \
    "$COMPOSE_DIR/docker-compose.yml"
  local cat
  for cat in "$@"; do
    [ -z "$cat" ] && continue
    printf -- '%s\n' \
      "--profile" \
      "$cat"
  done
}

list_all_services() {
  for cat in $(discover_categories); do
    list_services "$cat"
  done
}

run_docker() {
  local action="$1"
  shift
  local services=("$@")
  # Collect the categories to enable. If the operator didn't pick a category
  # (e.g. ran `./compose-tui.sh ps`), enable ALL of them so every service is
  # visible to the command.
  local cats=()
  if [ ${#services[@]} -eq 0 ]; then
    while IFS= read -r c; do cats+=("$c"); done < <(discover_categories)
    while IFS= read -r s; do services+=("$s"); done < <(list_all_services)
  else
    # Determine categories from selected services by looking up each service
    # file. Fall back to all categories if a service can't be located.
    declare -A seen_cats=()
    local svc cat
    for svc in "${services[@]}"; do
      for cat in $(discover_categories); do
        if list_services "$cat" | grep -qx -- "$svc"; then
          [ -z "${seen_cats[$cat]:-}" ] && cats+=("$cat") && seen_cats[$cat]=1
          break
        fi
      done
    done
  fi
  local -a flags
  while IFS= read -r line; do flags+=("$line"); done < <(build_compose_flags "${cats[@]}")
  info "docker compose ${flags[*]} $action ${services[*]}"

  # For up: run detached (-d) so the TUI does NOT attach to the container
  # logs. Without -d, docker compose blocks on the log stream until the
  # operator hits Ctrl-C, which is annoying and meant the operator could
  # not launch more than one batch at a time.
  #
  # For restart: `docker compose restart` is already non-blocking — it
  # sends SIGTERM/SIGHUP and returns immediately. Adding -d here would
  # error with `unknown shorthand flag: 'd' in -d` because `restart`
  # doesn't accept that flag.
  #
  # For ps/logs/down/pull/rm: keep current behaviour — these are
  # short-lived queries and the operator expects to see output.
  local -a detached_args=()
  case "$action" in
    up) detached_args=(-d) ;;
  esac

  docker compose "${flags[@]}" "$action" "${detached_args[@]}" "${services[@]}"
}

# ---------- NON-INTERACTIVE FIRST ----------
# Pre-process: if any argument is a category name (not a service name), expand
# it to all services in that category. This lets you run `./compose-tui.sh up system`
# to start every service in the system category without going through fzf.
expand_category_args() {
  local out=()
  local arg
  for arg in "$@"; do
    if [ -f "$COMPOSE_DIR/${COMPOSE_PREFIX}${arg}.yml" ]; then
      while IFS= read -r svc; do
        [ -z "$svc" ] && continue
        out+=("$svc")
      done < <(list_services "$arg")
    else
      out+=("$arg")
    fi
  done
  printf '%s\n' "${out[@]}"
}

case "$ACTION" in
  -h|--help|help)
    cat <<'EOF'
flat-lab compose manager — interactive + non-interactive control for the 18
compose-*.yml files. Replaces the old Makefile/up.sh.

USAGE
  ./scripts/compose-tui.sh [ACTION] [TARGETS...]

ACTIONS (interactive)
  (no action)                    open the menu: pick categories, services, action

ACTIONS (non-interactive — for cron, scripts, SSH from another machine)
  up <svc|cat> [...]             start the listed services
  down <svc|cat> [...]           stop the listed services
  restart <svc|cat>              restart the listed services
  ps [svc|cat]                   show status (no args = every service)
  logs [svc|cat]                 tail logs (no args = every service)
  pull <svc|cat>                 pull latest images for the listed services
  rm <svc|cat>                   remove stopped containers
  up-all                         start every category
  down-all                       stop every category
  ps-all                         status report grouped by category

ACTIONS (admin / setup)
  --validate                     parse-check every compose file
  --audit                        show .env vars still on __PLACEHOLDER or unset
  --audit-generate               write fresh secrets to .env (backup first)
  --clear-state                  forget the saved menu selection
  -h, --help, help               this help text

TARGETS
  Each TARGET is either a service name (caddy, navidrome) or a category name
  (system, media, bookmarks). Categories expand to all services they contain.
  Mix freely:  ./scripts/compose-tui.sh up system caddy paperless-ngx

EXAMPLES
  ./scripts/compose-tui.sh
      # full menu: pick categories, services, action

  ./scripts/compose-tui.sh up caddy
      # start only the reverse proxy

  ./scripts/compose-tui.sh up system
      # start every service in the 'system' category

  ./scripts/compose-tui.sh up system caddy paperless-ngx
      # start all of 'system' PLUS caddy (already in system, harmless)
      # PLUS paperless-ngx (in 'knowledge')

  ./scripts/compose-tui.sh down-all
      # stop every running service across all categories

  ./scripts/compose-tui.sh logs --tail=100 navidrome
      # tail navidrome logs

  ./scripts/compose-tui.sh --validate
      # check every compose file for parse errors

  ./scripts/compose-tui.sh --audit-generate
      # populate .env with fresh secrets for every required var

PERSISTENCE
  Menu selections are saved to  ~/.config/flat-lab-tui/state  and re-toggled
  on the next menu launch. Reset with --clear-state.

EXIT CODES
  0   success
  1   docker compose or fzf returned non-zero
  2   fzf not installed (run: sudo apt install fzf)
  3   network not creatable
  64  usage error (unknown action / missing required var)
EOF
    exit 0
    ;;
  --clear-state)
    rm -f "$STATE_FILE"
    info "cleared saved selection"
    exit 0
    ;;
  --audit)
    # Cross-category env audit shortcut. Same as ./scripts/audit-env.sh.
    exec "$(dirname "$0")/audit-env.sh" "${@:2}"
    ;;
  --audit-generate)
    # Same as --audit but also writes fresh secrets to .env.
    exec "$(dirname "$0")/audit-env.sh" --generate
    ;;
  --setup)
    # First-time onboarding wizard. Walks the operator through:
    #   1. .env exists? (copy from .env.example if missing)
    #   2. env vars audit (run --audit, prompt for --audit-generate)
    #   3. external network homelab_net exists?
    #   4. fzf installed?
    #   5. show profile list and current .env selection
    info "=== flat-lab first-time setup ==="
    echo

    # 1. .env exists?
    if [ ! -f "$COMPOSE_DIR/.env" ]; then
      info "[1/5] .env is missing."
      info "      Copy from template:  cp .env.example .env"
      info "      Then fill in tokens, network IDs, hostnames."
      exit 1
    fi
    info "[1/5] .env exists ✓"

    # 2. env audit
    info "[2/5] checking env vars..."
    if "$(dirname "$0")/audit-env.sh" >/dev/null 2>&1; then
      info "      ✓ all required secrets are set"
    else
      info "      ⚠ some required vars are missing or still placeholders."
      info "      run:  ./scripts/compose-tui.sh --audit-generate"
    fi

    # 3. external network
    info "[3/5] checking homelab_net..."
    if docker network inspect homelab_net >/dev/null 2>&1; then
      info "      ✓ homelab_net exists"
    else
      info "      creating homelab_net..."
      docker network create homelab_net
    fi

    # 4. fzf
    info "[4/5] checking fzf..."
    if have fzf; then
      info "      ✓ fzf installed"
    else
      info "      ⚠ fzf missing. Install with:  sudo apt install fzf"
    fi

    # 5. profile list + .env COMPOSE_PROFILES
    info "[5/5] compose profiles (from .env):"
    profiles=$(grep -E "^COMPOSE_PROFILES=" "$COMPOSE_DIR/.env" | head -1 | cut -d= -f2-)
    info "      $profiles"
    info ""
    info "Available categories (defined in compose-*.yml):"
    for cat in $(discover_categories); do
      count=$(count_services "$cat")
      info "      $cat ($count services)"
    done

    info ""
    info "Next steps:"
    info "  • Run ./scripts/compose-tui.sh to open the interactive menu"
    info "  • Or run ./scripts/compose-tui.sh up <category> to start a category"
    info "  • Edit COMPOSE_PROFILES in .env to set which categories start by default"
    exit 0
    ;;
  --validate)
    # Validate every compose file by running docker compose config across
    # all profiles. Reports parse errors, missing env vars, duplicate
    # container names, and unknown networks.
    info "validating all compose files..."
    declare -A errors_per_file=()
    cats=$(discover_categories)
    for cat in $cats; do
      file="${COMPOSE_PREFIX}${cat}.yml"
      # grep returns 1 when no matches found, which would trip pipefail.
      # Use `|| true` to swallow the no-error case.
      # The regex matches only real error patterns (not flags like --show-error):
      #   "error: ..."       (compose error message)
      #   "Error: ..."       (with capital)
      #   "additional property X not allowed"
      #   "field X is required"
      #   "undefined volume X" or "undefined network X"
      err=$(docker compose -f "$COMPOSE_DIR/docker-compose.yml" -f "$COMPOSE_DIR/$file" --profile "$cat" config 2>&1 | grep -iE "(^error|^[A-Z]+[Ee]rror:|additional property|undefined (volume|network|service)|is required|unknown)" | grep -v "level=warning" | head -3 || true)
      if [ -n "$err" ]; then
        errors_per_file["$file"]="$err"
      fi
    done
    if [ "${#errors_per_file[@]}" -eq 0 ]; then
      info "all $(echo "$cats" | wc -w) compose files: OK"
    else
      info "VALIDATION FAILED in ${#errors_per_file[@]} file(s):"
      for f in "${!errors_per_file[@]}"; do
        echo "--- $f ---"
        echo "${errors_per_file[$f]}"
      done
      exit 1
    fi
    exit 0
    ;;
  ps-all)
    # Show running status of every service across all categories.
    ensure_fzf  # ensures docker is reachable
    info "status of every service across all categories:"
    cats=$(discover_categories)
    for cat in $cats; do
      printf '\n--- %s ---\n' "$cat"
      docker compose -f "$COMPOSE_DIR/docker-compose.yml" --profile "$cat" ps 2>&1 | grep -v "level=warning" | head -20
    done
    exit 0
    ;;
  up-all)
    # Start every service across all categories.
    ensure_network
    cats=$(discover_categories)
    info "starting every category: $cats"
    declare -a all_flags
    while IFS= read -r line; do all_flags+=("$line"); done < <(build_compose_flags $cats)
    docker compose "${all_flags[@]}" up -d
    exit $?
    ;;
  down-all)
    ensure_network
    cats=$(discover_categories)
    info "stopping every category: $cats"
    declare -a all_flags
    while IFS= read -r line; do all_flags+=("$line"); done < <(build_compose_flags $cats)
    docker compose "${all_flags[@]}" down
    exit $?
    ;;
  up|down|restart|ps|logs|pull|rm)
    ensure_fzf
    ensure_network
    shift
    # If no service args given, default to the full category set so the
    # operator gets a global ps/logs/etc without going through the picker.
    if [ $# -eq 0 ]; then
      set -- $(discover_categories)
    fi
    # Expand any category names to their constituent services.
    # Pass-through service names unchanged.
    expanded=$(expand_category_args "$@")
    # shellcheck disable=SC2086
    run_docker "$ACTION" $expanded
    exit $?
    ;;
  menu|"")
    ensure_fzf
    ensure_network
    cd "$COMPOSE_DIR"
    load_state
    while true; do
      echo "=== flat-lab compose manager ===" >&2

      selected_cats=$(pick_categories "$STATE_CATS")
      if [ -z "$selected_cats" ]; then
        info "no categories selected, exiting"
        exit 0
      fi

      selected_services=$(pick_services "$selected_cats" "$STATE_SERVICES")
      if [ -z "$selected_services" ]; then
        info "no services selected, going back"
        continue
      fi

      # Convert newline-separated selection into array for status + docker run.
      # shellcheck disable=SC2206
      selected_arr=($selected_services)

      # Show the current state of every selected service before asking
      # for an action. The operator sees what they're about to touch.
      show_status "${selected_arr[@]}"

      action=$(pick_action)
      if [ -z "$action" ]; then
        info "no action chosen, going back"
        continue
      fi

      # Persist this selection so the next launch pre-toggles the same items.
      save_state "$selected_cats" "$selected_services"

      # Execute the docker command and tee everything to a dated log file
      # under $STATE_DIR/logs/. The TUI prints the command first so the
      # operator sees exactly what ran, then runs it (via run_docker) and
      # captures full stdout+stderr in the log via `tee -a`. On exit the
      # operator can `tail -f ~/.config/flat-lab-tui/logs/<latest>.log`
      # to follow, or just read it back.
      logdir="$STATE_DIR/logs"
      mkdir -p "$logdir"
      ts="$(date +%Y%m%d-%H%M%S)"
      logfile="$logdir/${action}-${ts}.log"
      flags_file="$(mktemp)"
      build_compose_flags > "$flags_file"
      flags_str="$(paste -sd' ' "$flags_file")"

      # For up, run_docker adds -d so we don't attach to logs.
      # For restart, `docker compose restart` is already non-blocking.
      # Show the relevant flag in both the banner and the logged command
      # line so the operator can replay the command later by copy-paste.
      case "$action" in
        up) detached_flag="-d" ;;
        *)  detached_flag="" ;;
      esac

      info "running:"
      info "  cd $COMPOSE_DIR && docker compose $flags_str $action $detached_flag $selected_services"
      info "logging to: $logfile"
      echo

      {
        printf '# flat-lab TUI run\n'
        printf '# command: cd %s && docker compose %s %s %s %s\n' \
          "$COMPOSE_DIR" \
          "$flags_str" \
          "$action" \
          "$detached_flag" \
          "$selected_services"
        printf '# started: %s\n' "$(date -Iseconds)"
        printf '# ----\n'
      } > "$logfile"
      rm -f "$flags_file"

      # Run docker. Output goes to BOTH the terminal (operator sees live
      # progress, SearXNG engine errors, etc.) AND the logfile.
      # shellcheck disable=SC2086
      run_docker "$action" $selected_services 2>&1 | tee -a "$logfile"
      rc=${PIPESTATUS[0]}

      printf '# ----\n# finished: %s (exit %s)\n' "$(date -Iseconds)" "$rc" >> "$logfile"
      info "exit code: $rc"
      info "log saved: $logfile"
      exit $rc
    done
    ;;
  *)
    die "unknown action: $ACTION

Usage:
  ./scripts/compose-tui.sh                          interactive menu
  ./scripts/compose-tui.sh up <svc|cat> [...]      start services
  ./scripts/compose-tui.sh down <svc|cat> [...]    stop services
  ./scripts/compose-tui.sh restart <svc|cat>       restart services
  ./scripts/compose-tui.sh ps [svc|cat]             list status (no args = all)
  ./scripts/compose-tui.sh logs [svc|cat]           tail logs (no args = all)
  ./scripts/compose-tui.sh pull <svc|cat>           pull images
  ./scripts/compose-tui.sh rm <svc|cat>             remove stopped containers
  ./scripts/compose-tui.sh up-all                   start every category
  ./scripts/compose-tui.sh down-all                 stop every category
  ./scripts/compose-tui.sh ps-all                   status of every category
  ./scripts/compose-tui.sh --validate               validate all compose files
  ./scripts/compose-tui.sh --audit                  check .env for missing vars
  ./scripts/compose-tui.sh --audit-generate         write fresh secrets to .env
  ./scripts/compose-tui.sh --clear-state            reset saved selection

Service or category args both work:
  ./scripts/compose-tui.sh up caddy                 # one service
  ./scripts/compose-tui.sh up system                # all services in category
  ./scripts/compose-tui.sh up system caddy          # mix"
    ;;
esac
