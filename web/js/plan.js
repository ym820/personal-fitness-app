import { isWeighted } from './catalog.js';

/** 和最后一次训练交替；没有记录从 A 开始。调用方先去掉已删除的记录 */
export function nextTemplateId(history) {
  let last = null;
  for (const w of history) if (!last || Date.parse(w.date) > Date.parse(last.date)) last = w;
  return last?.templateId === 'A' ? 'B' : 'A';
}

export function nextWorkout(catalog, history) {
  const templateId = nextTemplateId(history);
  const items = catalog.template(templateId)?.exercises ?? [];
  const newestFirst = [...history].sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
  const exercises = items.flatMap(item => {
    const exercise = catalog.exercise(item.exerciseId);
    return exercise ? [target(item, exercise, newestFirst)] : [];
  });
  return { templateId, exercises };
}

function target(item, exercise, newestFirst) {
  const make = (weightLb, suggestIncrease = false) => ({
    exerciseId: item.exerciseId,
    sets: item.sets,
    targetMin: item.targetMin,
    targetMax: item.targetMax,
    weightLb,
    suggestIncrease,
  });

  if (!isWeighted(exercise)) return make(0);

  const lastSets = newestFirst
    .map(w => w.sets.filter(s => s.exerciseId === item.exerciseId))
    .find(s => s.length > 0);
  if (!lastSets) return make(null);

  const lastWeight = Math.max(...lastSets.map(s => s.weightLb));
  const completedAll = lastSets.length >= item.sets && lastSets.every(s => s.value >= item.targetMax);
  return completedAll ? make(lastWeight + exercise.increment, true) : make(lastWeight);
}

/** 估算时长时每组按 45 秒算 */
const SECONDS_PER_SET = 45;

export const totalSets = workout => workout.exercises.reduce((n, e) => n + e.sets, 0);

export function estimatedDurationSeconds(workout, restSeconds) {
  const n = totalSets(workout);
  return n === 0 ? 0 : n * SECONDS_PER_SET + (n - 1) * restSeconds;
}
