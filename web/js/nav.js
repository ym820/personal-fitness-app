/** 每个页面在第几层：标签页是 0，从标签页点进去的是 1 */
const DEPTH = { today: 0, library: 0, history: 0, exercise: 1, settings: 1, workout: 1, done: 1 };

const section = hash => (hash || '#/today').split('/')[1] ?? '';

/** 历史记录详情（#/history/id）比历史列表深一层 */
function depth(hash) {
  const parts = (hash || '#/today').split('/');
  if (parts[1] === 'history' && parts.length > 2) return 1;
  return DEPTH[parts[1]] ?? 0;
}

/**
 * 页面切换用哪种动画：
 * forward 点进更深的页面，新页从右边滑入；back 返回，当前页往右滑出；
 * fade 同一层之间（切标签、训练 → 完成）淡入淡出；none 同一页刷新不动画
 */
export function navKind(from, to) {
  if (from === to) return 'none';
  const a = depth(from);
  const b = depth(to);
  if (b > a) return 'forward';
  if (b < a) return 'back';
  return section(from) === section(to) && a === 0 ? 'none' : 'fade';
}
