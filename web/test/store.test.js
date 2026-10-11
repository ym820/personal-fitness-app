import test from 'node:test';
import assert from 'node:assert/strict';
import { createStore, memoryStorage } from '../js/store.js';

const w = (id, extra = {}) => ({ id, date: '2026-10-12T10:00:00.000Z', durationSeconds: 60, templateId: 'A', sets: [], deleted: false, ...extra });

test('添加、读取训练记录', () => {
  const store = createStore(memoryStorage());
  assert.deepEqual(store.loadWorkouts(), []);
  store.addWorkout(w('a'));
  assert.deepEqual(store.loadWorkouts().map(x => x.id), ['a']);
});

test('同一条记录添加两次只留一条', () => {
  const store = createStore(memoryStorage());
  store.addWorkout(w('a'));
  store.addWorkout(w('a'));
  assert.equal(store.loadWorkouts().length, 1);
});

test('删除只做标记，visibleWorkouts 不显示', () => {
  const store = createStore(memoryStorage());
  store.addWorkout(w('a'));
  store.addWorkout(w('b'));
  store.markDeleted('a');
  assert.equal(store.loadWorkouts().length, 2);
  assert.deepEqual(store.visibleWorkouts().map(x => x.id), ['b']);
});

test('进行中的训练：存、读、清除', () => {
  const store = createStore(memoryStorage());
  assert.equal(store.loadSession(), null);
  store.saveSession({ id: 's1' });
  assert.deepEqual(store.loadSession(), { id: 's1' });
  store.clearSession();
  assert.equal(store.loadSession(), null);
});

test('设置和同步状态有默认值', () => {
  const store = createStore(memoryStorage());
  assert.deepEqual(store.loadSettings(), { token: '', repo: 'ym820/fitness-data' });
  assert.deepEqual(store.loadSyncStatus(), { lastSuccessAt: null, error: null });
  store.saveSettings({ token: 't', repo: 'me/data' });
  assert.deepEqual(store.loadSettings(), { token: 't', repo: 'me/data' });
});

test('存储里的数据坏了，用默认值，不报错', () => {
  const storage = memoryStorage();
  storage.setItem('fitness.workouts', '{坏的');
  assert.deepEqual(createStore(storage).loadWorkouts(), []);
});
