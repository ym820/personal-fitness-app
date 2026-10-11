import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { catalog } from './fixtures.js';
import { BODY_PARTS, filterExercises, isWeighted, thumbnailURL, watchURL } from '../js/catalog.js';

test('计划里的动作都在动作库里', () => {
  for (const template of catalog.plan.templates) {
    for (const item of template.exercises) assert.ok(catalog.exercise(item.exerciseId), item.exerciseId);
  }
  assert.equal(catalog.template('A').nameZh, '训练 A');
});

test('每个动作有 1 到 2 张示范图（平板支撑这类静态动作只有一张），图片文件存在', () => {
  for (const e of catalog.exercises) {
    assert.ok(e.images.length >= 1 && e.images.length <= 2, e.id);
    for (const name of e.images) {
      const file = new URL(`../../FitnessApp/Assets.xcassets/ExerciseImages/${name}.imageset/${name}.svg`, import.meta.url);
      assert.ok(existsSync(file), name);
    }
  }
});

test('每个动作的部位都在 BODY_PARTS 里', () => {
  const parts = new Set(BODY_PARTS.map(([id]) => id));
  for (const e of catalog.exercises) assert.ok(parts.has(e.bodyPart), `${e.id}: ${e.bodyPart}`);
});

test('加重步长大于 0 才算负重动作', () => {
  assert.equal(isWeighted(catalog.exercise('Leg_Press')), true);
  assert.equal(isWeighted(catalog.exercise('Plank')), false);
});

test('搜索中英文名和器材，不分大小写，空白等于不搜', () => {
  assert.ok(filterExercises(catalog.exercises, 'leg press').some(e => e.id === 'Leg_Press'));
  assert.ok(filterExercises(catalog.exercises, '哑铃').length > 0);
  assert.equal(filterExercises(catalog.exercises, '  ').length, catalog.exercises.length);
  assert.equal(filterExercises(catalog.exercises, 'zzz').length, 0);
});

test('视频地址和封面', () => {
  assert.equal(watchURL({ platform: 'bilibili', id: 'BV1x' }), 'https://www.bilibili.com/video/BV1x');
  assert.equal(watchURL({ platform: 'youtube', id: 'abc' }), 'https://www.youtube.com/watch?v=abc');
  assert.equal(thumbnailURL({ platform: 'youtube', id: 'abc' }), 'https://i.ytimg.com/vi/abc/hqdefault.jpg');
  assert.equal(thumbnailURL({ platform: 'bilibili', id: 'BV1x', thumbnail: 'https://i0.hdslb.com/a.jpg' }), 'https://i0.hdslb.com/a.jpg');
  assert.equal(thumbnailURL({ platform: 'bilibili', id: 'BV1x' }), null);
  assert.ok(catalog.videosFor('Leg_Press').length > 0);
  assert.deepEqual(catalog.videosFor('nope'), []);
});
