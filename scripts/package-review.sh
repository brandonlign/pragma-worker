#!/usr/bin/env bash
set -euo pipefail

: "${FINAL_VIDEO:?FINAL_VIDEO is required}"
: "${RESULT_DIR:?RESULT_DIR is required}"
: "${JOB_ID:?JOB_ID is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"

mkdir -p "$RESULT_DIR/keyframes"

duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FINAL_VIDEO")"
if [ -z "$duration" ]; then
  echo "Unable to determine render duration." >&2
  exit 70
fi

ffmpeg -hide_banner -loglevel error -y -i "$FINAL_VIDEO" \
  -vf "scale=540:-2" -c:v libx264 -preset medium -crf 28 -an \
  "$RESULT_DIR/review.mp4"

mapfile -t timestamps < <(python3 - "$duration" <<'PY'
import sys

duration = float(sys.argv[1])
for ratio in (0.08, 0.28, 0.50, 0.72, 0.92):
    print(f"{max(0.0, duration * ratio):.3f}")
PY
)

for offset in "${!timestamps[@]}"; do
  index=$((offset + 1))
  ffmpeg -hide_banner -loglevel error -y \
    -ss "${timestamps[$offset]}" -i "$FINAL_VIDEO" \
    -frames:v 1 -q:v 2 "$RESULT_DIR/keyframes/frame-0${index}.jpg"
done

ffmpeg -hide_banner -loglevel error -y -i "$FINAL_VIDEO" \
  -vf "fps=5/${duration},scale=324:-2,tile=5x1:padding=12:margin=12:color=0x0b0d10" \
  -frames:v 1 "$RESULT_DIR/contact-sheet.jpg"

ffprobe -v error -show_format -show_streams -of json "$FINAL_VIDEO" > "$RESULT_DIR/media-metadata.json"

python3 - "$RESULT_DIR/status.json" "$JOB_ID" "$SOURCE_SHA" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, job_id, source_sha = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({
        "status": "success",
        "jobId": job_id,
        "sourceSha": source_sha,
        "completedAt": datetime.now(timezone.utc).isoformat(),
    }, handle, indent=2)
    handle.write("\n")
PY

(
  cd "$RESULT_DIR"
  find . -type f ! -name checksums.txt -print0 | sort -z | xargs -0 sha256sum > checksums.txt
)
