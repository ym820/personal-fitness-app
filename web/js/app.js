import { html } from './dom.js';
import { loadCatalog } from './catalog.js';
import { createStore, memoryStorage } from './store.js';
import { mergeWorkouts } from './merge.js';
import { syncWorkouts } from './sync.js';
import { todayView } from './views/today.js';
import { exerciseView, libraryView } from './views/library.js';
import { historyView, workoutDetailView } from './views/history.js';
import { settingsView } from './views/settings.js';
import { doneView, workoutView } from './views/workout.js';

/** localStorage 能用就用；无痕模式等情况下用内存代替，并显示提示 */
function pickStorage() {
  try {
    localStorage.setItem('fitness.test', '1');
    localStorage.removeItem('fitness.test');
    return localStorage;
  } catch {
    return null;
  }
}

const storage = pickStorage();
const main = document.getElementById('app');

const app = {
  catalog: null,
  store: createStore(storage ?? memoryStorage()),
  syncing: false,
  navigate(hash) {
    if (location.hash === hash) render();
    else location.hash = hash;
  },
  refresh: () => render(),
  sync: () => syncNow(),
};

const routes = [
  [/^#\/today$/, todayView],
  [/^#\/library$/, libraryView],
  [/^#\/exercise\/([^/]+)$/, exerciseView],
  [/^#\/history$/, historyView],
  [/^#\/history\/([^/]+)$/, workoutDetailView],
  [/^#\/settings$/, settingsView],
  [/^#\/workout$/, workoutView],
  [/^#\/done\/([^/]+)$/, doneView],
];

/** 详情页、设置页等高亮哪个标签 */
const TAB_FOR = { exercise: 'library', settings: 'history', workout: 'today', done: 'today' };

let cleanup = null;

function render() {
  cleanup?.();
  cleanup = null;
  const hash = location.hash || '#/today';
  const found = routes.map(([pattern, view]) => [hash.match(pattern), view]).find(([m]) => m);
  if (!found) return app.navigate('#/today');
  const [match, view] = found;
  const page = view(app, ...match.slice(1).map(decodeURIComponent));
  main.innerHTML = String(page.html);
  cleanup = page.mount?.(main) ?? null;

  const section = hash.split('/')[1];
  const tab = TAB_FOR[section] ?? section;
  document.querySelectorAll('.tabbar a').forEach(a => a.classList.toggle('active', a.dataset.tab === tab));
  document.body.classList.toggle('in-workout', section === 'workout');
}

let inFlight = null;

/** 同步到 GitHub。没填令牌就什么都不做；同时只跑一个 */
function syncNow() {
  const { token, repo } = app.store.loadSettings();
  if (!token || !repo) return Promise.resolve();
  inFlight ??= (async () => {
    app.syncing = true;
    try {
      const merged = await syncWorkouts({ token, repo, local: app.store.loadWorkouts() });
      // 同步期间可能又存了新记录，和最新的本地记录再合并一次，不丢
      app.store.saveWorkouts(mergeWorkouts(app.store.loadWorkouts(), merged));
      app.store.saveSyncStatus({ lastSuccessAt: new Date().toISOString(), error: null });
    } catch (error) {
      app.store.saveSyncStatus({ ...app.store.loadSyncStatus(), error: error.message });
    } finally {
      app.syncing = false;
      inFlight = null;
      // 训练页有输入框和倒计时，不打断
      if (!location.hash.startsWith('#/workout')) render();
    }
  })();
  return inFlight;
}

async function start() {
  document.getElementById('banner').hidden = Boolean(storage);
  try {
    app.catalog = await loadCatalog();
  } catch (error) {
    main.innerHTML = String(html`<div class="empty"><p>${error.message}</p><button class="button" onclick="location.reload()">重试</button></div>`);
    return;
  }
  addEventListener('hashchange', () => {
    render();
    scrollTo(0, 0);
  });
  render();
  syncNow();
}

start();
