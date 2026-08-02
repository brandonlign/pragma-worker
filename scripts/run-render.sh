#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${RESULT_DIR:?RESULT_DIR is required}"
: "${JOB_ID:?JOB_ID is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"

WORKER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
mkdir -p "$RESULT_DIR"
RESULT_DIR="$(cd "$RESULT_DIR" && pwd)"

CONFIG_JSON="$(node "$WORKER_ROOT/scripts/read-source-config.mjs" "$SOURCE_DIR")"
json_field() {
  node -e 'const value=JSON.parse(process.argv[1]); process.stdout.write(String(value[process.argv[2]]));' "$CONFIG_JSON" "$1"
}

ENTRY_POINT="$(json_field entryPoint)"
COMPOSITION_ID="$(json_field compositionId)"
OUTPUT_NAME="$(json_field outputName)"
INSTALL_COMMAND="$(json_field installCommand)"
PREPARE_COMMAND="$(json_field prepareCommand)"
CHECK_COMMAND="$(json_field checkCommand)"
CRF="$(json_field crf)"
FINAL_VIDEO="$RESULT_DIR/${OUTPUT_NAME}.mp4"

CONFIG_JSON="$CONFIG_JSON" SOURCE_DIR="$SOURCE_DIR" \
  bash "$WORKER_ROOT/scripts/reuse-drive-files.sh"

cd "$SOURCE_DIR"
set +x
bash -o pipefail -c "$INSTALL_COMMAND"
bash -o pipefail -c "$PREPARE_COMMAND"
bash -o pipefail -c "$CHECK_COMMAND"

REMOTION_BIN="$SOURCE_DIR/node_modules/.bin/remotion"
if [ ! -x "$REMOTION_BIN" ]; then
  echo "Remotion CLI was not installed at the expected path." >&2
  exit 69
fi

"$REMOTION_BIN" render "$ENTRY_POINT" "$COMPOSITION_ID" "$FINAL_VIDEO" \
  --codec=h264 --crf="$CRF" --pixel-format=yuv420p --log=error

FINAL_VIDEO="$FINAL_VIDEO" RESULT_DIR="$RESULT_DIR" JOB_ID="$JOB_ID" SOURCE_SHA="$SOURCE_SHA" \
  "$WORKER_ROOT/scripts/package-review.sh"
