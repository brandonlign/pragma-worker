#!/usr/bin/env bash
set -euo pipefail

: "${CONFIG_JSON:?CONFIG_JSON is required}"
: "${SOURCE_DIR:?SOURCE_DIR is required}"

reuse_count="$(node -e 'const c=JSON.parse(process.argv[1]); process.stdout.write(String(c.reuseFiles.length));' "$CONFIG_JSON")"
if [ "$reuse_count" = "0" ]; then
  exit 0
fi

: "${RCLONE_CONFIG_B64:?RCLONE_CONFIG_B64 is required when reusable files are configured}"

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

render_root_id="${PRAGMA_RENDER_ROOT_ID:-$DEFAULT_PRAGMA_RENDER_ROOT_ID}"
python3 - "$CONFIG_FILE" "$render_root_id" <<'PY'
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

while IFS=$'\t' read -r from_job remote_name destination; do
  target="$SOURCE_DIR/$destination"
  mkdir -p "$(dirname "$target")"
  if ! rclone copyto "gdrive:$from_job/$remote_name" "$target" \
    --config "$CONFIG_FILE" --log-level ERROR >/dev/null 2>&1; then
    echo "Private reusable media fetch failed." >&2
    exit 74
  fi
done < <(
  node -e '
    const config = JSON.parse(process.argv[1]);
    for (const item of config.reuseFiles) {
      process.stdout.write(`${item.fromJobId}\t${item.remoteName}\t${item.destination}\n`);
    }
  ' "$CONFIG_JSON"
)

echo "Private reusable media restored."
