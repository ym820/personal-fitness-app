import { html } from '../dom.js';
import { isWeighted } from '../catalog.js';
import { WorkoutFlow } from '../flow.js';
import * as F from '../format.js';
import { templateName } from './common.js';

/** 新的进行中训练。id 在开始时就定下，结束时用它存记录，重复结束也只有一条 */
export function startSession(workout, restSeconds) {
  return {
    id: crypto.randomUUID(),
    flow: new WorkoutFlow(workout, restSeconds).toJSON(),
    startedAt: new Date().toISOString(),
    restEndsAt: null,
    draft: null,
  };
}

export function workoutView(app) {
  const session = app.store.loadSession();
  if (!session) {
    queueMicrotask(() => app.navigate('#/today'));
    return { html: '' };
  }
  const flow = WorkoutFlow.fromJSON(session.flow);
  if (flow.phase.type === 'finished') {
    // 上次「结束」存完记录后页面被关了，这里补完
    queueMicrotask(() => finish(app, session, flow));
    return { html: '' };
  }
  return flow.phase.type === 'resting' ? restScreen(app, session, flow) : setScreen(app, session, flow);
}

function header(app, flow) {
  return html`
    <header class="workout-header">
      <span class="secondary num">${templateName(app.catalog, flow.workout.templateId)} · 第 ${Math.min(flow.completedSets.length + 1, flow.totalSets)} / ${flow.totalSets} 组</span>
      <button class="link" data-action="end">结束训练</button>
    </header>
    <progress max="${flow.totalSets}" value="${flow.completedSets.length}"></progress>`;
}

function setScreen(app, session, flow) {
  const { catalog, store } = app;
  const target = flow.current;
  const exercise = catalog.exercise(target.exerciseId);
  const position = flow.position;
  const weighted = isWeighted(exercise);
  const defaultWeight = flow.defaultWeight();
  const draft = session.draft ?? {};
  const valueText = draft.value ?? String(flow.defaultValue());
  const weightText = draft.weight ?? (defaultWeight === null ? '' : F.inputNumber(defaultWeight));

  return {
    html: html`
      ${header(app, flow)}
      <section class="set-card">
        <h1 class="title">${exercise.nameZh}</h1>
        <p class="secondary">${exercise.nameEn}</p>
        <p class="set-count num">第 ${position.setIndex + 1} 组 / 共 ${target.sets} 组</p>
        <p class="secondary num">目标 ${F.target(target.targetMin, target.targetMax, exercise.unit)}${weighted && target.weightLb !== null ? ` · ${F.weight(target.weightLb)}` : ''}</p>
        <a class="link" href="#/exercise/${exercise.id}">看示范</a>
      </section>
      ${stepper('value', exercise.unit === 'seconds' ? '秒数' : '次数', valueText, exercise.unit === 'seconds' ? 5 : 1, F.unitZh(exercise.unit), 'numeric')}
      ${weighted ? stepper('weight', '重量', weightText, exercise.increment, 'lb', 'decimal') : ''}
      ${weighted && defaultWeight === null ? html`<p class="hint">第一次做这个动作，先填一个重量</p>` : ''}
      <div class="bottom-action"><button class="button primary" data-action="done">完成这组</button></div>`,
    mount(root) {
      const input = name => root.querySelector(`input[name=${name}]`);
      const done = root.querySelector('[data-action=done]');
      const read = () => ({
        value: F.parseCount(input('value').value),
        weight: weighted ? F.parseWeight(input('weight').value) : 0,
      });
      const refreshButton = () => {
        const d = read();
        done.disabled = d.value === null || d.weight === null;
      };
      const saveDraft = () => {
        refreshButton();
        store.saveSession({ ...session, draft: { value: input('value').value, weight: input('weight')?.value } });
      };

      for (const box of root.querySelectorAll('[data-stepper]')) {
        const field = box.querySelector('input');
        const step = Number(box.dataset.step);
        for (const button of box.querySelectorAll('[data-delta]')) {
          button.addEventListener('click', () => {
            const current = Number(field.value) || 0;
            field.value = F.inputNumber(Math.max(0, current + step * Number(button.dataset.delta)));
            saveDraft();
          });
        }
        field.addEventListener('input', saveDraft);
      }
      refreshButton();

      done.addEventListener('click', () => {
        const d = read();
        if (d.value === null || d.weight === null) return;
        flow.completeSet(d.value, d.weight);
        const restEndsAt = flow.phase.type === 'resting' ? Date.now() + flow.restSeconds * 1000 : null;
        store.saveSession({ ...session, flow: flow.toJSON(), draft: null, restEndsAt });
        app.refresh();
      });
      root.querySelector('[data-action=end]').addEventListener('click', () => endWorkout(app, session, flow));
      return keepAwake();
    },
  };
}

