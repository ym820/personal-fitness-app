/**
 * 按 id 合并训练记录：两边都保留；同一个 id 只要有一份标了已删除就算已删除；按日期排序。
 * 删除只做标记，否则下次同步会被另一边的旧记录带回来。
 */
export function mergeWorkouts(...lists) {
  const byId = new Map();
  for (const w of lists.flat()) {
    const prev = byId.get(w.id);
    byId.set(w.id, { ...(prev ?? w), deleted: Boolean(prev?.deleted || w.deleted) });
  }
  return [...byId.values()].sort(
    (a, b) => Date.parse(a.date) - Date.parse(b.date) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  );
}

export const sameWorkouts = (a, b) => JSON.stringify(mergeWorkouts(a)) === JSON.stringify(mergeWorkouts(b));
