import { html } from '../dom.js';

export const art = name => html`<img class="art" src="img/${name}.svg" alt="">`;

/** 缩略图用结束姿势：多数动作的结束姿势最有辨识度（比如推起、拉到底） */
export const thumb = (exercise, size = '') => html`<span class="thumb ${size}">${art(exercise.images.at(-1))}</span>`;

export const templateName = (catalog, id) => catalog.template(id)?.nameZh ?? id;

/** 两位序号：01、02… */
export const index2 = i => String(i + 1).padStart(2, '0');

/** 一行数字统计：[[数值, 说明], …] */
export const stats = items => html`<div class="stats num">${items.map(([value, label]) => html`<div><b>${value}</b><span>${label}</span></div>`)}</div>`;