function stepper(name, label, text, step, unit, inputmode) {
  return html`
    <div class="stepper" data-stepper data-step="${step}">
      <span>${label}</span>
      <button class="round" data-delta="-1" aria-label="减少${label}">−</button>
      <input name="${name}" inputmode="${inputmode}" value="${text}" placeholder="填写" aria-label="${label}">
      <span class="secondary">${unit}</span>
      <button class="round" data-delta="1" aria-label="增加${label}">+</button>
    </div>`;
}

const secondsLeft = endsAt => Math.max(0, Math.ceil((endsAt - Date.now()) / 1000));

function restScreen(app, session, flow) {
  const { catalog, store } = app;
  const next = catalog.exercise(flow.current.exerciseId);
  let endsAt = session.restEndsAt ?? Date.now();

  return {
    html: html`
      ${header(app, flow)}
      <section class="rest">
        <p class="secondary">休息</p>
        <p class="countdown" data-countdown>${F.duration(secondsLeft(endsAt))}</p>
        <p>下一组：${next.nameZh} 第 ${flow.position.setIndex + 1} 组</p>
        <div class="row-buttons">
          <button class="button" data-action="add">+30 秒</button>
          <button class="button primary" data-action="skip">跳过</button>
        </div>
      </section>`,
    mount(root) {
      const label = root.querySelector('[data-countdown]');
      const finishRest = () => {
        flow.finishRest();
        store.saveSession({ ...session, flow: flow.toJSON(), restEndsAt: null, draft: null });
        app.refresh();
      };
      // 按实际时间算，锁屏回来也是对的
      const tick = () => {
        const left = secondsLeft(endsAt);
        label.textContent = F.duration(left);
        if (left === 0) finishRest();
      };
      const timer = setInterval(tick, 250);
      root.querySelector('[data-action=add]').addEventListener('click', () => {
        endsAt += 30_000;
        store.saveSession({ ...session, restEndsAt: endsAt });
        tick();
      });
      root.querySelector('[data-action=skip]').addEventListener('click', finishRest);
      root.querySelector('[data-action=end]').addEventListener('click', () => endWorkout(app, session, flow));
      const release = keepAwake();
      return () => {
        clearInterval(timer);
        release();
      };
    },
  };
}

function endWorkout(app, session, flow) {
  const message = flow.completedSets.length
    ? '结束训练？已完成的组会保存。'
    : '结束训练？还没有完成任何一组，不会保存记录。';
  if (!confirm(message)) return;
  flow.endEarly();
  finish(app, session, flow);
}

/** 先存记录再清掉进行中的训练：中间被关掉，下次打开会再走一遍这里，按 id 去重不会重复 */
function finish(app, session, flow) {
  const { store } = app;
  if (flow.completedSets.length === 0) {
    store.clearSession();
    app.navigate('#/today');
    return;
  }
  store.addWorkout({
    id: session.id,
    date: session.startedAt,
    durationSeconds: Math.round((Date.now() - Date.parse(session.startedAt)) / 1000),
    templateId: flow.workout.templateId,
    sets: flow.completedSets,
    deleted: false,
  });
  store.clearSession();
  app.sync();
  app.navigate(`#/done/${session.id}`);
}

/** 训练时保持屏幕常亮。不支持或被拒绝时照常用，只是可能自动锁屏 */
function keepAwake() {
  let lock = null;
  let released = false;
  const request = async () => {
    try {
      const next = await navigator.wakeLock?.request('screen');
      if (released) next?.release();
      else lock = next ?? null;
    } catch {
      // 不支持或没有权限
    }
  };
  const onVisible = () => {
    if (document.visibilityState === 'visible' && !released) request();
  };
  request();
  document.addEventListener('visibilitychange', onVisible);
  return () => {
    released = true;
    document.removeEventListener('visibilitychange', onVisible);
    lock?.release().catch(() => {});
  };
}

export function doneView(app, id) {
  const { store } = app;
  const workout = store.visibleWorkouts().find(w => w.id === id);
  if (!workout) return { html: html`<p class="empty">找不到这次训练</p>` };
  const { token } = store.loadSettings();
  const status = store.loadSyncStatus();
  const syncText = !token
    ? '记录已保存在这台手机上。在「历史 → 设置」里开启同步后会备份到 GitHub。'
    : app.syncing
      ? '正在同步到 GitHub…'
      : status.error
        ? `同步失败：${status.error}`
        : '已同步到 GitHub。';

  return {
    html: html`
      <section class="done">
        <div class="done-mark" aria-hidden="true">✓</div>
        <h1 class="title">训练完成</h1>
        <ul class="list">
          <li class="pair"><span>时长</span><span class="num">${F.duration(workout.durationSeconds)}</span></li>
          <li class="pair"><span>完成</span><span class="num">${workout.sets.length} 组</span></li>
        </ul>
        <p class="section-footer">${syncText}</p>
        <a class="button primary" href="#/today">回到今天</a>
      </section>`,
  };
}
