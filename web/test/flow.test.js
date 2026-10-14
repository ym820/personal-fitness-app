import test from 'node:test';
import assert from 'node:assert/strict';
import { WorkoutFlow } from '../js/flow.js';

const workout = {
  templateId: 'A',
  exercises: [
    { exerciseId: 'Leg_Press', sets: 3, targetMin: 8, targetMax: 12, weightLb: 100, suggestIncrease: false },
    { exerciseId: 'Leverage_Chest_Press', sets: 2, targetMin: 8, targetMax: 12, weightLb: null, suggestIncrease: false },
    { exerciseId: 'Plank', sets: 1, targetMin: 20, targetMax: 40, weightLb: 0, suggestIncrease: false },
  ],
};
const doing = (exerciseIndex, setIndex) => ({ type: 'doingSet', position: { exerciseIndex, setIndex } });
const resting = (exerciseIndex, setIndex) => ({ type: 'resting', position: { exerciseIndex, setIndex } });
const FINISHED = { type: 'finished' };

test('从第一个动作的第一组开始', () => {
  const flow = new WorkoutFlow(workout, 90);
  assert.deepEqual(flow.phase, doing(0, 0));
  assert.equal(flow.current.exerciseId, 'Leg_Press');
  assert.equal(flow.defaultValue(), 12);
  assert.equal(flow.defaultWeight(), 100);
  assert.equal(flow.totalSets, 6);
  assert.deepEqual(flow.completedSets, []);
});

test('没有动作直接结束', () => {
  const flow = new WorkoutFlow({ templateId: 'A', exercises: [] }, 90);
  assert.deepEqual(flow.phase, FINISHED);
  assert.equal(flow.current, null);
  assert.equal(flow.position, null);
});

test('完成一组进入休息，休息完做下一组', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(10, 100);
  assert.deepEqual(flow.phase, resting(0, 1));
  assert.equal(flow.current.exerciseId, 'Leg_Press');
  flow.finishRest();
  assert.deepEqual(flow.phase, doing(0, 1));
  assert.deepEqual(flow.completedSets, [{ exerciseId: 'Leg_Press', setIndex: 0, value: 10, weightLb: 100 }]);
});

test('完整走一遍', () => {
  const flow = new WorkoutFlow(workout, 90);
  let rests = 0;
  for (let guard = 0; flow.phase.type !== 'finished' && guard < 100; guard++) {
    if (flow.phase.type === 'doingSet') flow.completeSet(flow.defaultValue(), flow.defaultWeight() ?? 50);
    else { rests++; flow.finishRest(); }
  }
  assert.deepEqual(flow.phase, FINISHED);
  assert.equal(flow.completedSets.length, 6);
  assert.equal(rests, 5);
  assert.deepEqual(flow.completedSets.map(s => s.exerciseId), [
    'Leg_Press', 'Leg_Press', 'Leg_Press', 'Leverage_Chest_Press', 'Leverage_Chest_Press', 'Plank',
  ]);
  assert.deepEqual(flow.completedSets.map(s => s.setIndex), [0, 1, 2, 0, 1, 0]);
});

test('换动作前的休息指向下一个动作', () => {
  const flow = new WorkoutFlow(workout, 90);
  for (let i = 0; i < 3; i++) {
    flow.completeSet(12, 100);
    flow.finishRest();
  }
  assert.deepEqual(flow.phase, doing(1, 0));
  assert.equal(flow.current.exerciseId, 'Leverage_Chest_Press');
});

test('改过的重量带到同一个动作的下一组', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(12, 90);
  flow.finishRest();
  assert.equal(flow.defaultWeight(), 90);
});

test('第一次做的动作，填之前没有默认重量', () => {
  const flow = new WorkoutFlow(workout, 90);
  for (let i = 0; i < 3; i++) {
    flow.completeSet(12, 100);
    flow.finishRest();
  }
  assert.equal(flow.defaultWeight(), null);
  flow.completeSet(10, 40);
  flow.finishRest();
  assert.equal(flow.defaultWeight(), 40);
});

