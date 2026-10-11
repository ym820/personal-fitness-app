/** 动作库按这个顺序分组 */
export const BODY_PARTS = [
  ['legs', '腿和臀'], ['chest', '胸'], ['back', '背'], ['shoulders', '肩'], ['arms', '手臂'], ['core', '核心'],
];

/** 加重步长大于 0 的是负重动作，自重动作为 0 */
export const isWeighted = exercise => exercise.increment > 0;

export function makeCatalog({ exercises, plan, videos = {} }) {
  const byId = new Map(exercises.map(e => [e.id, e]));
  return {
    exercises,
    plan,
    exercise: id => byId.get(id),
    template: id => plan.templates.find(t => t.id === id),
    videosFor: id => videos[id] ?? [],
  };
}

export async function loadCatalog(base = 'data/') {
  const get = async name => {
    const response = await fetch(`${base}${name}.json`);
    if (!response.ok) throw new Error(`读取 ${name}.json 失败（${response.status}）`);
    return response.json();
  };
  const [exercises, plan, videos] = await Promise.all(['exercises', 'plan', 'videos'].map(get));
  return makeCatalog({ exercises, plan, videos });
}

export function filterExercises(exercises, query) {
  const q = query.trim().toLowerCase();
  if (!q) return exercises;
  return exercises.filter(e => [e.nameZh, e.nameEn, e.equipmentZh, e.equipmentEn].some(s => s.toLowerCase().includes(q)));
}

export const watchURL = v =>
  v.platform === 'youtube' ? `https://www.youtube.com/watch?v=${v.id}` : `https://www.bilibili.com/video/${v.id}`;

export const thumbnailURL = v =>
  v.thumbnail ?? (v.platform === 'youtube' ? `https://i.ytimg.com/vi/${v.id}/hqdefault.jpg` : null);
