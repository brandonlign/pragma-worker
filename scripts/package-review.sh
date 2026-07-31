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

python3 - "$duration" "$RESULT_DIR" <<'PY'
import subprocess
import sys
from pathlib import Path

duration = float(sys.argv[1])
result = Path(sys.argv[2])
for index, ratio in enumerate((0.08, 0.28, 0.50, 0.72, 0.92), start=1):
    timestamp = max(0.0, duration * ratio)
    target = result / "keyframes" / f"frame-{index:02d}.jpg"
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-ss", f"{timestamp:.3f}", "-i", str(result / Path(sys.argv[2]).name),
    ], check=False)
PY

for index in 1 2 3 4 5; do
  ratio="$(python3 - "$index" <<'PY'
import sys
print((0.08, 0.28, 0.50, 0.72, 0.92)[int(sys.argv[1]) - 1])
PY
)"
  timestamp="$(python3 - "$duration" "$ratio" <<'PY'
import sys
print(max(0.0, float(sys.argv[1]) * float(sys.argv[2])))
PY
)"
  ffmpeg -hide_banner -loglevel error -y -ss "$timestamp" -i "$FINAL_VIDEO" -frames:v 1 -q:v 2 "$RESULT_DIR/keyframes/frame-0${index}.jpg"
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
