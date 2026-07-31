#!/usr/bin/env node

import {readFile} from 'node:fs/promises';
import path from 'node:path';

const sourceRoot = path.resolve(process.argv[2]);
const configPath = path.join(sourceRoot, 'remotion-worker.json');
const config = JSON.parse(await readFile(configPath, 'utf8'));
const allowed = new Set(['entryPoint', 'compositionId', 'outputName', 'installCommand', 'prepareCommand', 'checkCommand', 'crf']);

for (const key of Object.keys(config)) {
  if (!allowed.has(key)) throw new Error(`Unexpected private-source field: ${key}`);
}

const text = (value, field, fallback) => {
  const result = value ?? fallback;
  if (typeof result !== 'string' || result.trim() === '' || /[\r\n\0]/.test(result)) {
    throw new Error(`${field} must be a non-empty one-line string`);
  }
  return result;
};

const entryPoint = text(config.entryPoint, 'entryPoint');
const resolvedEntry = path.resolve(sourceRoot, entryPoint);
if (!resolvedEntry.startsWith(`${sourceRoot}${path.sep}`)) throw new Error('entryPoint escapes the private checkout');

const compositionId = text(config.compositionId, 'compositionId');
const outputName = text(config.outputName, 'outputName');
if (!/^[A-Za-z0-9_-]+$/.test(compositionId)) throw new Error('Invalid compositionId');
if (!/^[A-Za-z0-9_-]+$/.test(outputName)) throw new Error('Invalid outputName');

const crf = Number(config.crf ?? 20);
if (!Number.isInteger(crf) || crf < 1 || crf > 51) throw new Error('crf must be an integer from 1 through 51');

console.log(JSON.stringify({
  entryPoint,
  compositionId,
  outputName,
  installCommand: text(config.installCommand, 'installCommand', 'npm install --no-audit --no-fund'),
  prepareCommand: text(config.prepareCommand, 'prepareCommand', 'true'),
  checkCommand: text(config.checkCommand, 'checkCommand', 'npm run lint'),
  crf,
}));
