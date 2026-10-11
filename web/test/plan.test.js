import test from 'node:test';
import assert from 'node:assert/strict';
import { catalog } from './fixtures.js';
import { estimatedDurationSeconds, nextTemplateId, nextWorkout, totalSets } from '../js/plan.js';

const day = n => new Date(n * 86_400_000).toISOString();
const workout = (templateId, n, sets = []) => ({ id: `w${n}`, date: day(n), durationSeconds: 0, templateId, sets, deleted: false });
const sets = (exerciseId, values, weightLb) => values.map((value, setIndex) => ({ exerciseId, setIndex, value, weightLb }));
const target = (next, id) => {
  const t = next.exercises.find(e => e.exerciseId === id);
  assert.ok(t, `${id} 不在这次计划里`);
  return t;
};

test('没有记录从 A 开始', () => {
  assert.equal(nextTemplateId([]), 'A');
});

test('和最后一次训练交替', () => {
  assert.equal(nextTemplateId([workout('A', 1)]), 'B');
  assert.equal(nextTemplateId([workout('A', 1), workout('B', 3)]), 'A');
});

test('按日期找最后一次，不按数组顺序', () => {
  assert.equal(nextTemplateId([workout('B', 5), workout('A', 1), workout('B', 3)]), 'A');
});

test('第一次：负重动作没有重量，自重动作为 0，不提示加重', () => {
  const next = nextWorkout(catalog, []);
  assert.equal(next.templateId, 'A');
  assert.deepEqual(next.exercises.map(e => e.exerciseId), catalog.template('A').exercises.map(e => e.exerciseId));
  assert.equal(target(next, 'Leg_Press').weightLb, null);
  assert.equal(target(next, 'Plank').weightLb, 0);
  assert.ok(next.exercises.every(e => !e.suggestIncrease));
});

test('照抄计划里的组数和目标', () => {
  const next = nextWorkout(catalog, []);
  const legPress = target(next, 'Leg_Press');
  assert.equal(legPress.sets, 3);
  assert.equal(legPress.targetMin, 8);
  assert.equal(legPress.targetMax, 12);
  const plank = target(next, 'Plank');
  assert.equal(plank.targetMin, 20);
  assert.equal(plank.targetMax, 40);
});

test('所有组做满，器械加 10 lb', () => {
  const history = [workout('A', 1, sets('Leg_Press', [12, 12, 12], 100)), workout('B', 3)];
  const legPress = target(nextWorkout(catalog, history), 'Leg_Press');
  assert.equal(legPress.weightLb, 110);
  assert.equal(legPress.suggestIncrease, true);
});

test('差一次没做满，重量不变', () => {
  const history = [workout('A', 1, sets('Leg_Press', [12, 12, 11], 100)), workout('B', 3)];
  const legPress = target(nextWorkout(catalog, history), 'Leg_Press');
  assert.equal(legPress.weightLb, 100);
  assert.equal(legPress.suggestIncrease, false);
});

test('提前结束（组数不够）不加重', () => {
  const history = [workout('A', 1, sets('Leg_Press', [12, 12], 100)), workout('B', 3)];
  const legPress = target(nextWorkout(catalog, history), 'Leg_Press');
  assert.equal(legPress.weightLb, 100);
  assert.equal(legPress.suggestIncrease, false);
});

test('哑铃加 5 lb', () => {
  const history = [workout('B', 1, sets('Dumbbell_Bench_Press', [12, 12, 12], 20)), workout('A', 2)];
  const bench = target(nextWorkout(catalog, history), 'Dumbbell_Bench_Press');
  assert.equal(bench.weightLb, 25);
  assert.equal(bench.suggestIncrease, true);
});

test('自重动作不提示加重', () => {
  const history = [workout('A', 1, sets('Plank', [40, 40, 40], 0)), workout('B', 3)];
  const plank = target(nextWorkout(catalog, history), 'Plank');
  assert.equal(plank.weightLb, 0);
  assert.equal(plank.suggestIncrease, false);
});

test('用最近一次训练里最重的一组', () => {
  const history = [
    workout('A', 1, sets('Leg_Press', [12, 12, 12], 200)),
    workout('A', 5, [
      { exerciseId: 'Leg_Press', setIndex: 0, value: 10, weightLb: 90 },
      { exerciseId: 'Leg_Press', setIndex: 1, value: 9, weightLb: 100 },
      { exerciseId: 'Leg_Press', setIndex: 2, value: 8, weightLb: 100 },
    ]),
    workout('B', 7),
  ];
  const legPress = target(nextWorkout(catalog, history), 'Leg_Press');
  assert.equal(legPress.weightLb, 100);
  assert.equal(legPress.suggestIncrease, false);
});

test('其他动作不受影响', () => {
  const history = [workout('A', 1, sets('Leg_Press', [12, 12, 12], 100)), workout('B', 3)];
  const next = nextWorkout(catalog, history);
  assert.equal(next.templateId, 'A');
  assert.equal(target(next, 'Leverage_Chest_Press').weightLb, null);
});

test('总组数和估算时长（每组 45 秒 + 组间休息）', () => {
  const next = nextWorkout(catalog, []);
  assert.equal(totalSets(next), 15);
  assert.equal(estimatedDurationSeconds(next, 90), 15 * 45 + 14 * 90);
  assert.equal(estimatedDurationSeconds({ templateId: 'A', exercises: [] }, 90), 0);
});
