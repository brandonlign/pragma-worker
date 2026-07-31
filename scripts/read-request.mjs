#!/usr/bin/env node

import {appendFile, readFile} from 'node:fs/promises';

const path = process.argv[2] ?? 'jobs/request.json';
const request = JSON.parse(await readFile(path, 'utf8'));
const allowed = new Set(['jobId', 'sourceSha', 'revision']);

for (const key of Object.keys(request)) {
  if (!allowed.has(key)) throw new Error(`Unexpected request field: ${key}`);
}

if (!/^[a-z0-9][a-z0-9-]{5,63}$/.test(request.jobId ?? '')) {
  throw new Error('jobId must be 6-64 lowercase letters, numbers, or hyphens');
}
if (!/^[0-9a-f]{40}$/.test(request.sourceSha ?? '')) {
  throw new Error('sourceSha must be a complete lowercase 40-character SHA');
}
if (!Number.isInteger(request.revision) || request.revision < 1) {
  throw new Error('revision must be a positive integer');
}

if (!process.env.GITHUB_OUTPUT) throw new Error('GITHUB_OUTPUT is unavailable');
await appendFile(process.env.GITHUB_OUTPUT, `job_id=${request.jobId}\nsource_sha=${request.sourceSha}\nrevision=${request.revision}\n`);
console.log(`Validated render request ${request.jobId} revision ${request.revision}.`);
