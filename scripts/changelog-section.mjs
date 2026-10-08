#!/usr/bin/env node

import { readFileSync } from 'node:fs';

const version = (process.argv[2] ?? '').replace(/^v/, '');
const path = process.argv[3] ?? 'CHANGELOG.md';

if (!version) {
  console.error('usage: changelog-section.mjs <version> [changelog path]');
  process.exit(2);
}

const lines = readFileSync(path, 'utf8').split(/\r?\n/);
const heading =
  /^##\s+\[?v?([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)\]?/;

let start = -1;
let end = lines.length;

for (let i = 0; i < lines.length; i++) {
  const match = heading.exec(lines[i]);
  if (!match) continue;

  if (start === -1) {
    if (match[1] === version) start = i + 1;
  } else {
    end = i;
    break;
  }
}

if (start === -1) {
  console.error(`No "## [${version}]" section in ${path}.`);
  process.exit(1);
}

const body = lines
  .slice(start, end)
  .filter((line) => !/^\[[^\]]+\]:\s+https?:\/\//.test(line))
  .join('\n')
  .trim();

if (!body) {
  console.error(`The "${version}" section in ${path} is empty.`);
  process.exit(1);
}

process.stdout.write(`${body}\n`);
