import test from 'node:test';
import assert from 'node:assert/strict';
import { navKind } from '../js/nav.js';

test('从列表点进详情是 forward，返回是 back', () => {
  assert.equal(navKind('#/library', '#/exercise/Leg_Press'), 'forward');
  assert.equal(navKind('#/exercise/Leg_Press', '#/library'), 'back');
  assert.equal(navKind('#/history', '#/history/abc'), 'forward');
  assert.equal(navKind('#/history/abc', '#/history'), 'back');
  assert.equal(navKind('#/today', '#/workout'), 'forward');
});

test('切标签、训练到完成是 fade', () => {
  assert.equal(navKind('#/today', '#/library'), 'fade');
  assert.equal(navKind('#/library', '#/history'), 'fade');
  assert.equal(navKind('#/workout', '#/done/abc'), 'fade');
});

test('同一页、空网址当作今天', () => {
  assert.equal(navKind('#/today', '#/today'), 'none');
  assert.equal(navKind('', '#/today'), 'none');
  assert.equal(navKind('', '#/exercise/Plank'), 'forward');
});
