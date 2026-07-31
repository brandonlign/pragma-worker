#!/usr/bin/env bash
set -euo pipefail

: "${RESULT_DIR:?RESULT_DIR is required}"
: "${JOB_ID:?JOB_ID is required}"
: "${RCLONE_CONFIG_B64:?RCLONE_CONFIG_B64 is required}"

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

resolve_root_id() {
  rclone lsjson gdrive: --config "$CONFIG_FILE" --dirs-only --max-depth 1 --log-level ERROR | \
    python3 -c '
import json, sys
name = "Pragma-Renders"
items = json.load(sys.stdin)
matches = [item for item in items if item.get("Name") == name and item.get("IsDir")]
if len(matches) != 1:
    print(f"Expected exactly one worker-created {name} folder; found {len(matches)}.", file=sys.stderr)
    raise SystemExit(65)
print(matches[0]["ID"])
'
}

if [ -n "${PRAGMA_RENDER_ROOT_ID:-}" ]; then
  set_root_folder "$PRAGMA_RENDER_ROOT_ID"
else
  rclone mkdir gdrive:Pragma-Renders --config "$CONFIG_FILE" --log-level ERROR
  root_id="$(resolve_root_id)"
  set_root_folder "$root_id"
fi

rclone mkdir "gdrive:$JOB_ID" --config "$CONFIG_FILE" --log-level ERROR
rclone copy "$RESULT_DIR" "gdrive:$JOB_ID" \
  --config "$CONFIG_FILE" --transfers 4 --checkers 8 --log-level ERROR
rclone check "$RESULT_DIR" "gdrive:$JOB_ID" \
  --config "$CONFIG_FILE" --one-way --log-level ERROR

echo "Private Drive upload verified for job $JOB_ID."
