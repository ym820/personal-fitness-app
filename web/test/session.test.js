import test from 'node:test';
import assert from 'node:assert/strict';
import { elapsedSeconds, isPaused, pauseSession, resumeSession } from '../js/session.js';

const start = Date.parse('2026-10-15T10:00:00Z');
const session = { startedAt: new Date(start).toISOString(), restEndsAt: null };

test('没暂停过时已练时长就是开始到现在', () => {
  assert.equal(elapsedSeconds(session, start + 90_000), 90);
});

test('暂停期间已练时长不走', () => {
  const paused = pauseSession(session, start + 60_000);
  assert.ok(isPaused(paused));
  assert.equal(elapsedSeconds(paused, start + 60_000), 60);
  assert.equal(elapsedSeconds(paused, start + 600_000), 60);
});

test('继续后不算暂停的时间，多次暂停累加', () => {
  let s = pauseSession(session, start + 60_000);
  s = resumeSession(s, start + 360_000);
  assert.ok(!isPaused(s));
  assert.equal(elapsedSeconds(s, start + 420_000), 120);
  s = resumeSession(pauseSession(s, start + 420_000), start + 480_000);
  assert.equal(elapsedSeconds(s, start + 480_000), 120);
});

test('休息中暂停，继续后倒计时剩下的时间不变', () => {
  const resting = { ...session, restEndsAt: start + 90_000 };
  const s = resumeSession(pauseSession(resting, start + 30_000), start + 330_000);
  assert.equal(s.restEndsAt - (start + 330_000), 60_000);
});

test('重复暂停或没暂停时继续不改东西', () => {
  const paused = pauseSession(session, start + 10_000);
  assert.equal(pauseSession(paused, start + 20_000), paused);
  assert.equal(resumeSession(session, start + 20_000), session);
});
