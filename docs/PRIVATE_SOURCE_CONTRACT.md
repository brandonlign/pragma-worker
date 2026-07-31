# Private source contract

The private source repository must contain `remotion-worker.json` at its root.

## Allowed fields

### `entryPoint`

Repository-relative Remotion entry file. It must remain inside the checkout.

### `compositionId`

Remotion composition identifier containing only letters, numbers, underscores, and hyphens.

### `outputName`

Filename stem for the full-quality MP4. It may contain only letters, numbers, underscores, and hyphens.

### `installCommand`

Trusted one-line command executed before preparation. The Pragma starter uses:

```text
npm install --no-audit --no-fund
```

### `prepareCommand`

Trusted one-line command executed after installation and before checks. Use it for private build-time preparation such as narration generation. It defaults to `true`.

### `checkCommand`

Trusted one-line validation command executed before rendering. The starter uses:

```text
npm run lint
```

### `crf`

H.264 CRF from 1 through 51. Lower values produce higher quality and larger files.

## Security model

Commands come only from an exact commit in the authorized private repository. They are never accepted from the public render request.
