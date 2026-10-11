import { isWeighted } from './catalog.js';

export const number = v => (Math.round(v) === v ? String(v) : v.toFixed(1));
export const weight = lb => `${number(lb)} lb`;
export const unitZh = unit => (unit === 'seconds' ? '秒' : '次');
export const value = (v, unit) => `${v} ${unitZh(unit)}`;
export const target = (min, max, unit) => `${min}-${max} ${unitZh(unit)}`;

/** 秒数 → "1:05" 或 "1:02:05" */
export function duration(seconds) {
  const total = Math.round(seconds);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = n => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

/** 估算时长，取整到 5 分钟 */
export const approxMinutes = seconds => `约 ${Math.max(5, Math.round(seconds / 60 / 5) * 5)} 分钟`;

const MUSCLES = {
  abdominals: '腹肌', biceps: '肱二头肌', calves: '小腿', chest: '胸肌', forearms: '前臂',
  glutes: '臀肌', hamstrings: '大腿后侧', lats: '背阔肌', 'lower back': '下背', 'middle back': '中背',
  quadriceps: '大腿前侧', shoulders: '肩部', traps: '斜方肌', triceps: '肱三头肌',
};
export const muscleZh = m => MUSCLES[m] ?? m;

const formatter = options => new Intl.DateTimeFormat('zh-CN', options);
const SHORT = formatter({ month: 'numeric', day: 'numeric', weekday: 'short' });
const DATE_TIME = formatter({ month: 'numeric', day: 'numeric', weekday: 'short', hour: '2-digit', minute: '2-digit' });
const LONG = formatter({ year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' });
export const dateShort = iso => SHORT.format(new Date(iso));
export const dateTime = iso => DATE_TIME.format(new Date(iso));
export const dateLong = iso => LONG.format(new Date(iso));

/** 输入框里的次数：非负整数，否则 null */
export function parseCount(text) {
  const t = String(text).trim();
  return /^\d+$/.test(t) ? Number(t) : null;
}

/** 输入框里的重量：非负数，可以有小数，否则 null */
export function parseWeight(text) {
  const t = String(text).trim();
  const n = Number(t);
  return t !== '' && Number.isFinite(n) && n >= 0 ? n : null;
}

/** 按动作分组，保持训练时的顺序 */
export function groupSets(sets) {
  const groups = [];
  for (const set of sets) {
    const group = groups.find(g => g.exerciseId === set.exerciseId);
    if (group) group.sets.push(set);
    else groups.push({ exerciseId: set.exerciseId, sets: [set] });
  }
  return groups;
}

/** "12 次 × 90 lb"，自重动作只显示次数。找不到动作时按负重、按次数显示 */
export function setText(set, exercise) {
  const text = value(set.value, exercise?.unit ?? 'reps');
  return exercise && !isWeighted(exercise) ? text : `${text} × ${weight(set.weightLb)}`;
}
