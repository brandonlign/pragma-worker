# Security

## Public/private boundary

This repository must never contain private production material. Render requests expose only an opaque job ID, an exact source commit SHA, and a positive revision number.

## Trigger boundary

The workflow runs only when all of these conditions hold:

- the pull request comes from this repository, not a fork;
- the branch name begins with `render/`;
- the pull request changes only `jobs/request.json`;
- the request schema validates.

Keep write access to this repository restricted. Anyone with write access can create an internal render branch and cause the workflow to use configured secrets.

## Source access

Use a fine-grained token that can read only `brandonlign/pragma-video`. Grant repository contents read-only and no unrelated account permissions.

## Drive access

Use an rclone Google Drive remote with the exact `drive.file` scope. The upload script refuses broader scopes. The worker can access only files and folders created or explicitly authorized for that credential.

## Logs and artifacts

The workflow publishes no GitHub Actions artifact containing the private build. Detailed build output is redirected into `private-build.log` and uploaded only to the private Drive destination. GitHub logs contain only high-level status.

## Secrets

Never commit credentials, paste them into pull requests or issues, include them in render requests, or print them from private preparation scripts.
