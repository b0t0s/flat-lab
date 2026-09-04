#!/usr/bin/env bash
# audit-env.sh — scan compose-*.yml files for required environment variables.
# Reports which vars each compose file references, which have defaults, and
# which are still set to __PLACEHOLDER_*__ in .env. Designed to catch
# "POSTGRES_PASSWORD not specified" before docker compose up.
#
# Usage:
#   ./scripts/audit-env.sh             # audit + report only
#   ./scripts/audit-env.sh --generate  # audit + write fresh secrets to .env
#
# Exit codes:
#   0 — all required vars are set to real values (no __PLACEHOLDER_*__)
#   1 — at least one required secret is missing or still a placeholder
#   2 — .env is missing entirely (operator should copy from .env.example)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_DIR="$REPO_ROOT"
COMPOSE_PREFIX="compose-"
ENV_FILE="$COMPOSE_DIR/.env"
GENERATE=0
[ "${1:-}" = "--generate" ] && GENERATE=1

cd "$COMPOSE_DIR" || exit 2

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env not found at $ENV_FILE" >&2
  echo "       Copy from .env.example first:  cp .env.example .env" >&2
  exit 2
fi

# Load current .env (skip comments and blank lines).
declare -A env_value
while IFS= read -r line; do
  line="${line%%#*}"
  line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
    env_value["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  fi
done < "$ENV_FILE"

# Scan all compose files for ${VAR} and ${VAR:-default} references.
declare -A required_vars   # var -> "file1 file2 ..."
declare -A optional_vars   # var -> "file1 file2 ..."
for f in "${COMPOSE_PREFIX}"*.yml; do
  [ -f "$f" ] || continue
  while IFS= read -r match; do
    [ -z "$match" ] && continue
    var="${match%%:*}"
    if [[ "$match" == *":-"* ]]; then
      optional_vars["$var"]="${optional_vars[$var]:-} $f"
    else
      required_vars["$var"]="${required_vars[$var]:-} $f"
    fi
  done < <(grep -oE '\$\{[A-Z_][A-Z0-9_]*(:-[^}]*)?\}' "$f" | sed 's/[${}]//g')
done

# Check which required vars are missing or still placeholders.
unset_missing=()
unset_placeholder=()
unset_ok=()

for var in "${!required_vars[@]}"; do
  val="${env_value[$var]:-}"
  if [ -z "$val" ]; then
    unset_missing+=("$var")
  elif [[ "$val" == __PLACEHOLDER_*__ ]]; then
    unset_placeholder+=("$var")
  else
    unset_ok+=("$var")
  fi
done

# Sort for stable output.
IFS=$'\n' unset_missing=($(printf '%s\n' "${unset_missing[@]}" | sort -u))
IFS=$'\n' unset_placeholder=($(printf '%s\n' "${unset_placeholder[@]}" | sort -u))
IFS=$'\n' unset_ok=($(printf '%s\n' "${unset_ok[@]}" | sort -u))
unset IFS

echo "=== compose env audit ==="
echo
echo "Scanned $(ls "${COMPOSE_PREFIX}"*.yml | wc -l) compose files in $COMPOSE_DIR"
echo
echo "Required vars found:        ${#unset_ok[@]}"
echo "Required vars MISSING:      ${#unset_missing[@]}"
echo "Required vars PLACEHOLDER:  ${#unset_placeholder[@]}"
echo "Optional vars:              ${#optional_vars[@]}"
echo

# Sort required by source file
declare -A file_to_vars
for var in "${!required_vars[@]}"; do
  for f in ${required_vars[$var]}; do
    file_to_vars["$f"]="${file_to_vars[$f]:-} $var"
  done
done

# Generate mode: write fresh secrets to .env
if [ "$GENERATE" -eq 1 ] && { [ "${#unset_missing[@]}" -gt 0 ] || [ "${#unset_placeholder[@]}" -gt 0 ]; }; then
  echo "=== Generating fresh secrets for ${#unset_missing[@]} missing + ${#unset_placeholder[@]} placeholder vars ==="
  echo

  # Backup before writing
  cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d-%H%M%S)"

  # Append or update each missing var
  declare -A new_values
  for var in "${unset_missing[@]}" "${unset_placeholder[@]}"; do
    # Match the var name pattern to pick a sensible generator
    case "$var" in
      *_USER|*_ADMIN_USER|*USER)
        new_val="admin"
        ;;
      *_EMAIL|*EMAIL)
        new_val="admin@example.com"
        ;;
      *_URL|*URL|*_HOSTNAME)
        new_val="https://example.com"
        ;;
      *_API_KEY)
        # RDAP/WHOIS-style 32-char hex
        new_val="$(openssl rand -hex 16)"
        ;;
      *_KEY|*_SECRET|*_PASSWORD|*_PASS|*_HASH|*_TOKEN)
        # 32-char URL-safe base64
        new_val="$(openssl rand -base64 36 | tr -d '/+=' | head -c 32)"
        ;;
      *)
        new_val="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
        ;;
    esac
    new_values["$var"]="$new_val"
  done

  # Rewrite .env: keep comments + existing vars, replace __PLACEHOLDER_*__,
  # append missing ones at the bottom in a generated section.
  tmp_env="$(mktemp)"
  declare -A written
  while IFS= read -r line; do
    if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)= ]]; then
      var="${BASH_REMATCH[1]}"
      if [ -n "${new_values[$var]:-}" ]; then
        echo "${var}=${new_values[$var]}" >> "$tmp_env"
        written["$var"]=1
      else
        echo "$line" >> "$tmp_env"
      fi
    else
      echo "$line" >> "$tmp_env"
    fi
  done < "$ENV_FILE"

  # Append any vars that weren't in the file
  appended=0
  for var in "${!new_values[@]}"; do
    [ -n "${written[$var]:-}" ] && continue
    echo "${var}=${new_values[$var]}" >> "$tmp_env"
    appended=$((appended + 1))
  done

  if [ "$appended" -gt 0 ]; then
    echo "" >> "$tmp_env"
    echo "## =========================================" >> "$tmp_env"
    echo "## Generated by audit-env.sh $(date +%Y-%m-%d)" >> "$tmp_env"
    echo "## =========================================" >> "$tmp_env"
  fi

  mv "$tmp_env" "$ENV_FILE"
  chmod 600 "$ENV_FILE"  # match the original permissions

  echo "Wrote $(( ${#unset_missing[@]} + ${#unset_placeholder[@]} )) new values to $ENV_FILE"
  echo "Backup: $ENV_FILE.bak.$(date +%Y%m%d-%H%M%S)"
  exit 0
fi

if [ "${#unset_missing[@]}" -gt 0 ] || [ "${#unset_placeholder[@]}" -gt 0 ]; then
  echo "=== ACTION REQUIRED ==="
  echo
  if [ "${#unset_missing[@]}" -gt 0 ]; then
    echo "Variables not set in .env:"
    for var in "${unset_missing[@]}"; do
      printf "  %-40s  ← %s\n" "$var" "${required_vars[$var]}"
    done
    echo
  fi
  if [ "${#unset_placeholder[@]}" -gt 0 ]; then
    echo "Variables still set to __PLACEHOLDER_*__:"
    for var in "${unset_placeholder[@]}"; do
      printf "  %-40s  ← %s\n" "$var" "${required_vars[$var]}"
    done
    echo
  fi
  echo "Fix: edit .env and replace placeholders with real values."
  echo "     Or generate fresh secrets:  ./scripts/audit-env.sh --generate"
  exit 1
fi

echo "All required vars are set. Ready to start any category."
exit 0