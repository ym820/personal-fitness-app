import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const build = () => execFileSync('scripts/build_web.sh', { cwd: root });
const cacheName = () => readFileSync(new URL('_site/sw.js', root), 'utf8').match(/const CACHE = '([^']+)'/)[1];

test('组装后 sw.js 的缓存名带内容版本号，内容不变版本号也不变', () => {
  build();
  const first = cacheName();
  assert.match(first, /^fitness-[0-9]+$/);
  build();
  assert.equal(cacheName(), first);
});
