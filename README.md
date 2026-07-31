# Pragma Worker

A public GitHub Actions worker that renders an exact commit from the private Pragma Remotion repository and uploads the result to private Google Drive storage.

The public repository contains only rendering, validation, review packaging, and upload infrastructure. It does not store private scripts, prompts, assets, voiceovers, source code, or rendered videos.

## Flow

1. An internal `render/<job-id>` pull request changes only `jobs/request.json`.
2. The worker validates the opaque job ID and exact private-source commit SHA.
3. It checks out the authorized private repository with a repository-scoped read-only token.
4. It installs dependencies, runs the private preparation and check commands, and renders the configured Remotion composition.
5. It creates a review MP4, keyframes, a contact sheet, media metadata, checksums, status, and a private build log.
6. It uploads the package through a least-privilege Google Drive credential.

## Required secrets

- `SOURCE_REPOSITORY`
- `SOURCE_REPO_TOKEN`
- `RCLONE_CONFIG_B64`

Optional narration secrets:

- `ELEVENLABS_API_KEYS_JSON`
- `ELEVENLABS_API_KEY`

The restricted Drive credential created `Pragma-Renders` at Drive root during initial setup. Move that folder once into `Pragma Production`; its Drive ID stays unchanged, and the worker is pinned to that same folder ID for all future uploads. `PRAGMA_RENDER_ROOT_ID` remains supported as an optional override.

See `docs/SETUP.md` and `SECURITY.md`.
