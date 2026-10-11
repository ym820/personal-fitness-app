import { html } from '../dom.js';

export const art = name => html`<img class="art" src="img/${name}.svg" alt="">`;

/** 缩略图用结束姿势：多数动作的结束姿势最有辨识度（比如推起、拉到底） */
export const thumb = exercise => html`<span class="thumb">${art(exercise.images.at(-1))}</span>`;

export const tag = (text, color) => html`<span class="tag ${color}">${text}</span>`;

export const templateName = (catalog, id) => catalog.template(id)?.nameZh ?? id;
