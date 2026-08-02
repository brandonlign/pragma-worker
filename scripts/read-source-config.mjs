#!/usr/bin/env node

import {readFile} from 'node:fs/promises';
import path from 'node:path';

const sourceRoot = path.resolve(process.argv[2]);
const configPath = path.join(sourceRoot, 'remotion-worker.json');
const config = JSON.parse(await readFile(configPath, 'utf8'));
const allowed = new Set([
  'entryPoint',
  'compositionId',
  'outputName',
  'installCommand',
  'prepareCommand',
  'checkCommand',
  'crf',
  'reuseFiles',
]);

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

const reuseFiles = (() => {
  const value = config.reuseFiles ?? [];
  if (!Array.isArray(value) || value.length > 8) {
    throw new Error('reuseFiles must be an array with at most 8 entries');
  }

  return value.map((item, index) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new Error(`reuseFiles[${index}] must be an object`);
    }
    const itemAllowed = new Set(['fromJobId', 'remoteName', 'destination']);
    for (const key of Object.keys(item)) {
      if (!itemAllowed.has(key)) {
        throw new Error(`Unexpected reuseFiles[${index}] field: ${key}`);
      }
    }

    const fromJobId = text(item.fromJobId, `reuseFiles[${index}].fromJobId`);
    if (!/^[a-z0-9][a-z0-9-]{5,63}$/.test(fromJobId)) {
      throw new Error(`Invalid reuseFiles[${index}].fromJobId`);
    }

    const safeRelative = (raw, field) => {
      const value = text(raw, field);
      if (
        value.startsWith('/') ||
        value.includes('\\') ||
        value.split('/').some((part) => part === '' || part === '.' || part === '..') ||
        !/^[A-Za-z0-9._/-]+$/.test(value)
      ) {
        throw new Error(`${field} must be a safe relative path`);
      }
      return value;
    };

    const remoteName = safeRelative(
      item.remoteName,
      `reuseFiles[${index}].remoteName`,
    );
    const destination = safeRelative(
      item.destination,
      `reuseFiles[${index}].destination`,
    );
    const resolvedDestination = path.resolve(sourceRoot, destination);
    if (!resolvedDestination.startsWith(`${sourceRoot}${path.sep}`)) {
      throw new Error(`reuseFiles[${index}].destination escapes the private checkout`);
    }

    return {fromJobId, remoteName, destination};
  });
})();

console.log(JSON.stringify({
  entryPoint,
  compositionId,
  outputName,
  installCommand: text(config.installCommand, 'installCommand', 'npm install --no-audit --no-fund'),
  prepareCommand: text(config.prepareCommand, 'prepareCommand', 'true'),
  checkCommand: text(config.checkCommand, 'checkCommand', 'npm run lint'),
  crf,
  reuseFiles,
}));
