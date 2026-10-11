import { mergeWorkouts } from './merge.js';

const KEYS = {
  workouts: 'fitness.workouts',
  session: 'fitness.session',
  settings: 'fitness.settings',
  syncStatus: 'fitness.syncStatus',
};

/** localStorage 用不了时（比如无痕模式）的替代品，关掉页面就没了 */
export function memoryStorage() {
  const map = new Map();
  return {
    getItem: key => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, String(value)),
    removeItem: key => map.delete(key),
  };
}

export function createStore(storage) {
  const read = (key, fallback) => {
    try {
      const text = storage.getItem(key);
      return text === null ? fallback : JSON.parse(text);
    } catch {
      return fallback;
    }
  };
  const write = (key, value) => storage.setItem(key, JSON.stringify(value));

  const store = {
    loadWorkouts: () => read(KEYS.workouts, []),
    saveWorkouts: list => write(KEYS.workouts, list),
    visibleWorkouts: () => store.loadWorkouts().filter(w => !w.deleted),
    /** 按 id 合并：「结束」存完记录后页面被关、重新打开又结束一次，也只有一条 */
    addWorkout: workout => store.saveWorkouts(mergeWorkouts(store.loadWorkouts(), [workout])),
    markDeleted: id => store.saveWorkouts(store.loadWorkouts().map(w => (w.id === id ? { ...w, deleted: true } : w))),

    loadSession: () => read(KEYS.session, null),
    saveSession: session => write(KEYS.session, session),
    clearSession: () => storage.removeItem(KEYS.session),

    loadSettings: () => read(KEYS.settings, { token: '', repo: 'ym820/fitness-data' }),
    saveSettings: settings => write(KEYS.settings, settings),

    loadSyncStatus: () => read(KEYS.syncStatus, { lastSuccessAt: null, error: null }),
    saveSyncStatus: status => write(KEYS.syncStatus, status),
  };
  return store;
}
