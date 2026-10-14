import { html } from '../dom.js';
import { isWeighted } from '../catalog.js';
import { WorkoutFlow } from '../flow.js';
import * as F from '../format.js';
import { stats, thumb } from './common.js';

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

/** 顶部：结束、已练时长、第几组；下面每个动作一段进度条 */
function header(session, flow) {
  const doneOf = id => flow.completedSets.filter(s => s.exerciseId === id).length;
  return html`
    <header class="workout-header">
      <button class="end" data-action="end">✕ 结束</button>
      <b class="num" data-elapsed>${F.duration(elapsed(session))}</b>
      <span class="count num">${Math.min(flow.completedSets.length + 1, flow.totalSets)} / ${flow.totalSets}</span>
    </header>
    <div class="segments" aria-hidden="true">${flow.workout.exercises.map(e =>
      html`<i style="--p: ${e.sets ? Math.round((doneOf(e.exerciseId) / e.sets) * 100) : 100}%"></i>`)}</div>`;
}

/** 器械被占时换到别的没做完的动作：底部弹出列表，点哪个就换到哪个 */
function switchSheet(app, flow) {
  const options = flow.switchable();
  if (options.length === 0) return '';
  return html`
    <dialog class="sheet" data-switch-sheet>
      <p class="eyebrow">换一个动作，这个之后再做</p>
      <ul class="list">${options.map(i => {
        const target = flow.workout.exercises[i];
        const exercise = app.catalog.exercise(target.exerciseId);
        const done = flow.doneSets(i);
        return html`<li><button class="row" data-switch-to="${i}">
          ${thumb(exercise)}
          <div class="row-text"><strong>${exercise.nameZh}</strong><span>${exercise.nameEn}</span></div>
          <div class="row-end num"><span>${done ? `已做 ${done} / ${target.sets} 组` : `${target.sets} 组`}</span></div>
        </button></li>`;
      })}</ul>
      <button class="button" data-action="close-sheet">取消</button>
    </dialog>`;
}

function mountSwitch(root, app, session, flow, extra = () => ({})) {
  const sheet = root.querySelector('[data-switch-sheet]');
  if (!sheet) return;
  root.querySelector('[data-action=switch]').addEventListener('click', () => sheet.showModal());
  sheet.querySelector('[data-action=close-sheet]').addEventListener('click', () => sheet.close());
  // 点遮罩关闭
  sheet.addEventListener('click', event => { if (event.target === sheet) sheet.close(); });
  for (const button of sheet.querySelectorAll('[data-switch-to]')) {
    button.addEventListener('click', () => {
      flow.switchTo(Number(button.dataset.switchTo));
      app.store.saveSession({ ...session, ...extra(), flow: flow.toJSON(), draft: null });
      sheet.close();
      app.refresh();
    });
  }
}

const elapsed = session => (Date.now() - Date.parse(session.startedAt)) / 1000;

