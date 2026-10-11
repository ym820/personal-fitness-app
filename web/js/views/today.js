import { html } from '../dom.js';
import { isWeighted } from '../catalog.js';
import { estimatedDurationSeconds, nextWorkout, totalSets } from '../plan.js';
import * as F from '../format.js';
import { tag, templateName, thumb } from './common.js';
import { startSession } from './workout.js';

export function todayView(app) {
  const { catalog, store } = app;
  const done = store.visibleWorkouts();
  const workout = nextWorkout(catalog, done);
  const last = done.reduce((a, w) => (!a || Date.parse(w.date) > Date.parse(a.date) ? w : a), null);
  const rest = catalog.plan.restSeconds;

  return {
    html: html`
      <h1 class="large-title">今天</h1>
      <section class="card hero">
        <p class="secondary">下次训练</p>
        <h2>${templateName(catalog, workout.templateId)}</h2>
        <p>${workout.exercises.length} 个动作 · ${totalSets(workout)} 组 · ${F.approxMinutes(estimatedDurationSeconds(workout, rest))}</p>
        <p class="footnote secondary">${last ? `上次：${F.dateShort(last.date)} ${templateName(catalog, last.templateId)}` : '第一次训练，点下面的「开始训练」'}</p>
      </section>
      <h3 class="section-header">动作</h3>
      <ul class="list">${workout.exercises.map(t => row(catalog.exercise(t.exerciseId), t))}</ul>
      <p class="section-footer">每组之间休息 ${rest} 秒。所有组都做到最高次数，下次会自动加重。</p>
      <div class="bottom-action">
        <button class="button primary" data-action="start">${store.loadSession() ? '继续训练' : '开始训练'}</button>
      </div>`,
    mount(root) {
      root.querySelector('[data-action=start]').addEventListener('click', () => {
        if (!store.loadSession()) store.saveSession(startSession(workout, rest));
        app.navigate('#/workout');
      });
    },
  };
}

function row(exercise, t) {
  return html`<li><a class="row" href="#/exercise/${exercise.id}">
    ${thumb(exercise)}
    <div class="row-text">
      <strong>${exercise.nameZh}</strong>
      <span class="secondary">${exercise.nameEn}</span>
      <span class="footnote num">${t.sets} × ${F.target(t.targetMin, t.targetMax, exercise.unit)} ${weightTag(exercise, t)}</span>
    </div>
  </a></li>`;
}

function weightTag(exercise, t) {
  if (!isWeighted(exercise)) return '';
  if (t.weightLb === null) return tag('首次，开始后填重量', 'orange');
  return html`${F.weight(t.weightLb)} ${t.suggestIncrease ? tag(`加重 +${F.weight(exercise.increment)}`, 'green') : ''}`;
}
