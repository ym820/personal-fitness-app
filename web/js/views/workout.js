import { WorkoutFlow } from '../flow.js';

/** 新的进行中训练。id 在开始时就定下，结束时用它存记录，重复结束也只有一条 */
export function startSession(workout, restSeconds) {
  return {
    id: crypto.randomUUID(),
    flow: new WorkoutFlow(workout, restSeconds).toJSON(),
    startedAt: new Date().toISOString(),
    restEndsAt: null,
    draft: null,
  };
}
