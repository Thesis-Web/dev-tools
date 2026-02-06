#!/bin/bash
set -euo pipefail

# ========= Local source =========
WIN_DL="/mnt/c/Users/james/Downloads"
PROCESSED_DIR="$WIN_DL/_processed"
mkdir -p "$PROCESSED_DIR"

# ========= Remote destination =========
DROPLET_USER="deploy"
DROPLET_HOST="146.190.139.104"

# Where repos live on the droplet:
REMOTE_BASE="/home/deploy/repos"

# After successful upload:
#   move = move original into Downloads/_processed
#   delete = delete original from Downloads
#   keep = keep original in Downloads
AFTER="${AFTER:-move}"   # move|delete|keep

# If destination exists:
#   overwrite = replace destination
#   skip = don't upload
ON_CONFLICT="${ON_CONFLICT:-overwrite}"  # overwrite|skip

# Repo key -> absolute repo path on droplet
declare -A REPO_MAP=(
  ["backend"]="$REMOTE_BASE/thesisweb-backend"
  ["frontend"]="$REMOTE_BASE/thesis-web-com-site"
  ["protocol"]="$REMOTE_BASE/the-thesis-chain-protocol"
  ["architecture"]="$REMOTE_BASE/the-thesis-project-architecture"
  ["devkit"]="$REMOTE_BASE/the-thesis-chain-ai-devkit"
  ["sims"]="$REMOTE_BASE/the-thesis-chain-test"
  ["portfolio"]="$REMOTE_BASE/thesis-portfolio"
)

# ========= Helpers =========

log() { printf "%s\n" "$*"; }

# Extract "key path" from the first line if it contains a TARGET header.
extract_target() {
  local file="$1"
  local line
  line="$(head -n 1 "$file" | tr -d '\r')"

  # // TARGET: key path
  if [[ "$line" =~ ^[[:space:]]*//[[:space:]]*TARGET:\ (.+)$ ]]; then
    echo "${BASH_REMATCH[1]}"; return 0
  fi
  # # TARGET: key path
  if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*TARGET:\ (.+)$ ]]; then
    echo "${BASH_REMATCH[1]}"; return 0
  fi
  # <!-- TARGET: key path -->
  if [[ "$line" =~ ^[[:space:]]*\<\!\-\-[[:space:]]*TARGET:\ (.+)[[:space:]]*\-\-\> ]]; then
    echo "${BASH_REMATCH[1]}"; return 0
  fi

  return 1
}

# Create payload by stripping the first line (the header) and normalizing CRLF.
make_payload() {
  local src="$1"
  local dst="$2"
  # Strip first line, then remove any trailing \r
  tail -n +2 "$src" | sed 's/\r$//' > "$dst"
}

# ========= Main =========

log "🔍 Scanning: $WIN_DL"
log "➡️  Remote: $DROPLET_USER@$DROPLET_HOST"
log "⚙️ AFTER=$AFTER  ON_CONFLICT=$ON_CONFLICT"

shopt -s nullglob
for f in "$WIN_DL"/*; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f")"

  # Skip junk
  [[ "$name" == "desktop.ini" ]] && continue
  [[ "$name" == "_processed" ]] && continue

  # Skip obvious binaries/archives/media to avoid null-byte warnings
  case "$name" in
    *.exe|*.msi|*.zip|*.7z|*.rar|*.3mf|*.stl|*.png|*.jpg|*.jpeg|*.gif|*.mp4|*.mov|*.pdf)
      continue
      ;;
  esac

  # Extract routing header
  if ! target="$(extract_target "$f")"; then
    log "⏭️ No TARGET header: $name"
    continue
  fi

  # Parse: "key path..."
  repo_key="$(echo "$target" | awk '{print $1}')"
  path_in_repo="$(echo "$target" | cut -d' ' -f2- | sed 's/[[:space:]]*$//')"

  if [[ -z "${REPO_MAP[$repo_key]+x}" ]]; then
    log "❌ Unknown repo key '$repo_key' in $name"
    log "   Known keys: ${!REPO_MAP[*]}"
    exit 1
  fi

  remote_repo="${REPO_MAP[$repo_key]}"
  remote_dest="$remote_repo/$path_in_repo"
  remote_dir="$(dirname "$remote_dest")"

  log "📦 $name → $remote_dest"

  # Ensure remote directory exists
  ssh "$DROPLET_USER@$DROPLET_HOST" "mkdir -p '$remote_dir'"

  # Conflict behavior
  if [[ "$ON_CONFLICT" == "skip" ]]; then
    if ssh "$DROPLET_USER@$DROPLET_HOST" "[ -e '$remote_dest' ]"; then
      log "⏭️ Exists, skipping: $remote_dest"
      continue
    fi
  fi

  # Build payload with header stripped (supports JSON, etc.)
  tmp="$(mktemp)"
  make_payload "$f" "$tmp"

  # Upload payload
  scp "$tmp" "$DROPLET_USER@$DROPLET_HOST:$remote_dest"
  rm -f "$tmp"

  # Post-upload handling of original local file
  case "$AFTER" in
    move)
      mv -f "$f" "$PROCESSED_DIR/$name"
      ;;
    delete)
      rm -f "$f"
      ;;
    keep)
      : # no-op
      ;;
    *)
      log "❌ Invalid AFTER=$AFTER (use move|delete|keep)"
      exit 1
      ;;
  esac
done

log "🚀 Done."
