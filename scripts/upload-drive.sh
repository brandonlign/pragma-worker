#!/usr/bin/env bash
set -euo pipefail

: "${RESULT_DIR:?RESULT_DIR is required}"
: "${JOB_ID:?JOB_ID is required}"
: "${RCLONE_CONFIG_B64:?RCLONE_CONFIG_B64 is required}"

# This folder ID is only a locator, not a credential. It keeps future uploads
# pointed at the same worker-created Pragma-Renders folder even after that
# folder is moved under Pragma Production in Drive.
DEFAULT_PRAGMA_RENDER_ROOT_ID="13TgY0EdfH2R4RIuB39FzAX29pLTiPPrH"

CONFIG_FILE="$(mktemp)"
trap 'rm -f "$CONFIG_FILE"' EXIT
printf '%s' "$RCLONE_CONFIG_B64" | base64 --decode > "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

scope="$(awk -F '=' '
  /^\[gdrive\]/{inside=1; next}
  /^\[/{inside=0}
  inside && $1 ~ /^[[:space:]]*scope[[:space:]]*$/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit
  }
' "$CONFIG_FILE")"

case "$scope" in
  drive.file|https://www.googleapis.com/auth/drive.file) ;;
  *) echo "The gdrive remote must use the exact drive.file scope." >&2; exit 65 ;;
esac

set_root_folder() {
  python3 - "$CONFIG_FILE" "$1" <<'PY'
import configparser
import os
import sys

path, folder_id = sys.argv[1:]
config = configparser.RawConfigParser()
config.read(path)
if "gdrive" not in config:
    raise SystemExit("Missing [gdrive] remote")
config.set("gdrive", "root_folder_id", folder_id)
with open(path, "w", encoding="utf-8") as handle:
    config.write(handle, space_around_delimiters=True)
os.chmod(path, 0o600)
PY
}

render_root_id="${PRAGMA_RENDER_ROOT_ID:-$DEFAULT_PRAGMA_RENDER_ROOT_ID}"
set_root_folder "$render_root_id"

rclone mkdir "gdrive:$JOB_ID" --config "$CONFIG_FILE" --log-level ERROR
rclone copy "$RESULT_DIR" "gdrive:$JOB_ID" \
  --config "$CONFIG_FILE" --transfers 4 --checkers 8 --log-level ERROR
rclone check "$RESULT_DIR" "gdrive:$JOB_ID" \
  --config "$CONFIG_FILE" --one-way --log-level ERROR

echo "Private Drive upload verified for job $JOB_ID."
