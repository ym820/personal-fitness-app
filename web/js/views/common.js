import { html } from '../dom.js';

export const art = name => html`<img class="art" src="img/${name}.svg" alt="">`;

/** 缩略图用结束姿势：多数动作的结束姿势最有辨识度（比如推起、拉到底） */
export const thumb = (exercise, size = '') => html`<span class="thumb ${size}">${art(exercise.images.at(-1))}</span>`;

export const templateName = (catalog, id) => catalog.template(id)?.nameZh ?? id;

/** 两位序号：01、02… */
export const index2 = i => String(i + 1).padStart(2, '0');

/** 一行数字统计：[[数值, 说明], …] */
export const stats = items => html`<div class="stats num">${items.map(([value, label]) => html`<div><b>${value}</b><span>${label}</span></div>`)}</div>`;

/**
 * 代替系统的 confirm()：从底部弹出的确认框，和换动作的列表一个样式。
 * 点确认得到 true；点取消、点遮罩或按返回键得到 false
 */
export function confirmSheet({ title, message = '', confirmLabel, cancelLabel = '取消', danger = false }) {
  const sheet = document.createElement('dialog');
  sheet.className = 'sheet confirm';
  sheet.innerHTML = String(html`
    <h2>${title}</h2>
    ${message ? html`<p>${message}</p>` : ''}
    <div class="stack">
      <button class="button ${danger ? 'danger' : 'primary'}" data-answer="yes">${confirmLabel}</button>
      <button class="button" data-answer="no">${cancelLabel}</button>
    </div>`);
  document.body.append(sheet);
  sheet.showModal();
  return new Promise(resolve => {
    let answered = false;
    const answer = yes => {
      if (answered) return;
      answered = true;
      resolve(yes);
      // 先往下滑出再移除；不播动画（减弱动态效果）时靠定时器兜底
      sheet.dataset.closing = '';
      const remove = () => { sheet.close(); sheet.remove(); };
      sheet.addEventListener('animationend', remove, { once: true });
      setTimeout(remove, 300);
    };
    sheet.querySelector('[data-answer=yes]').addEventListener('click', () => answer(true));
    sheet.querySelector('[data-answer=no]').addEventListener('click', () => answer(false));
    sheet.addEventListener('click', event => { if (event.target === sheet) answer(false); });
    sheet.addEventListener('cancel', event => { event.preventDefault(); answer(false); });
  });
}
