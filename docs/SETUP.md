# Setup

## 1. Private source

The private repository is `brandonlign/pragma-video`. It already contains `remotion-worker.json` and the starter composition.

## 2. Source token

Create a fine-grained GitHub personal access token with:

- Repository access: only `brandonlign/pragma-video`
- Repository contents: read-only
- All unrelated permissions: no access

Add these Actions secrets to this repository:

- `SOURCE_REPOSITORY` = `brandonlign/pragma-video`
- `SOURCE_REPO_TOKEN` = the fine-grained token

## 3. Restricted Drive credential

Create a dedicated rclone configuration on a trusted computer:

```bash
rclone config --config "$HOME/.config/rclone/pragma-worker.conf"
```

Create a remote named `gdrive` using Google Drive and the exact OAuth scope `drive.file`. Do not use full-drive access and do not configure a Shared Drive.

Encode the config without printing it:

```bash
base64 -i "$HOME/.config/rclone/pragma-worker.conf" | tr -d '\n' | pbcopy
```

Add the clipboard value as `RCLONE_CONFIG_B64`.

### First successful upload

A `drive.file` credential cannot automatically access the browser-created `Pragma Production` folder. On its first successful upload, the worker creates `Pragma-Renders` at Drive root because that folder is owned by the restricted credential.

After that first upload:

1. Move the worker-created `Pragma-Renders` folder into the existing `Pragma Production` folder.
2. Copy the moved folder's ID from its Drive URL.
3. Add that ID as the repository secret `PRAGMA_RENDER_ROOT_ID`.

The worker then addresses the same restricted folder directly by ID on later runs.

## 4. Optional narration

For private preparation that calls ElevenLabs, add either:

- `ELEVENLABS_API_KEYS_JSON` containing a JSON array of authorized keys, or
- `ELEVENLABS_API_KEY` as a single-key fallback.

Do not place keys in source files, requests, issues, pull requests, or logs.

## 5. Render request

Create an internal branch named `render/<opaque-job-id>`, update only `jobs/request.json`, and open a pull request into `main`.

```json
{
  "jobId": "pragma-20260731-001",
  "sourceSha": "0123456789abcdef0123456789abcdef01234567",
  "revision": 1
}
```

The pull request should remain unmerged. Close it after the Drive result is verified.

## 6. Result package

Successful jobs contain:

- full-quality MP4
- `review.mp4`
- `contact-sheet.jpg`
- sampled keyframes
- `media-metadata.json`
- `status.json`
- `checksums.txt`
- `private-build.log`

Failed jobs upload status and private logs when Drive configuration is working.
