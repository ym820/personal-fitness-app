import { html } from '../dom.js';
import * as F from '../format.js';
import { templateName } from './common.js';

export function historyView(app) {
  const { catalog, store } = app;
  const list = store.visibleWorkouts().sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
  return {
    html: html`
      <header class="page-header">
        <h1 class="large-title">历史</h1>
        <a href="#/settings">设置</a>
      </header>
      ${list.length
        ? html`<ul class="list">${list.map(w => html`<li><a class="row" href="#/history/${w.id}">
            <div class="row-text">
              <strong>${templateName(catalog, w.templateId)}</strong>
              <span class="secondary row-meta"><span>${F.dateTime(w.date)}</span><span class="num">${w.sets.length} 组 · ${F.duration(w.durationSeconds)}</span></span>
            </div>
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
      <nav class="navbar"><a class="back" href="#/history">‹ 历史</a><span>${templateName(catalog, workout.templateId)}</span></nav>
      <ul class="list">
        <li class="pair"><span>日期</span><span class="secondary">${F.dateLong(workout.date)}</span></li>
        <li class="pair"><span>时长</span><span class="secondary num">${F.duration(workout.durationSeconds)}</span></li>
      </ul>
      ${F.groupSets(workout.sets).map(group => {
        const exercise = catalog.exercise(group.exerciseId);
        return html`
          <h3 class="section-header">${exercise ? `${exercise.nameZh}  ${exercise.nameEn}` : group.exerciseId}</h3>
          <ul class="list">${group.sets.map(set => html`<li class="pair"><span>第 ${set.setIndex + 1} 组</span><span class="num">${F.setText(set, exercise)}</span></li>`)}</ul>`;
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
