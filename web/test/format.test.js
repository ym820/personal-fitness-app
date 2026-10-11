import test from 'node:test';
import assert from 'node:assert/strict';
import * as F from '../js/format.js';

test('数字：整数不带小数，其他保留一位', () => {
  assert.equal(F.number(10), '10');
  assert.equal(F.number(2.5), '2.5');
  assert.equal(F.weight(90), '90 lb');
});

test('次数和目标', () => {
  assert.equal(F.value(12, 'reps'), '12 次');
  assert.equal(F.value(30, 'seconds'), '30 秒');
  assert.equal(F.target(8, 12, 'reps'), '8-12 次');
});

test('时长', () => {
  assert.equal(F.duration(65), '1:05');
  assert.equal(F.duration(3725), '1:02:05');
  assert.equal(F.duration(0), '0:00');
});

test('估算时长取整到 5 分钟，最少 5 分钟', () => {
  assert.equal(F.approxMinutes(0), '约 5 分钟');
  assert.equal(F.approxMinutes(1700), '约 30 分钟');
});

test('肌肉名翻译，没有的原样返回', () => {
  assert.equal(F.muscleZh('lats'), '背阔肌');
  assert.equal(F.muscleZh('unknown'), 'unknown');
});

test('次数只接受非负整数', () => {
  assert.equal(F.parseCount('12'), 12);
  assert.equal(F.parseCount(' 8 '), 8);
  assert.equal(F.parseCount('0'), 0);
  assert.equal(F.parseCount(''), null);
  assert.equal(F.parseCount('abc'), null);
  assert.equal(F.parseCount('-1'), null);
  assert.equal(F.parseCount('12.5'), null);
});

test('重量接受非负数，可以有小数', () => {
  assert.equal(F.parseWeight('42.5'), 42.5);
  assert.equal(F.parseWeight(' 40 '), 40);
  assert.equal(F.parseWeight('0'), 0);
  assert.equal(F.parseWeight(''), null);
  assert.equal(F.parseWeight('   '), null);
  assert.equal(F.parseWeight('abc'), null);
  assert.equal(F.parseWeight('-5'), null);
});

test('按动作分组，保持训练时的顺序', () => {
  const sets = [
    { exerciseId: 'A', setIndex: 0, value: 10, weightLb: 50 },
    { exerciseId: 'B', setIndex: 0, value: 10, weightLb: 20 },
    { exerciseId: 'A', setIndex: 1, value: 9, weightLb: 50 },
  ];
  assert.deepEqual(F.groupSets(sets).map(g => [g.exerciseId, g.sets.length]), [['A', 2], ['B', 1]]);
});

test('每组的文字：自重动作不显示重量', () => {
  const set = { exerciseId: 'x', setIndex: 0, value: 12, weightLb: 90 };
  assert.equal(F.setText(set, { unit: 'reps', increment: 10 }), '12 次 × 90 lb');
  assert.equal(F.setText({ ...set, value: 30, weightLb: 0 }, { unit: 'seconds', increment: 0 }), '30 秒');
  assert.equal(F.setText(set, undefined), '12 次 × 90 lb');
});

test('重量不接受十六进制和科学计数法', () => {
  assert.equal(F.parseWeight('0x10'), null);
  assert.equal(F.parseWeight('1e3'), null);
  assert.equal(F.parseWeight('.5'), 0.5);
  assert.equal(F.parseWeight('40.'), 40);
});

test('输入框里的数字保留到两位小数，不丢 47.25 这样的重量', () => {
  assert.equal(F.inputNumber(47.25), '47.25');
  assert.equal(F.inputNumber(0.1 + 0.2), '0.3');
  assert.equal(F.inputNumber(10), '10');
});
