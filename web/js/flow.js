import { totalSets } from './plan.js';

/**
 * 一次训练的流程：做组 → 休息 → 下一组 → 下一个动作 → 结束。
 * 器械被占时可以先换到别的动作，跳过的动作等其他的做完再回来。
 * 页面只负责显示 phase 和调用这里的方法。可以存成 JSON，练到一半关掉也能接着练。
 */
export class WorkoutFlow {
  constructor(workout, restSeconds, saved = null) {
    this.workout = workout;
    this.restSeconds = restSeconds;
    this.phase = saved?.phase ?? firstPhase(workout);
    this.completedSets = saved?.completedSets ?? [];
    /** 本次训练里每个动作最后一次实际用的重量 */
    this.usedWeights = saved?.usedWeights ?? {};
  }

  static fromJSON(saved) {
    return new WorkoutFlow(saved.workout, saved.restSeconds, saved);
  }

  toJSON() {
    return {
      workout: this.workout,
      restSeconds: this.restSeconds,
      phase: this.phase,
      completedSets: this.completedSets,
      usedWeights: this.usedWeights,
    };
  }

  get totalSets() {
    return totalSets(this.workout);
  }

  /** 正在做的组，或休息完要做的组 */
  get position() {
    return this.phase.type === 'finished' ? null : this.phase.position;
  }

  get current() {
    const p = this.position;
    return p ? this.workout.exercises[p.exerciseIndex] : null;
  }

  /** 预填的次数（或秒数） */
  defaultValue() {
    return this.current?.targetMax ?? 0;
  }

  /** 预填的重量：本次训练里这个动作上一组的重量，没有就用目标重量。null 表示要用户填 */
  defaultWeight() {
    const c = this.current;
    if (!c) return null;
    return this.usedWeights[c.exerciseId] ?? c.weightLb;
  }

  /** 这个动作已经做了几组 */
  doneSets(exerciseIndex) {
    const id = this.workout.exercises[exerciseIndex].exerciseId;
    return this.completedSets.filter(s => s.exerciseId === id).length;
  }

  /** 除了当前动作以外还没做完的动作，可以换过去 */
  switchable() {
    const p = this.position;
    if (!p) return [];
    return this.workout.exercises.flatMap((e, i) =>
      i !== p.exerciseIndex && this.doneSets(i) < e.sets ? [i] : []);
  }

  /** 换到另一个没做完的动作，从它下一组接着做。休息中换就换掉休息完要做的动作 */
  switchTo(exerciseIndex) {
    if (!this.switchable().includes(exerciseIndex)) return;
    this.phase = { ...this.phase, position: { exerciseIndex, setIndex: this.doneSets(exerciseIndex) } };
  }

  completeSet(value, weightLb) {
    if (this.phase.type !== 'doingSet') return;
    const { position } = this.phase;
    const c = this.current;
    this.completedSets.push({ exerciseId: c.exerciseId, setIndex: position.setIndex, value, weightLb });
    this.usedWeights[c.exerciseId] = weightLb;
    const next = this.#nextPosition(position);
    this.phase = next ? { type: 'resting', position: next } : { type: 'finished' };
  }

  /** 休息倒计时结束或跳过休息 */
  finishRest() {
    if (this.phase.type === 'resting') this.phase = { type: 'doingSet', position: this.phase.position };
  }

  endEarly() {
    this.phase = { type: 'finished' };
  }

  /** 当前动作没做完就接着做；做完了找后面没做完的，后面都做完了再回头找跳过的 */
  #nextPosition({ exerciseIndex }) {
    const { exercises } = this.workout;
    const order = [...exercises.keys()].map(k => (exerciseIndex + k) % exercises.length);
    const next = order.find(i => this.doneSets(i) < exercises[i].sets);
    return next === undefined ? null : { exerciseIndex: next, setIndex: this.doneSets(next) };
  }
}

function firstPhase(workout) {
  const i = workout.exercises.findIndex(e => e.sets > 0);
  return i >= 0 ? { type: 'doingSet', position: { exerciseIndex: i, setIndex: 0 } } : { type: 'finished' };
}
