import test from 'node:test';
import assert from 'node:assert/strict';
import { mergeWorkouts, sameWorkouts } from '../js/merge.js';

const w = (id, day, extra = {}) => ({
  id, date: new Date(day * 86_400_000).toISOString(), durationSeconds: 1200, templateId: 'A', sets: [], deleted: false, ...extra,
});

test('两边的记录都保留，按日期排序', () => {
  const merged = mergeWorkouts([w('b', 2)], [w('a', 1), w('c', 3)]);
  assert.deepEqual(merged.map(x => x.id), ['a', 'b', 'c']);
});

test('同一条记录只留一份', () => {
  assert.equal(mergeWorkouts([w('a', 1)], [w('a', 1)]).length, 1);
});

test('任何一边标了已删除，就算已删除', () => {
  assert.equal(mergeWorkouts([w('a', 1)], [w('a', 1, { deleted: true })])[0].deleted, true);
  assert.equal(mergeWorkouts([w('a', 1, { deleted: true })], [w('a', 1)])[0].deleted, true);
});

test('缺少 deleted 字段当作没删除', () => {
  const { deleted, ...noFlag } = w('a', 1);
  assert.equal(mergeWorkouts([noFlag])[0].deleted, false);
});

test('同步期间新增的记录不会丢', () => {
  const beforeSync = [w('a', 1)];
  const syncResult = mergeWorkouts(beforeSync, [w('remote', 2)]);
  const localNow = [...beforeSync, w('new', 3)];
  assert.deepEqual(mergeWorkouts(localNow, syncResult).map(x => x.id), ['a', 'remote', 'new']);
});

test('内容相同（顺序不同）算相同', () => {
  assert.equal(sameWorkouts([w('a', 1), w('b', 2)], [w('b', 2), w('a', 1)]), true);
  assert.equal(sameWorkouts([w('a', 1)], [w('a', 1), w('b', 2)]), false);
  assert.equal(sameWorkouts([w('a', 1)], [w('a', 1, { deleted: true })]), false);
});
