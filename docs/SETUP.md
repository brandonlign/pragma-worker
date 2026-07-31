# Setup

## 1. Private source

The private repository is `brandonlign/pragma-video`. It contains `remotion-worker.json` and the starter composition.

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

### Render destination

On its first successful upload, the restricted credential creates `Pragma-Renders` at Drive root. Future jobs automatically reuse that folder, so no folder move or additional secret is required.

`PRAGMA_RENDER_ROOT_ID` remains supported as an optional advanced override when the target folder is already accessible to the same restricted credential.

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
