import { html } from '../dom.js';
import { isWeighted } from '../catalog.js';
import { estimatedDurationSeconds, nextWorkout, totalSets } from '../plan.js';
import * as F from '../format.js';
import { index2, stats, templateName, thumb } from './common.js';
import { startSession } from './workout.js';

export function todayView(app) {
  const { catalog, store } = app;
  const done = store.visibleWorkouts();
  const workout = nextWorkout(catalog, done);
  const last = done.reduce((a, w) => (!a || Date.parse(w.date) > Date.parse(a.date) ? w : a), null);
  const rest = catalog.plan.restSeconds;
  const minutes = Math.max(5, Math.round(estimatedDurationSeconds(workout, rest) / 60 / 5) * 5);

  return {
    html: html`
      <p class="eyebrow">${F.dateShort(new Date().toISOString())}${last ? ` · 上次 ${F.dateShort(last.date)}` : ''}</p>
      <section class="hero">
        <small>${last ? '下次训练' : '第一次训练'}</small>
        <h1>${templateName(catalog, workout.templateId)}</h1>
      </section>
      ${stats([[workout.exercises.length, '动作'], [totalSets(workout), '组'], [`~${minutes}`, '分钟']])}
      <ul class="list">${workout.exercises.map((t, i) => row(catalog.exercise(t.exerciseId), t, i))}</ul>
      <p class="section-footer">每组之间休息 ${rest} 秒。所有组都做到最高次数，下次自动加重。</p>
      <div class="bottom-action">
        <button class="button primary" data-action="start">${store.loadSession() ? '继续训练' : '开始训练'}<span class="dot" aria-hidden="true">→</span></button>
      </div>`,
    mount(root) {
      root.querySelector('[data-action=start]').addEventListener('click', () => {
        if (!store.loadSession()) store.saveSession(startSession(workout, rest));
        app.navigate('#/workout');
      });
    },
  };
}

function row(exercise, t, i) {
  return html`<li><a class="row" href="#/exercise/${exercise.id}">
    <span class="idx num">${index2(i)}</span>
    ${thumb(exercise)}
    <div class="row-text">
      <strong>${exercise.nameZh}</strong>
      <span class="num">${t.sets} × ${F.target(t.targetMin, t.targetMax, exercise.unit)}</span>
    </div>
    ${weight(exercise, t)}
  </a></li>`;
}

function weight(exercise, t) {
  if (!isWeighted(exercise)) return '';
  if (t.weightLb === null) return html`<div class="row-end"><b class="secondary">—</b><span>首次</span></div>`;
  return html`<div class="row-end num">
    <b>${F.number(t.weightLb)}<small>lb</small></b>
    ${t.suggestIncrease ? html`<span class="accent">↑ +${F.number(exercise.increment)}</span>` : ''}
  </div>`;
}
