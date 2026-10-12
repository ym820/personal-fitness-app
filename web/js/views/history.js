import { html } from '../dom.js';
import * as F from '../format.js';
import { stats, templateName } from './common.js';

export function historyView(app) {
  const { catalog, store } = app;
  const list = store.visibleWorkouts().sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
  return {
    html: html`
      <header class="page-header">
        <h1 class="large-title">记录</h1>
        <a href="#/settings">设置</a>
      </header>
      ${list.length
        ? html`<ul class="list">${list.map(w => html`<li><a class="row" href="#/history/${w.id}">
            ${dayBadge(w.date)}
            <div class="row-text">
              <strong>${templateName(catalog, w.templateId)}</strong>
              <span>${F.dateTime(w.date)}</span>
            </div>
            <div class="row-end num"><b>${w.sets.length}<small>组</small></b><span>${F.duration(w.durationSeconds)}</span></div>
          </a></li>`)}</ul>`
        : html`<div class="empty"><strong>还没有训练记录</strong><p>完成一次训练后会出现在这里</p></div>`}`,
  };
}

export function workoutDetailView(app, id) {
  const { catalog, store } = app;
  const workout = store.visibleWorkouts().find(w => w.id === id);
  if (!workout) return { html: html`<p class="empty">找不到这次训练</p>` };

  return {
    html: html`
      <nav class="navbar"><a class="back" href="#/history">‹ 记录</a></nav>
      <p class="eyebrow">${F.dateLong(workout.date)}</p>
      <h1 class="large-title">${templateName(catalog, workout.templateId)}</h1>
      ${stats([[F.duration(workout.durationSeconds), '时长'], [workout.sets.length, '组'], [F.number(F.volume(workout.sets)), '总重量 lb']])}
      ${F.groupSets(workout.sets).map(group => {
        const exercise = catalog.exercise(group.exerciseId);
        return html`
          <h3 class="section-header">${exercise ? `${exercise.nameZh} · ${exercise.nameEn}` : group.exerciseId}</h3>
          <ul class="group">${group.sets.map(set => html`<li class="pair"><span>第 ${set.setIndex + 1} 组</span><span class="num">${F.setText(set, exercise)}</span></li>`)}</ul>`;
      })}
      <button class="button destructive" data-action="delete">删除这次训练</button>`,
    mount(root) {
      root.querySelector('[data-action=delete]').addEventListener('click', () => {
        if (!confirm('删除这次训练？')) return;
        store.markDeleted(id);
        app.sync();
        app.navigate('#/history');
      });
    },
  };
}

const MONTH = new Intl.DateTimeFormat('zh-CN', { month: 'short' });

/** 历史列表左边的日期块：大号日子，下面月份 */
function dayBadge(iso) {
  const d = new Date(iso);
  return html`<span class="day num"><b>${d.getDate()}</b><span>${MONTH.format(d)}</span></span>`;
}