/** 每秒刷新顶部的已练时长 */
function runClock(root, session) {
  const label = root.querySelector('[data-elapsed]');
  const timer = setInterval(() => { label.textContent = F.duration(elapsed(session)); }, 1000);
  return () => clearInterval(timer);
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
      ${header(session, flow)}
      <section class="set-head">
        <div>
          <h1>${exercise.nameZh}</h1>
          <p>${exercise.nameEn} · <a href="#/exercise/${exercise.id}">看示范 ›</a></p>
        </div>
        ${thumb(exercise, 'large')}
      </section>
      <p class="set-meta num"><span class="pill">第 ${position.setIndex + 1} 组 / ${target.sets}</span><span class="secondary">目标 ${F.target(target.targetMin, target.targetMax, exercise.unit)}</span>${flow.switchable().length
        ? html`<button class="link switch" data-action="switch">换动作</button>` : ''}</p>
      ${stepper('value', exercise.unit === 'seconds' ? '秒数' : '次数', '', valueText, exercise.unit === 'seconds' ? 5 : 1, F.unitZh(exercise.unit), 'numeric')}
      ${weighted
        ? stepper('weight', '重量', defaultWeight === null
          ? html`<span class="accent">第一次做，先填一个重量</span>`
          : `每次 ±${F.weight(exercise.increment)}`, weightText, exercise.increment, 'lb', 'decimal')
        : ''}
      <div class="bottom-action"><button class="button primary" data-action="done">完成这组<span class="dot" aria-hidden="true">✓</span></button></div>
      ${switchSheet(app, flow)}`,
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
        for (const field of root.querySelectorAll('.dial input')) field.style.setProperty('--len', fitLength(field.value));
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
      mountSwitch(root, app, session, flow);
      const release = keepAwake();
      const stopClock = runClock(root, session);
      return () => {
        stopClock();
        release();
      };
    },
  };
}

function stepper(name, label, note, text, step, unit, inputmode) {
  return html`
    <div class="dial" data-stepper data-step="${step}">
      <div class="dial-label"><span>${label}</span><span>${note}</span></div>
      <div class="dial-row">
        <label class="dial-value">
          <input name="${name}" inputmode="${inputmode}" value="${text}" placeholder="0" aria-label="${label}" style="--len: ${fitLength(text)}">
          <span>${unit}</span>
        </label>
        <button class="round" data-delta="-1" aria-label="减少${label}">−</button>
        <button class="round" data-delta="1" aria-label="增加${label}">+</button>
      </div>
    </div>`;
}

/** 输入框按数字位数变宽，单位紧跟在数字后面 */
const fitLength = text => Math.max(1, String(text).length);

/** 休息圆环的周长，半径 132、画布 290 */
const RING = 2 * Math.PI * 132;

const secondsLeft = endsAt => Math.max(0, Math.ceil((endsAt - Date.now()) / 1000));

function restScreen(app, session, flow) {
  const { catalog, store } = app;
  const target = flow.current;
  const next = catalog.exercise(target.exerciseId);
  const nextWeight = isWeighted(next) ? flow.defaultWeight() : null;
  let endsAt = session.restEndsAt ?? Date.now();
  // 圆环按剩余时间占比画；+30 秒后超过原定休息时间，就按加长后的总时长算
  const fraction = left => left / Math.max(flow.restSeconds, left, 1);

  return {
    html: html`
      ${header(session, flow)}
      <section class="rest">
        <p class="eyebrow">休息</p>
        <div class="ring">
          <svg viewBox="0 0 290 290" aria-hidden="true">
            <circle class="track" cx="145" cy="145" r="132"/>
            <circle class="bar" cx="145" cy="145" r="132" stroke-dasharray="${RING}" stroke-dashoffset="${RING * (1 - fraction(secondsLeft(endsAt)))}" data-ring/>
          </svg>
          <div class="ring-text">
            <p class="countdown" data-countdown>${F.duration(secondsLeft(endsAt))}</p>
            <span class="num">下一组 · 第 ${flow.position.setIndex + 1} 组</span>
          </div>
        </div>
        <div class="next">
          ${thumb(next)}
          <div class="row-text"><span>接下来</span><strong>${next.nameZh}</strong></div>
          <div class="row-end num">
            ${nextWeight !== null ? html`<b>${F.number(nextWeight)}<small>lb</small></b>` : ''}
            <span>${F.target(target.targetMin, target.targetMax, next.unit)}</span>
          </div>
        </div>
        ${flow.switchable().length ? html`<button class="link switch" data-action="switch">换一个动作</button>` : ''}
      </section>
      <div class="bottom-action row-buttons">
        <button class="button" data-action="add">+30 秒</button>
        <button class="button primary" data-action="skip">跳过</button>
      </div>
      ${switchSheet(app, flow)}`,
    mount(root) {
      const label = root.querySelector('[data-countdown]');
      const ring = root.querySelector('[data-ring]');
      const finishRest = () => {
        flow.finishRest();
        store.saveSession({ ...session, flow: flow.toJSON(), restEndsAt: null, draft: null });
        app.refresh();
      };
      // 按实际时间算，锁屏回来也是对的
      const tick = () => {
        const left = secondsLeft(endsAt);
        label.textContent = F.duration(left);
        ring.style.strokeDashoffset = RING * (1 - fraction(left));
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
      // 休息倒计时照常走，只换休息完要做的动作
      mountSwitch(root, app, session, flow, () => ({ restEndsAt: endsAt }));
      const release = keepAwake();
      const stopClock = runClock(root, session);
      return () => {
        clearInterval(timer);
        stopClock();
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
    ? '记录已保存在这台手机上。在「记录 → 设置」里开启同步后会备份到 GitHub。'
    : app.syncing
      ? '正在同步到 GitHub…'
      : status.error
        ? `同步失败：${status.error}`
        : '已同步到 GitHub。';

  return {
    html: html`
      <section class="done">
        <div class="done-mark" aria-hidden="true">✓</div>
        <h1>训练完成</h1>
        ${stats([[F.duration(workout.durationSeconds), '时长'], [workout.sets.length, '组'], [F.number(F.volume(workout.sets)), '总重量 lb']])}
        <p class="section-footer">${syncText}</p>
        <a class="button primary" href="#/today">回到今天</a>
      </section>`,
  };
}