test('最后一组做完直接结束，不休息', () => {
  const single = { templateId: 'B', exercises: [{ exerciseId: 'Crunches', sets: 1, targetMin: 8, targetMax: 12, weightLb: 0, suggestIncrease: false }] };
  const flow = new WorkoutFlow(single, 90);
  flow.completeSet(12, 0);
  assert.deepEqual(flow.phase, FINISHED);
});

test('提前结束保留已完成的组', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(12, 100);
  flow.endEarly();
  assert.deepEqual(flow.phase, FINISHED);
  assert.equal(flow.completedSets.length, 1);
});

test('在不对的阶段调用会被忽略', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.finishRest();
  assert.deepEqual(flow.phase, doing(0, 0));
  flow.completeSet(12, 100);
  flow.completeSet(12, 100);
  assert.equal(flow.completedSets.length, 1);
  flow.endEarly();
  flow.completeSet(12, 100);
  assert.equal(flow.completedSets.length, 1);
});

test('存成 JSON 再读回来，能接着练', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(12, 90);
  const restored = WorkoutFlow.fromJSON(JSON.parse(JSON.stringify(flow)));
  assert.deepEqual(restored.phase, resting(0, 1));
  assert.deepEqual(restored.completedSets, flow.completedSets);
  assert.equal(restored.restSeconds, 90);
  restored.finishRest();
  assert.equal(restored.defaultWeight(), 90);
});

test('器械被占，换到后面的动作，做完再回来', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(12, 100);
  flow.finishRest();
  assert.deepEqual(flow.switchable(), [1, 2]);
  flow.switchTo(2);
  assert.deepEqual(flow.phase, doing(2, 0));
  assert.equal(flow.current.exerciseId, 'Plank');
  flow.completeSet(30, 0);
  // 平板支撑做完了，回到腿举的第 2 组
  assert.deepEqual(flow.phase, resting(0, 1));
  for (let guard = 0; flow.phase.type !== 'finished' && guard < 100; guard++) {
    if (flow.phase.type === 'doingSet') flow.completeSet(12, 50);
    else flow.finishRest();
  }
  assert.deepEqual(flow.completedSets.map(s => [s.exerciseId, s.setIndex]), [
    ['Leg_Press', 0], ['Plank', 0], ['Leg_Press', 1], ['Leg_Press', 2],
    ['Leverage_Chest_Press', 0], ['Leverage_Chest_Press', 1],
  ]);
});

test('跳过的动作在最后补上', () => {
  const flow = new WorkoutFlow(workout, 90);
  for (let i = 0; i < 3; i++) {
    flow.completeSet(12, 100);
    flow.finishRest();
  }
  flow.switchTo(2);
  flow.completeSet(30, 0);
  assert.deepEqual(flow.phase, resting(1, 0));
});

test('休息时也能换下一个动作', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(12, 100);
  flow.switchTo(1);
  assert.deepEqual(flow.phase, resting(1, 0));
  assert.equal(flow.defaultWeight(), null);
  flow.switchTo(0);
  assert.deepEqual(flow.phase, resting(0, 1));
  assert.equal(flow.defaultWeight(), 100);
});

test('不能换到当前动作、做完的动作或不存在的动作', () => {
  const flow = new WorkoutFlow(workout, 90);
  for (let i = 0; i < 3; i++) {
    flow.completeSet(12, 100);
    flow.finishRest();
  }
  for (const i of [0, 1, 7]) flow.switchTo(i);
  assert.deepEqual(flow.phase, doing(1, 0));
  assert.deepEqual(flow.switchable(), [2]);
  flow.endEarly();
  flow.switchTo(2);
  assert.deepEqual(flow.phase, FINISHED);
  assert.deepEqual(flow.switchable(), []);
});
