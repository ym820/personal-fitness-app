# 网页版实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做一个取代 iOS app 的网页版（PWA）：在 iPhone 上看计划、看动作和视频、记组数和重量、休息计时，训练记录存在手机本地并自动同步到 GitHub 私有仓库。

**Architecture:** `web/` 下是纯 HTML + CSS + ES module，没有编译步骤。计划推进、训练流程、记录合并、GitHub 同步写成不碰 DOM 的模块，用 `node --test` 测；页面模块只负责拼 HTML 和绑定事件。`scripts/build_web.sh` 把 `web/`、现有的 JSON 和 SVG 复制到 `_site/`，GitHub Actions 把 `_site/` 发布到 GitHub Pages。

**Tech Stack:** HTML、CSS、JavaScript（ES modules）、Node 内置测试（`node --test`，Node 20+）、Service Worker、GitHub REST API（Contents）、GitHub Actions + GitHub Pages。

**Spec:** `docs/superpowers/specs/2026-10-11-web-app-design.md`

## Global Constraints

- 不用 npm 依赖，不加编译步骤。`web/package.json` 只写 `{"type": "module"}`，让 Node 把 `.js` 当 ES module
- 网站发布在 `https://ym820.github.io/personal-fitness-app/`，页面里所有地址都用相对路径（`img/...`、`data/...`），不能以 `/` 开头
- 动作、计划、视频 JSON 继续放在 `Packages/FitnessCore/Sources/FitnessCore/Resources/`，示范图继续用 `FitnessApp/Assets.xcassets/ExerciseImages/*.imageset/*.svg`，不复制进 `web/`
- 界面文字用中文；不用长破折号，用「 - 」或改写句子
- 训练记录格式：`{ id, date, durationSeconds, templateId, sets: [{ exerciseId, setIndex, value, weightLb }], deleted }`
- GitHub 令牌只存在手机的 localStorage，不写进代码、不提交
- 不改 iOS 代码（`FitnessApp/`、`FitnessWatch/`、`Packages/`），只读它的数据和图片
- 提交（commit）和推送（push）分开执行，计划里只提交

## Review Focus

- GitHub 上的 `workouts.json` 被手动改坏（不是 JSON，或者结构不对）：报错，**不能**用本地记录覆盖它。测试在 Task 5
- 同步还在进行时又存了一次新训练：新训练不能丢。测试在 Task 4（「同步期间新增的记录不会丢」）
- 训练进行中关掉页面、或者「结束」刚存完记录就被关掉：重新打开能接着练，且不会出现两条相同的记录。测试在 Task 3（JSON 往返）和 Task 4（`addWorkout` 按 id 去重）
- 次数或重量输入框里填了空、字母、负数、小数次数：「完成这组」按钮不可点。测试在 Task 1（`parseCount` / `parseWeight`）
- 视频标题这类外部数据里带了 `<script>` 或引号：按文字显示，不会被当成 HTML。测试在 Task 1（`html` 转义）

---

## 文件结构

```
web/
  package.json            {"type": "module"}，只给 Node 测试用，不发布
  index.html              页面骨架：横幅、<main>、底部标签栏
  app.css                 全部样式
  manifest.webmanifest    添加到主屏幕用（Task 10）
  sw.js                   Service Worker，离线缓存（Task 10）
  js/
    dom.js                html 模板字符串（自动转义）
    format.js             数字、时长、日期、输入解析、按动作分组
    catalog.js            读 JSON，查动作和计划，搜索，视频地址
    plan.js               下次练 A/B、目标重量、加重规则
    flow.js               一次训练的流程（做组、休息、结束）
    merge.js              按 id 合并训练记录
    store.js              localStorage 读写
    sync.js               GitHub Contents API 同步
    app.js                入口：路由、同步调度、启动
    views/
      common.js           缩略图、标签、训练名
      today.js            今天页
      library.js          动作库、动作详情
      history.js          历史列表、单次训练详情
      settings.js         设置（令牌、同步状态）
      workout.js          做组、休息、结束页
  test/
    fixtures.js           读真实 JSON 生成 catalog
    *.test.js
scripts/build_web.sh      组装 _site/
.github/workflows/pages.yml
```

---

### Task 1: 基础模块和组装脚本

**Files:**
- Create: `web/package.json`
- Create: `web/js/dom.js`
- Create: `web/js/format.js`
- Create: `web/js/catalog.js`
- Create: `web/test/fixtures.js`
- Create: `web/test/dom.test.js`
- Create: `web/test/format.test.js`
- Create: `web/test/catalog.test.js`
- Create: `scripts/build_web.sh`
- Modify: `.gitignore`（末尾加 `_site/`）

**Interfaces:**
- Produces:
  - `dom.js`：`html` 模板标签，返回 `Raw`（`String(x)` 得到 HTML）；`raw(s)`；`esc(s)`
  - `format.js`：`number(v)`、`weight(lb)`、`unitZh(unit)`、`value(v, unit)`、`target(min, max, unit)`、`duration(seconds)`、`approxMinutes(seconds)`、`muscleZh(m)`、`dateShort(iso)`、`dateTime(iso)`、`dateLong(iso)`、`parseCount(text) -> number|null`、`parseWeight(text) -> number|null`、`groupSets(sets) -> [{exerciseId, sets}]`、`setText(set, exercise)`
  - `catalog.js`：`BODY_PARTS`（`[[id, 中文名], ...]`）、`isWeighted(exercise)`、`makeCatalog({exercises, plan, videos})` 返回 `{exercises, plan, exercise(id), template(id), videosFor(id)}`、`loadCatalog(base = 'data/')`、`filterExercises(exercises, query)`、`watchURL(video)`、`thumbnailURL(video)`
  - `fixtures.js`：`catalog`（用仓库里真实 JSON 生成）

- [ ] **Step 1: 建 `web/package.json` 和测试夹具**

`web/package.json`：

```json
{ "type": "module" }
```

`web/test/fixtures.js`：

```js
import { readFileSync } from 'node:fs';
import { makeCatalog } from '../js/catalog.js';

const dir = new URL('../../Packages/FitnessCore/Sources/FitnessCore/Resources/', import.meta.url);
const read = name => JSON.parse(readFileSync(new URL(`${name}.json`, dir), 'utf8'));

export const catalog = makeCatalog({ exercises: read('exercises'), plan: read('plan'), videos: read('videos') });
```

- [ ] **Step 2: 写失败的测试**

`web/test/dom.test.js`：

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { html } from '../js/dom.js';

test('插值会转义 HTML', () => {
  assert.equal(String(html`<p>${'<img src=x onerror=alert(1)>'}</p>`), '<p>&lt;img src=x onerror=alert(1)&gt;</p>');
});

test('引号也转义，放在属性里安全', () => {
  assert.equal(String(html`<a title="${'" onclick="x'}">`), '<a title="&quot; onclick=&quot;x">');
});

test('嵌套 html 和数组不会被二次转义', () => {
  const items = ['a', '<b>'].map(x => html`<li>${x}</li>`);
  assert.equal(String(html`<ul>${items}</ul>`), '<ul><li>a</li><li>&lt;b&gt;</li></ul>');
});

test('null、undefined、false 不输出，0 照常输出', () => {
  assert.equal(String(html`${null}${undefined}${false}${0}`), '0');
});
```

`web/test/format.test.js`：

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import * as F from '../js/format.js';

test('数字：整数不带小数，其他保留一位', () => {
  assert.equal(F.number(10), '10');
  assert.equal(F.number(2.5), '2.5');
  assert.equal(F.weight(90), '90 lb');
});

test('次数和目标', () => {
  assert.equal(F.value(12, 'reps'), '12 次');
  assert.equal(F.value(30, 'seconds'), '30 秒');
  assert.equal(F.target(8, 12, 'reps'), '8-12 次');
});

test('时长', () => {
  assert.equal(F.duration(65), '1:05');
  assert.equal(F.duration(3725), '1:02:05');
  assert.equal(F.duration(0), '0:00');
});

test('估算时长取整到 5 分钟，最少 5 分钟', () => {
  assert.equal(F.approxMinutes(0), '约 5 分钟');
  assert.equal(F.approxMinutes(1700), '约 30 分钟');
});

test('肌肉名翻译，没有的原样返回', () => {
  assert.equal(F.muscleZh('lats'), '背阔肌');
  assert.equal(F.muscleZh('unknown'), 'unknown');
});

test('次数只接受非负整数', () => {
  assert.equal(F.parseCount('12'), 12);
  assert.equal(F.parseCount(' 8 '), 8);
  assert.equal(F.parseCount('0'), 0);
  assert.equal(F.parseCount(''), null);
  assert.equal(F.parseCount('abc'), null);
  assert.equal(F.parseCount('-1'), null);
  assert.equal(F.parseCount('12.5'), null);
});

test('重量接受非负数，可以有小数', () => {
  assert.equal(F.parseWeight('42.5'), 42.5);
  assert.equal(F.parseWeight(' 40 '), 40);
  assert.equal(F.parseWeight('0'), 0);
  assert.equal(F.parseWeight(''), null);
  assert.equal(F.parseWeight('   '), null);
  assert.equal(F.parseWeight('abc'), null);
  assert.equal(F.parseWeight('-5'), null);
});

test('按动作分组，保持训练时的顺序', () => {
  const sets = [
    { exerciseId: 'A', setIndex: 0, value: 10, weightLb: 50 },
    { exerciseId: 'B', setIndex: 0, value: 10, weightLb: 20 },
    { exerciseId: 'A', setIndex: 1, value: 9, weightLb: 50 },
  ];
  assert.deepEqual(F.groupSets(sets).map(g => [g.exerciseId, g.sets.length]), [['A', 2], ['B', 1]]);
});

test('每组的文字：自重动作不显示重量', () => {
  const set = { exerciseId: 'x', setIndex: 0, value: 12, weightLb: 90 };
  assert.equal(F.setText(set, { unit: 'reps', increment: 10 }), '12 次 × 90 lb');
  assert.equal(F.setText({ ...set, value: 30, weightLb: 0 }, { unit: 'seconds', increment: 0 }), '30 秒');
  assert.equal(F.setText(set, undefined), '12 次 × 90 lb');
});
```

`web/test/catalog.test.js`：

```js
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
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `node --test web/test/*.test.js`
Expected: FAIL，报 `Cannot find module .../web/js/dom.js`（以及 format.js、catalog.js）

- [ ] **Step 4: 实现 `dom.js`、`format.js`、`catalog.js`**

`web/js/dom.js`：

```js
const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

export const esc = text => String(text).replace(/[&<>"']/g, c => ESCAPES[c]);

/** 已经是 HTML 的字符串，拼接时不再转义 */
export class Raw {
  constructor(text) { this.text = text; }
  toString() { return this.text; }
}

export const raw = text => new Raw(text);

/** html`<p>${x}</p>`：插值自动转义，嵌套的 html`` 和数组原样拼接 */
export function html(strings, ...values) {
  return raw(strings.reduce((out, s, i) => out + s + (i < values.length ? show(values[i]) : ''), ''));
}

function show(value) {
  if (value instanceof Raw) return value.text;
  if (Array.isArray(value)) return value.map(show).join('');
  if (value === null || value === undefined || value === false) return '';
  return esc(value);
}
```

`web/js/format.js`：

```js
import { isWeighted } from './catalog.js';

export const number = v => (Math.round(v) === v ? String(v) : v.toFixed(1));
export const weight = lb => `${number(lb)} lb`;
export const unitZh = unit => (unit === 'seconds' ? '秒' : '次');
export const value = (v, unit) => `${v} ${unitZh(unit)}`;
export const target = (min, max, unit) => `${min}-${max} ${unitZh(unit)}`;

/** 秒数 → "1:05" 或 "1:02:05" */
export function duration(seconds) {
  const total = Math.round(seconds);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = n => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

/** 估算时长，取整到 5 分钟 */
export const approxMinutes = seconds => `约 ${Math.max(5, Math.round(seconds / 60 / 5) * 5)} 分钟`;

const MUSCLES = {
  abdominals: '腹肌', biceps: '肱二头肌', calves: '小腿', chest: '胸肌', forearms: '前臂',
  glutes: '臀肌', hamstrings: '大腿后侧', lats: '背阔肌', 'lower back': '下背', 'middle back': '中背',
  quadriceps: '大腿前侧', shoulders: '肩部', traps: '斜方肌', triceps: '肱三头肌',
};
export const muscleZh = m => MUSCLES[m] ?? m;

const formatter = options => new Intl.DateTimeFormat('zh-CN', options);
const SHORT = formatter({ month: 'numeric', day: 'numeric', weekday: 'short' });
const DATE_TIME = formatter({ month: 'numeric', day: 'numeric', weekday: 'short', hour: '2-digit', minute: '2-digit' });
const LONG = formatter({ year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' });
export const dateShort = iso => SHORT.format(new Date(iso));
export const dateTime = iso => DATE_TIME.format(new Date(iso));
export const dateLong = iso => LONG.format(new Date(iso));

/** 输入框里的次数：非负整数，否则 null */
export function parseCount(text) {
  const t = String(text).trim();
  return /^\d+$/.test(t) ? Number(t) : null;
}

/** 输入框里的重量：非负数，可以有小数，否则 null */
export function parseWeight(text) {
  const t = String(text).trim();
  const n = Number(t);
  return t !== '' && Number.isFinite(n) && n >= 0 ? n : null;
}

/** 按动作分组，保持训练时的顺序 */
export function groupSets(sets) {
  const groups = [];
  for (const set of sets) {
    const group = groups.find(g => g.exerciseId === set.exerciseId);
    if (group) group.sets.push(set);
    else groups.push({ exerciseId: set.exerciseId, sets: [set] });
  }
  return groups;
}

/** "12 次 × 90 lb"，自重动作只显示次数。找不到动作时按负重、按次数显示 */
export function setText(set, exercise) {
  const text = value(set.value, exercise?.unit ?? 'reps');
  return exercise && !isWeighted(exercise) ? text : `${text} × ${weight(set.weightLb)}`;
}
```

`web/js/catalog.js`：

```js
/** 动作库按这个顺序分组 */
export const BODY_PARTS = [
  ['legs', '腿和臀'], ['chest', '胸'], ['back', '背'], ['shoulders', '肩'], ['arms', '手臂'], ['core', '核心'],
];

/** 加重步长大于 0 的是负重动作，自重动作为 0 */
export const isWeighted = exercise => exercise.increment > 0;

export function makeCatalog({ exercises, plan, videos = {} }) {
  const byId = new Map(exercises.map(e => [e.id, e]));
  return {
    exercises,
    plan,
    exercise: id => byId.get(id),
    template: id => plan.templates.find(t => t.id === id),
    videosFor: id => videos[id] ?? [],
  };
}

export async function loadCatalog(base = 'data/') {
  const get = async name => {
    const response = await fetch(`${base}${name}.json`);
    if (!response.ok) throw new Error(`读取 ${name}.json 失败（${response.status}）`);
    return response.json();
  };
  const [exercises, plan, videos] = await Promise.all(['exercises', 'plan', 'videos'].map(get));
  return makeCatalog({ exercises, plan, videos });
}

export function filterExercises(exercises, query) {
  const q = query.trim().toLowerCase();
  if (!q) return exercises;
  return exercises.filter(e => [e.nameZh, e.nameEn, e.equipmentZh, e.equipmentEn].some(s => s.toLowerCase().includes(q)));
}

export const watchURL = v =>
  v.platform === 'youtube' ? `https://www.youtube.com/watch?v=${v.id}` : `https://www.bilibili.com/video/${v.id}`;

export const thumbnailURL = v =>
  v.thumbnail ?? (v.platform === 'youtube' ? `https://i.ytimg.com/vi/${v.id}/hqdefault.jpg` : null);
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `node --test web/test/*.test.js`
Expected: PASS，全部通过

- [ ] **Step 6: 组装脚本**

`scripts/build_web.sh`：

```bash
#!/bin/bash
# 把网页代码、动作数据、示范图和图标组装到 _site/，本地预览和 GitHub Pages 都用它。
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf _site
mkdir -p _site/data _site/img
cp -R web/. _site/
rm -rf _site/test _site/package.json
cp Packages/FitnessCore/Sources/FitnessCore/Resources/{exercises,plan,videos}.json _site/data/
cp FitnessApp/Assets.xcassets/ExerciseImages/*.imageset/*.svg _site/img/
cp FitnessApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png _site/icon.png

# Service Worker 安装时预先缓存的文件列表
(cd _site && find . -type f ! -name sw.js ! -name files.json | sed 's|^\./||' | sort \
  | sed 's/.*/"&"/' | paste -sd, - | sed 's/.*/[&]/') > _site/files.json
```

然后：

```bash
chmod +x scripts/build_web.sh
echo '_site/' >> .gitignore
```

- [ ] **Step 7: 运行组装脚本，检查输出**

Run: `scripts/build_web.sh && ls _site _site/data && ls _site/img | wc -l && head -c 200 _site/files.json`
Expected: `_site` 里有 `data`、`img`、`icon.png`、`js`、`files.json`；`data` 里有三个 JSON；`img` 里 59 个 SVG（平板支撑只有一张图）；`files.json` 是以 `[` 开头的 JSON 数组。`_site` 里没有 `test` 和 `package.json`

- [ ] **Step 8: 提交**

```bash
git add web scripts/build_web.sh .gitignore
git commit -m "Add web base modules and site build script"
```

---

### Task 2: 计划推进（plan.js）

**Files:**
- Create: `web/js/plan.js`
- Test: `web/test/plan.test.js`

**Interfaces:**
- Consumes: `isWeighted` from `catalog.js`；`catalog.template(id)`、`catalog.exercise(id)`
- Produces:
  - `nextTemplateId(history) -> 'A'|'B'`，`history` 是训练记录数组（只用 `date`、`templateId`），调用方先过滤掉 `deleted`
  - `nextWorkout(catalog, history) -> { templateId, exercises: [{ exerciseId, sets, targetMin, targetMax, weightLb: number|null, suggestIncrease: boolean }] }`。`weightLb` 为 `null` 表示第一次做、要用户填；自重动作为 `0`
  - `totalSets(workout) -> number`
  - `estimatedDurationSeconds(workout, restSeconds) -> number`

- [ ] **Step 1: 写失败的测试**（从 `Packages/FitnessCore/Tests/FitnessCoreTests/PlanEngineTests.swift` 搬过来）

`web/test/plan.test.js`：

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { catalog } from './fixtures.js';
import { estimatedDurationSeconds, nextTemplateId, nextWorkout, totalSets } from '../js/plan.js';

const day = n => new Date(n * 86_400_000).toISOString();
const workout = (templateId, n, sets = []) => ({ id: `w${n}`, date: day(n), durationSeconds: 0, templateId, sets, deleted: false });
const sets = (exerciseId, values, weightLb) => values.map((value, setIndex) => ({ exerciseId, setIndex, value, weightLb }));
const target = (next, id) => {
  const t = next.exercises.find(e => e.exerciseId === id);
  assert.ok(t, `${id} 不在这次计划里`);
  return t;
};

test('没有记录从 A 开始', () => {
  assert.equal(nextTemplateId([]), 'A');
});

test('和最后一次训练交替', () => {
  assert.equal(nextTemplateId([workout('A', 1)]), 'B');
  assert.equal(nextTemplateId([workout('A', 1), workout('B', 3)]), 'A');
});

test('按日期找最后一次，不按数组顺序', () => {
  assert.equal(nextTemplateId([workout('B', 5), workout('A', 1), workout('B', 3)]), 'A');
});

test('第一次：负重动作没有重量，自重动作为 0，不提示加重', () => {
  const next = nextWorkout(catalog, []);
  assert.equal(next.templateId, 'A');
  assert.deepEqual(next.exercises.map(e => e.exerciseId), catalog.template('A').exercises.map(e => e.exerciseId));
  assert.equal(target(next, 'Leg_Press').weightLb, null);
  assert.equal(target(next, 'Plank').weightLb, 0);
  assert.ok(next.exercises.every(e => !e.suggestIncrease));
});

test('照抄计划里的组数和目标', () => {
  const next = nextWorkout(catalog, []);
  const legPress = target(next, 'Leg_Press');
  assert.equal(legPress.sets, 3);
  assert.equal(legPress.targetMin, 8);
  assert.equal(legPress.targetMax, 12);
  const plank = target(next, 'Plank');
  assert.equal(plank.targetMin, 20);
  assert.equal(plank.targetMax, 40);
});

test('所有组做满，器械加 10 lb', () => {
  const history = [workout('A', 1, sets('Leg_Press', [12, 12, 12], 100)), workout('B', 3)];
  const legPress = target(nextWorkout(catalog, history), 'Leg_Press');
  assert.equal(legPress.weightLb, 110);
  assert.equal(legPress.suggestIncrease, true);
});

test('差一次没做满，重量不变', () => {
  const history = [workout('A', 1, sets('Leg_Press', [12, 12, 11], 100)), workout('B', 3)];
  const legPress = target(nextWorkout(catalog, history), 'Leg_Press');
  assert.equal(legPress.weightLb, 100);
  assert.equal(legPress.suggestIncrease, false);
});

test('提前结束（组数不够）不加重', () => {
  const history = [workout('A', 1, sets('Leg_Press', [12, 12], 100)), workout('B', 3)];
  const legPress = target(nextWorkout(catalog, history), 'Leg_Press');
  assert.equal(legPress.weightLb, 100);
  assert.equal(legPress.suggestIncrease, false);
});

test('哑铃加 5 lb', () => {
  const history = [workout('B', 1, sets('Dumbbell_Bench_Press', [12, 12, 12], 20)), workout('A', 2)];
  const bench = target(nextWorkout(catalog, history), 'Dumbbell_Bench_Press');
  assert.equal(bench.weightLb, 25);
  assert.equal(bench.suggestIncrease, true);
});

test('自重动作不提示加重', () => {
  const history = [workout('A', 1, sets('Plank', [40, 40, 40], 0)), workout('B', 3)];
  const plank = target(nextWorkout(catalog, history), 'Plank');
  assert.equal(plank.weightLb, 0);
  assert.equal(plank.suggestIncrease, false);
});

test('用最近一次训练里最重的一组', () => {
  const history = [
    workout('A', 1, sets('Leg_Press', [12, 12, 12], 200)),
    workout('A', 5, [
      { exerciseId: 'Leg_Press', setIndex: 0, value: 10, weightLb: 90 },
      { exerciseId: 'Leg_Press', setIndex: 1, value: 9, weightLb: 100 },
      { exerciseId: 'Leg_Press', setIndex: 2, value: 8, weightLb: 100 },
    ]),
    workout('B', 7),
  ];
  const legPress = target(nextWorkout(catalog, history), 'Leg_Press');
  assert.equal(legPress.weightLb, 100);
  assert.equal(legPress.suggestIncrease, false);
});

test('其他动作不受影响', () => {
  const history = [workout('A', 1, sets('Leg_Press', [12, 12, 12], 100)), workout('B', 3)];
  const next = nextWorkout(catalog, history);
  assert.equal(next.templateId, 'A');
  assert.equal(target(next, 'Leverage_Chest_Press').weightLb, null);
});

test('总组数和估算时长（每组 45 秒 + 组间休息）', () => {
  const next = nextWorkout(catalog, []);
  assert.equal(totalSets(next), 15);
  assert.equal(estimatedDurationSeconds(next, 90), 15 * 45 + 14 * 90);
  assert.equal(estimatedDurationSeconds({ templateId: 'A', exercises: [] }, 90), 0);
});
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `node --test web/test/plan.test.js`
Expected: FAIL，`Cannot find module .../web/js/plan.js`

- [ ] **Step 3: 实现 `web/js/plan.js`**

```js
import { isWeighted } from './catalog.js';

/** 和最后一次训练交替；没有记录从 A 开始。调用方先去掉已删除的记录 */
export function nextTemplateId(history) {
  let last = null;
  for (const w of history) if (!last || Date.parse(w.date) > Date.parse(last.date)) last = w;
  return last?.templateId === 'A' ? 'B' : 'A';
}

export function nextWorkout(catalog, history) {
  const templateId = nextTemplateId(history);
  const items = catalog.template(templateId)?.exercises ?? [];
  const newestFirst = [...history].sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
  const exercises = items.flatMap(item => {
    const exercise = catalog.exercise(item.exerciseId);
    return exercise ? [target(item, exercise, newestFirst)] : [];
  });
  return { templateId, exercises };
}

function target(item, exercise, newestFirst) {
  const make = (weightLb, suggestIncrease = false) => ({
    exerciseId: item.exerciseId,
    sets: item.sets,
    targetMin: item.targetMin,
    targetMax: item.targetMax,
    weightLb,
    suggestIncrease,
  });

  if (!isWeighted(exercise)) return make(0);

  const lastSets = newestFirst
    .map(w => w.sets.filter(s => s.exerciseId === item.exerciseId))
    .find(s => s.length > 0);
  if (!lastSets) return make(null);

  const lastWeight = Math.max(...lastSets.map(s => s.weightLb));
  const completedAll = lastSets.length >= item.sets && lastSets.every(s => s.value >= item.targetMax);
  return completedAll ? make(lastWeight + exercise.increment, true) : make(lastWeight);
}

/** 估算时长时每组按 45 秒算 */
const SECONDS_PER_SET = 45;

export const totalSets = workout => workout.exercises.reduce((n, e) => n + e.sets, 0);

export function estimatedDurationSeconds(workout, restSeconds) {
  const n = totalSets(workout);
  return n === 0 ? 0 : n * SECONDS_PER_SET + (n - 1) * restSeconds;
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `node --test web/test/*.test.js`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add web/js/plan.js web/test/plan.test.js
git commit -m "Port plan engine to web"
```

---

### Task 3: 训练流程（flow.js）

**Files:**
- Create: `web/js/flow.js`
- Test: `web/test/flow.test.js`

**Interfaces:**
- Consumes: `totalSets` from `plan.js`；`nextWorkout` 的返回值作为 `workout`
- Produces: `class WorkoutFlow`
  - `new WorkoutFlow(workout, restSeconds)`；`WorkoutFlow.fromJSON(obj)`；`toJSON()`（`JSON.stringify(flow)` 可直接用）
  - `phase`：`{ type: 'doingSet', position }`、`{ type: 'resting', position }`（`position` 是休息完要做的那组）、`{ type: 'finished' }`；`position = { exerciseIndex, setIndex }`
  - `workout`、`restSeconds`、`completedSets`（`[{ exerciseId, setIndex, value, weightLb }]`）
  - getter：`totalSets`、`position`（finished 时为 `null`）、`current`（当前或下一组对应的 `workout.exercises[i]`，finished 时为 `null`）
  - `defaultValue()`、`defaultWeight() -> number|null`、`completeSet(value, weightLb)`、`finishRest()`、`endEarly()`；在不对的阶段调用时什么都不做

- [ ] **Step 1: 写失败的测试**（从 `WorkoutFlowTests.swift` 搬过来，加 JSON 往返）

`web/test/flow.test.js`：

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { WorkoutFlow } from '../js/flow.js';

const workout = {
  templateId: 'A',
  exercises: [
    { exerciseId: 'Leg_Press', sets: 3, targetMin: 8, targetMax: 12, weightLb: 100, suggestIncrease: false },
    { exerciseId: 'Leverage_Chest_Press', sets: 2, targetMin: 8, targetMax: 12, weightLb: null, suggestIncrease: false },
    { exerciseId: 'Plank', sets: 1, targetMin: 20, targetMax: 40, weightLb: 0, suggestIncrease: false },
  ],
};
const doing = (exerciseIndex, setIndex) => ({ type: 'doingSet', position: { exerciseIndex, setIndex } });
const resting = (exerciseIndex, setIndex) => ({ type: 'resting', position: { exerciseIndex, setIndex } });
const FINISHED = { type: 'finished' };

test('从第一个动作的第一组开始', () => {
  const flow = new WorkoutFlow(workout, 90);
  assert.deepEqual(flow.phase, doing(0, 0));
  assert.equal(flow.current.exerciseId, 'Leg_Press');
  assert.equal(flow.defaultValue(), 12);
  assert.equal(flow.defaultWeight(), 100);
  assert.equal(flow.totalSets, 6);
  assert.deepEqual(flow.completedSets, []);
});

test('没有动作直接结束', () => {
  const flow = new WorkoutFlow({ templateId: 'A', exercises: [] }, 90);
  assert.deepEqual(flow.phase, FINISHED);
  assert.equal(flow.current, null);
  assert.equal(flow.position, null);
});

test('完成一组进入休息，休息完做下一组', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(10, 100);
  assert.deepEqual(flow.phase, resting(0, 1));
  assert.equal(flow.current.exerciseId, 'Leg_Press');
  flow.finishRest();
  assert.deepEqual(flow.phase, doing(0, 1));
  assert.deepEqual(flow.completedSets, [{ exerciseId: 'Leg_Press', setIndex: 0, value: 10, weightLb: 100 }]);
});

test('完整走一遍', () => {
  const flow = new WorkoutFlow(workout, 90);
  let rests = 0;
  for (let guard = 0; flow.phase.type !== 'finished' && guard < 100; guard++) {
    if (flow.phase.type === 'doingSet') flow.completeSet(flow.defaultValue(), flow.defaultWeight() ?? 50);
    else { rests++; flow.finishRest(); }
  }
  assert.deepEqual(flow.phase, FINISHED);
  assert.equal(flow.completedSets.length, 6);
  assert.equal(rests, 5);
  assert.deepEqual(flow.completedSets.map(s => s.exerciseId), [
    'Leg_Press', 'Leg_Press', 'Leg_Press', 'Leverage_Chest_Press', 'Leverage_Chest_Press', 'Plank',
  ]);
  assert.deepEqual(flow.completedSets.map(s => s.setIndex), [0, 1, 2, 0, 1, 0]);
});

test('换动作前的休息指向下一个动作', () => {
  const flow = new WorkoutFlow(workout, 90);
  for (let i = 0; i < 3; i++) {
    flow.completeSet(12, 100);
    flow.finishRest();
  }
  assert.deepEqual(flow.phase, doing(1, 0));
  assert.equal(flow.current.exerciseId, 'Leverage_Chest_Press');
});

test('改过的重量带到同一个动作的下一组', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(12, 90);
  flow.finishRest();
  assert.equal(flow.defaultWeight(), 90);
});

test('第一次做的动作，填之前没有默认重量', () => {
  const flow = new WorkoutFlow(workout, 90);
  for (let i = 0; i < 3; i++) {
    flow.completeSet(12, 100);
    flow.finishRest();
  }
  assert.equal(flow.defaultWeight(), null);
  flow.completeSet(10, 40);
  flow.finishRest();
  assert.equal(flow.defaultWeight(), 40);
});

test('最后一组做完直接结束，不休息', () => {
  const single = { templateId: 'B', exercises: [{ exerciseId: 'Crunches', sets: 1, targetMin: 8, targetMax: 12, weightLb: 0, suggestIncrease: false }] };
  const flow = new WorkoutFlow(single, 90);
  flow.completeSet(12, 0);
  assert.deepEqual(flow.phase, FINISHED);
});

test('提前结束保留已完成的组', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(12, 100);
  flow.endEarly();
  assert.deepEqual(flow.phase, FINISHED);
  assert.equal(flow.completedSets.length, 1);
});

test('在不对的阶段调用会被忽略', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.finishRest();
  assert.deepEqual(flow.phase, doing(0, 0));
  flow.completeSet(12, 100);
  flow.completeSet(12, 100);
  assert.equal(flow.completedSets.length, 1);
  flow.endEarly();
  flow.completeSet(12, 100);
  assert.equal(flow.completedSets.length, 1);
});

test('存成 JSON 再读回来，能接着练', () => {
  const flow = new WorkoutFlow(workout, 90);
  flow.completeSet(12, 90);
  const restored = WorkoutFlow.fromJSON(JSON.parse(JSON.stringify(flow)));
  assert.deepEqual(restored.phase, resting(0, 1));
  assert.deepEqual(restored.completedSets, flow.completedSets);
  assert.equal(restored.restSeconds, 90);
  restored.finishRest();
  assert.equal(restored.defaultWeight(), 90);
});
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `node --test web/test/flow.test.js`
Expected: FAIL，`Cannot find module .../web/js/flow.js`

- [ ] **Step 3: 实现 `web/js/flow.js`**

```js
import { totalSets } from './plan.js';

/**
 * 一次训练的流程：做组 → 休息 → 下一组 → 下一个动作 → 结束。
 * 页面只负责显示 phase 和调用这里的方法。可以存成 JSON，练到一半关掉也能接着练。
 */
export class WorkoutFlow {
  constructor(workout, restSeconds, saved = null) {
    this.workout = workout;
    this.restSeconds = restSeconds;
    this.phase = saved?.phase ?? firstPhase(workout);
    this.completedSets = saved?.completedSets ?? [];
    /** 本次训练里每个动作最后一次实际用的重量 */
    this.usedWeights = saved?.usedWeights ?? {};
  }

  static fromJSON(saved) {
    return new WorkoutFlow(saved.workout, saved.restSeconds, saved);
  }

  toJSON() {
    return {
      workout: this.workout,
      restSeconds: this.restSeconds,
      phase: this.phase,
      completedSets: this.completedSets,
      usedWeights: this.usedWeights,
    };
  }

  get totalSets() {
    return totalSets(this.workout);
  }

  /** 正在做的组，或休息完要做的组 */
  get position() {
    return this.phase.type === 'finished' ? null : this.phase.position;
  }

  get current() {
    const p = this.position;
    return p ? this.workout.exercises[p.exerciseIndex] : null;
  }

  /** 预填的次数（或秒数） */
  defaultValue() {
    return this.current?.targetMax ?? 0;
  }

  /** 预填的重量：本次训练里这个动作上一组的重量，没有就用目标重量。null 表示要用户填 */
  defaultWeight() {
    const c = this.current;
    if (!c) return null;
    return this.usedWeights[c.exerciseId] ?? c.weightLb;
  }

  completeSet(value, weightLb) {
    if (this.phase.type !== 'doingSet') return;
    const { position } = this.phase;
    const c = this.current;
    this.completedSets.push({ exerciseId: c.exerciseId, setIndex: position.setIndex, value, weightLb });
    this.usedWeights[c.exerciseId] = weightLb;
    const next = this.#nextPosition(position);
    this.phase = next ? { type: 'resting', position: next } : { type: 'finished' };
  }

  /** 休息倒计时结束或跳过休息 */
  finishRest() {
    if (this.phase.type === 'resting') this.phase = { type: 'doingSet', position: this.phase.position };
  }

  endEarly() {
    this.phase = { type: 'finished' };
  }

  #nextPosition({ exerciseIndex, setIndex }) {
    if (setIndex + 1 < this.workout.exercises[exerciseIndex].sets) return { exerciseIndex, setIndex: setIndex + 1 };
    const next = this.workout.exercises.findIndex((e, i) => i > exerciseIndex && e.sets > 0);
    return next >= 0 ? { exerciseIndex: next, setIndex: 0 } : null;
  }
}

function firstPhase(workout) {
  const i = workout.exercises.findIndex(e => e.sets > 0);
  return i >= 0 ? { type: 'doingSet', position: { exerciseIndex: i, setIndex: 0 } } : { type: 'finished' };
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `node --test web/test/*.test.js`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add web/js/flow.js web/test/flow.test.js
git commit -m "Port workout flow to web"
```

---

### Task 4: 记录合并和本地存储（merge.js、store.js）

**Files:**
- Create: `web/js/merge.js`
- Create: `web/js/store.js`
- Test: `web/test/merge.test.js`
- Test: `web/test/store.test.js`

**Interfaces:**
- Produces:
  - `merge.js`：`mergeWorkouts(...lists) -> workouts`（按 `id` 去重；同一个 `id` 只要有一份 `deleted` 为真就算已删除；按 `date` 升序）；`sameWorkouts(a, b) -> boolean`
  - `store.js`：`memoryStorage()`（和 localStorage 一样的 `getItem/setItem/removeItem`，存在内存里）；`createStore(storage)` 返回：
    - `loadWorkouts()`、`saveWorkouts(list)`、`visibleWorkouts()`（去掉已删除的）、`addWorkout(workout)`（按 id 合并，重复添加只留一条）、`markDeleted(id)`
    - `loadSession()`、`saveSession(session)`、`clearSession()`：进行中的训练
    - `loadSettings() -> { token, repo }`（默认 `{ token: '', repo: 'ym820/fitness-data' }`）、`saveSettings(s)`
    - `loadSyncStatus() -> { lastSuccessAt, error }`（默认都是 `null`）、`saveSyncStatus(s)`

- [ ] **Step 1: 写失败的测试**

`web/test/merge.test.js`：

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { mergeWorkouts, sameWorkouts } from '../js/merge.js';

const w = (id, day, extra = {}) => ({
  id, date: new Date(day * 86_400_000).toISOString(), durationSeconds: 1200, templateId: 'A', sets: [], deleted: false, ...extra,
});

test('两边的记录都保留，按日期排序', () => {
  const merged = mergeWorkouts([w('b', 2)], [w('a', 1), w('c', 3)]);
  assert.deepEqual(merged.map(x => x.id), ['a', 'b', 'c']);
});

test('同一条记录只留一份', () => {
  assert.equal(mergeWorkouts([w('a', 1)], [w('a', 1)]).length, 1);
});

test('任何一边标了已删除，就算已删除', () => {
  assert.equal(mergeWorkouts([w('a', 1)], [w('a', 1, { deleted: true })])[0].deleted, true);
  assert.equal(mergeWorkouts([w('a', 1, { deleted: true })], [w('a', 1)])[0].deleted, true);
});

test('缺少 deleted 字段当作没删除', () => {
  const { deleted, ...noFlag } = w('a', 1);
  assert.equal(mergeWorkouts([noFlag])[0].deleted, false);
});

test('同步期间新增的记录不会丢', () => {
  const beforeSync = [w('a', 1)];
  const syncResult = mergeWorkouts(beforeSync, [w('remote', 2)]);
  const localNow = [...beforeSync, w('new', 3)];
  assert.deepEqual(mergeWorkouts(localNow, syncResult).map(x => x.id), ['a', 'remote', 'new']);
});

test('内容相同（顺序不同）算相同', () => {
  assert.equal(sameWorkouts([w('a', 1), w('b', 2)], [w('b', 2), w('a', 1)]), true);
  assert.equal(sameWorkouts([w('a', 1)], [w('a', 1), w('b', 2)]), false);
  assert.equal(sameWorkouts([w('a', 1)], [w('a', 1, { deleted: true })]), false);
});
```

`web/test/store.test.js`：

```js
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
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `node --test web/test/merge.test.js web/test/store.test.js`
Expected: FAIL，`Cannot find module .../web/js/merge.js`

- [ ] **Step 3: 实现 `web/js/merge.js`**

```js
/**
 * 按 id 合并训练记录：两边都保留；同一个 id 只要有一份标了已删除就算已删除；按日期排序。
 * 删除只做标记，否则下次同步会被另一边的旧记录带回来。
 */
export function mergeWorkouts(...lists) {
  const byId = new Map();
  for (const w of lists.flat()) {
    const prev = byId.get(w.id);
    byId.set(w.id, { ...(prev ?? w), deleted: Boolean(prev?.deleted || w.deleted) });
  }
  return [...byId.values()].sort(
    (a, b) => Date.parse(a.date) - Date.parse(b.date) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  );
}

export const sameWorkouts = (a, b) => JSON.stringify(mergeWorkouts(a)) === JSON.stringify(mergeWorkouts(b));
```

- [ ] **Step 4: 实现 `web/js/store.js`**

```js
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
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `node --test web/test/*.test.js`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add web/js/merge.js web/js/store.js web/test/merge.test.js web/test/store.test.js
git commit -m "Add workout merge and local storage for web"
```

---

### Task 5: GitHub 同步（sync.js）

**Files:**
- Create: `web/js/sync.js`
- Test: `web/test/sync.test.js`

**Interfaces:**
- Consumes: `mergeWorkouts`、`sameWorkouts` from `merge.js`
- Produces:
  - `class SyncError extends Error`（`message` 是给用户看的中文）
  - `syncWorkouts({ token, repo, local, fetchFn = fetch }) -> Promise<workouts>`：读 `repo` 里的 `workouts.json`，和 `local` 合并，有变化就写回，返回合并后的列表。`repo` 格式是 `用户名/仓库名`
  - `encodeBase64(text)`、`decodeBase64(b64)`：UTF-8 安全
  - 仓库里的文件格式：`{ "version": 1, "workouts": [...] }`，两格缩进，末尾换行

- [ ] **Step 1: 写失败的测试**

`web/test/sync.test.js`：

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { decodeBase64, encodeBase64, SyncError, syncWorkouts } from '../js/sync.js';

const w = (id, day, extra = {}) => ({
  id, date: new Date(day * 86_400_000).toISOString(), durationSeconds: 60, templateId: 'A', sets: [], deleted: false, ...extra,
});
const fileText = workouts => JSON.stringify({ version: 1, workouts }, null, 2) + '\n';

/** 假的 GitHub Contents API：一个文件，PUT 时检查 sha */
function fakeGitHub({ text = null, status = null } = {}) {
  const state = { file: text === null ? null : { text, sha: 'sha0' }, puts: [], beforePut: null };
  const fetchFn = async (url, init = {}) => {
    assert.equal(url, 'https://api.github.com/repos/me/data/contents/workouts.json');
    assert.equal(init.headers.Authorization, 'Bearer tok');
    if (status) return new Response('{}', { status });
    if ((init.method ?? 'GET') === 'GET') {
      return state.file
        ? Response.json({ content: encodeBase64(state.file.text), sha: state.file.sha })
        : new Response('{"message":"Not Found"}', { status: 404 });
    }
    const body = JSON.parse(init.body);
    state.puts.push(body);
    if (state.beforePut) {
      const change = state.beforePut;
      state.beforePut = null;
      change(state);
    }
    if (state.file?.sha !== body.sha) return new Response('{}', { status: 409 });
    state.file = { text: decodeBase64(body.content), sha: `sha${state.puts.length}` };
    return Response.json({ content: { sha: state.file.sha } }, { status: 200 });
  };
  return { state, fetchFn, remote: () => JSON.parse(state.file.text).workouts };
}

const run = (gh, local) => syncWorkouts({ token: 'tok', repo: 'me/data', local, fetchFn: gh.fetchFn });

test('base64 支持中文', () => {
  assert.equal(decodeBase64(encodeBase64('训练 A ✓')), '训练 A ✓');
  assert.equal(decodeBase64(encodeBase64('训练').replace(/(.{4})/g, '$1\n')), '训练');
});

test('GitHub 上还没有文件：用本地记录新建', async () => {
  const gh = fakeGitHub();
  const merged = await run(gh, [w('a', 1)]);
  assert.deepEqual(merged.map(x => x.id), ['a']);
  assert.equal(gh.state.puts.length, 1);
  assert.equal(gh.state.puts[0].sha, undefined);
  assert.deepEqual(gh.remote().map(x => x.id), ['a']);
  assert.equal(gh.state.file.text, fileText(merged));
});

test('两边各有新记录：合并后写回', async () => {
  const gh = fakeGitHub({ text: fileText([w('remote', 2)]) });
  const merged = await run(gh, [w('local', 1)]);
  assert.deepEqual(merged.map(x => x.id), ['local', 'remote']);
  assert.deepEqual(gh.remote().map(x => x.id), ['local', 'remote']);
  assert.equal(gh.state.puts[0].sha, 'sha0');
});

test('没有变化：不上传', async () => {
  const gh = fakeGitHub({ text: fileText([w('a', 1)]) });
  await run(gh, [w('a', 1)]);
  assert.equal(gh.state.puts.length, 0);
});

test('换手机：本地是空的，拉回全部记录', async () => {
  const gh = fakeGitHub({ text: fileText([w('a', 1), w('b', 2)]) });
  const merged = await run(gh, []);
  assert.deepEqual(merged.map(x => x.id), ['a', 'b']);
  assert.equal(gh.state.puts.length, 0);
});

test('上传时文件刚被别处改过：重新下载合并再上传', async () => {
  const gh = fakeGitHub({ text: fileText([w('a', 1)]) });
  gh.state.beforePut = state => { state.file = { text: fileText([w('a', 1), w('other', 3)]), sha: 'shaX' }; };
  const merged = await run(gh, [w('local', 2)]);
  assert.deepEqual(merged.map(x => x.id), ['a', 'local', 'other']);
  assert.deepEqual(gh.remote().map(x => x.id), ['a', 'local', 'other']);
  assert.equal(gh.state.puts.length, 2);
});

test('GitHub 上的文件坏了：报错，不覆盖', async () => {
  for (const text of ['不是 JSON', '{"workouts": "x"}', '{"workouts": [{"id": 1}]}']) {
    const gh = fakeGitHub({ text });
    await assert.rejects(run(gh, [w('a', 1)]), e => e instanceof SyncError && e.message.includes('格式不对'));
    assert.equal(gh.state.puts.length, 0);
  }
});

test('令牌无效、没权限、找不到仓库：给出对应提示', async () => {
  const cases = [[401, '令牌无效'], [403, '没有这个仓库的写入权限'], [500, '500']];
  for (const [status, text] of cases) {
    await assert.rejects(run(fakeGitHub({ status }), []), e => e instanceof SyncError && e.message.includes(text));
  }
});

test('仓库不存在：GET 和 PUT 都是 404', async () => {
  const fetchFn = async () => new Response('{}', { status: 404 });
  await assert.rejects(
    syncWorkouts({ token: 'tok', repo: 'me/data', local: [], fetchFn }),
    e => e instanceof SyncError && e.message.includes('找不到仓库'),
  );
});

test('没网：给出网络提示', async () => {
  const fetchFn = async () => { throw new TypeError('Failed to fetch'); };
  await assert.rejects(
    syncWorkouts({ token: 'tok', repo: 'me/data', local: [], fetchFn }),
    e => e instanceof SyncError && e.message.includes('网络'),
  );
});
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `node --test web/test/sync.test.js`
Expected: FAIL，`Cannot find module .../web/js/sync.js`

- [ ] **Step 3: 实现 `web/js/sync.js`**

```js
import { mergeWorkouts, sameWorkouts } from './merge.js';

const FILE = 'workouts.json';

export class SyncError extends Error {}

export function encodeBase64(text) {
  const bytes = new TextEncoder().encode(text);
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

/** GitHub 返回的 base64 每 60 个字符有一个换行 */
export function decodeBase64(b64) {
  const binary = atob(b64.replace(/\s/g, ''));
  return new TextDecoder().decode(Uint8Array.from(binary, c => c.charCodeAt(0)));
}

/**
 * 读 GitHub 上的 workouts.json，和本地合并，有变化就写回。返回合并后的记录。
 * ponytail: Contents API 只返回 1 MB 以内文件的内容，大约够存几年的记录；超过后会报「格式不对」，那时改用 Git Blobs API。
 */
export async function syncWorkouts({ token, repo, local, fetchFn = globalThis.fetch }) {
  const url = `https://api.github.com/repos/${repo}/contents/${FILE}`;
  const call = async (init = {}) => {
    try {
      return await fetchFn(url, {
        cache: 'no-store',
        ...init,
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          ...init.headers,
        },
      });
    } catch {
      throw new SyncError('网络连接失败，下次打开时会重试');
    }
  };

  for (let attempt = 0; ; attempt++) {
    const got = await call();
    let remote = [];
    let sha;
    if (got.status === 200) {
      const body = await got.json();
      sha = body.sha;
      remote = parseRemote(body.content);
    } else if (got.status !== 404) {
      throw errorFor(got.status);
    }

    const merged = mergeWorkouts(local, remote);
    if (sha && sameWorkouts(merged, remote)) return merged;

    const put = await call({
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: `Sync ${merged.length} workouts`,
        content: encodeBase64(JSON.stringify({ version: 1, workouts: merged }, null, 2) + '\n'),
        ...(sha && { sha }),
      }),
    });
    if (put.ok) return merged;
    // 409/422：下载之后文件又被别处改过，重来一次
    if ((put.status === 409 || put.status === 422) && attempt === 0) continue;
    throw errorFor(put.status);
  }
}

function parseRemote(content) {
  const bad = () => new SyncError('GitHub 上的 workouts.json 格式不对，没有覆盖它，请检查这个文件');
  let data;
  try {
    data = JSON.parse(decodeBase64(content ?? ''));
  } catch {
    throw bad();
  }
  const ok = Array.isArray(data?.workouts) && data.workouts.every(
    w => typeof w?.id === 'string' && typeof w?.date === 'string' && Array.isArray(w?.sets),
  );
  if (!ok) throw bad();
  return data.workouts;
}

function errorFor(status) {
  if (status === 401) return new SyncError('令牌无效或已过期，请在设置里重新填写');
  if (status === 403) return new SyncError('令牌没有这个仓库的写入权限');
  if (status === 404) return new SyncError('找不到仓库，或令牌没有这个仓库的权限');
  return new SyncError(`同步失败（GitHub 返回 ${status}）`);
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `node --test web/test/*.test.js`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add web/js/sync.js web/test/sync.test.js
git commit -m "Add GitHub sync for web workouts"
```

---

### Task 6: 页面骨架、样式和今天页

界面任务在动手前先加载 `apple-design` 和 `emil-design-eng` 两个 skill，按下面的代码实现后，再对照两个 skill 检查一遍（按压反馈、过渡曲线、减弱动态效果、字体和间距），只做小调整，不改结构。

**Files:**
- Create: `web/index.html`
- Create: `web/app.css`
- Create: `web/js/app.js`
- Create: `web/js/views/common.js`
- Create: `web/js/views/today.js`
- Create: `web/js/views/workout.js`（这一步只放 `startSession`，Task 9 补全）

**Interfaces:**
- Consumes: `loadCatalog`（catalog.js）、`createStore`/`memoryStorage`（store.js）、`mergeWorkouts`（merge.js）、`syncWorkouts`（sync.js）、`nextWorkout`/`totalSets`/`estimatedDurationSeconds`（plan.js）、`WorkoutFlow`（flow.js）、`html`（dom.js）
- Produces:
  - `app` 对象（传给每个页面）：`{ catalog, store, navigate(hash), refresh(), sync() -> Promise, syncing: boolean }`
  - 页面函数签名：`view(app, ...路由参数) -> { html, mount?(root) -> cleanup? }`。`html` 是 `html``...`` 的结果；`mount` 在插入页面后调用，返回的函数在离开页面时调用
  - `common.js`：`art(name)`、`thumb(exercise)`、`tag(text, 'green'|'orange')`、`templateName(catalog, id)`
  - `workout.js`：`startSession(workout, restSeconds) -> { id, flow, startedAt, restEndsAt: null, draft: null }`

- [ ] **Step 1: `web/index.html`**

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="theme-color" content="#f2f2f7" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-title" content="健身">
  <link rel="apple-touch-icon" href="icon.png">
  <title>健身</title>
  <link rel="stylesheet" href="app.css">
  <script type="module" src="js/app.js"></script>
</head>
<body>
  <div id="banner" class="banner" hidden>当前无法保存记录（可能是无痕模式），关掉页面后记录会丢失</div>
  <main id="app"></main>
  <nav class="tabbar">
    <a href="#/today" data-tab="today">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 7v10M3 9.5v5M18 7v10M21 9.5v5M6 12h12"/></svg>
      今天
    </a>
    <a href="#/library" data-tab="library">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M4 4h4v16H4zM10 4h4v16h-4zM16.5 4.5l3-.5 2.5 15.5-3 .5z"/></svg>
      动作库
    </a>
    <a href="#/history" data-tab="history">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>
      历史
    </a>
  </nav>
</body>
</html>
```

- [ ] **Step 2: `web/app.css`**

```css
:root {
  color-scheme: light dark;
  --bg: #f2f2f7;
  --card: #fff;
  --text: #000;
  --secondary: #6c6c70;
  --separator: rgba(60, 60, 67, 0.18);
  --fill: #e9e9ee;
  --accent: #1f9d55;
  --accent-soft: rgba(52, 199, 89, 0.15);
  --on-accent: #fff;
  --orange: #c25e00;
  --orange-soft: rgba(255, 149, 0, 0.15);
  --red: #d70015;
  --radius: 12px;
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --safe-top: env(safe-area-inset-top);
  --safe-bottom: env(safe-area-inset-bottom);
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #000;
    --card: #1c1c1e;
    --text: #fff;
    --secondary: #98989f;
    --separator: rgba(84, 84, 88, 0.6);
    --fill: #2c2c2e;
    --accent: #30d158;
    --accent-soft: rgba(48, 209, 88, 0.18);
    --on-accent: #000;
    --orange: #ff9f0a;
    --orange-soft: rgba(255, 159, 10, 0.18);
    --red: #ff453a;
  }
}

* { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
html { -webkit-text-size-adjust: 100%; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font: 17px/1.35 -apple-system, BlinkMacSystemFont, "PingFang SC", system-ui, sans-serif;
}
main {
  max-width: 640px;
  margin: 0 auto;
  padding: calc(var(--safe-top) + 12px) 16px calc(96px + var(--safe-bottom));
}
a { color: var(--accent); text-decoration: none; }
button { font: inherit; cursor: pointer; }

.secondary { color: var(--secondary); }
.footnote { font-size: 13px; }
.num { font-variant-numeric: tabular-nums; }
.large-title { font-size: 34px; font-weight: 700; letter-spacing: 0.01em; margin: 8px 0 12px; }
.title { font-size: 28px; font-weight: 700; margin: 16px 0 2px; }
.subtitle { font-size: 20px; margin: 0 0 8px; }
.section-header { font-size: 13px; font-weight: 400; color: var(--secondary); margin: 24px 16px 6px; }
.section-footer { font-size: 13px; color: var(--secondary); margin: 6px 16px 0; }
.section-footer.error { color: var(--red); }
.empty { text-align: center; color: var(--secondary); padding: 48px 16px; }
.empty strong { display: block; color: var(--text); margin-bottom: 4px; }

.banner {
  position: sticky; top: 0; z-index: 10;
  padding: calc(var(--safe-top) + 8px) 16px 8px;
  background: var(--orange-soft); color: var(--orange);
  font-size: 13px; text-align: center;
}

.card { background: var(--card); border-radius: var(--radius); padding: 16px; }
.hero h2 { font-size: 34px; margin: 2px 0 6px; }
.hero p { margin: 0 0 4px; }

.list { list-style: none; margin: 0; padding: 0; background: var(--card); border-radius: var(--radius); overflow: hidden; }
.list > li + li { border-top: 0.5px solid var(--separator); }
.row { display: flex; gap: 12px; align-items: center; padding: 10px 16px; color: inherit; transition: background-color 0.15s; }
.row:active { background: var(--fill); }
.row-text { display: flex; flex-direction: column; gap: 1px; min-width: 0; flex: 1; }
.row-text strong { font-weight: 600; }
.row-meta { display: flex; justify-content: space-between; gap: 8px; font-size: 15px; }
.pair { display: flex; justify-content: space-between; gap: 12px; padding: 11px 16px; }

/* 示范图是白色线条的 SVG：浅色模式反色成黑线，深色模式保持白线 */
.art { filter: invert(1); }
@media (prefers-color-scheme: dark) { .art { filter: none; } }
.thumb { flex: none; width: 56px; height: 56px; padding: 3px; border-radius: 10px; background: var(--bg); display: grid; place-items: center; }
.thumb .art { width: 100%; height: 100%; object-fit: contain; }

.tag { display: inline-block; margin-left: 4px; padding: 2px 6px; border-radius: 999px; font-size: 11px; font-weight: 600; }
.tag.green { color: var(--accent); background: var(--accent-soft); }
.tag.orange { color: var(--orange); background: var(--orange-soft); }

.button {
  display: block; width: 100%; min-height: 50px; padding: 14px;
  border: 0; border-radius: var(--radius);
  background: var(--fill); color: var(--accent);
  font-weight: 600; text-align: center;
  transition: transform 0.15s var(--ease-out), opacity 0.15s;
}
.button:active { transform: scale(0.97); }
.button.primary { background: var(--accent); color: var(--on-accent); }
.button.destructive { color: var(--red); margin-top: 24px; }
.button:disabled { opacity: 0.4; }
.button:disabled:active { transform: none; }
.link { background: none; border: 0; padding: 8px 0; color: var(--accent); }
.stack { display: grid; gap: 10px; margin-top: 20px; }
.bottom-action { position: sticky; bottom: calc(72px + var(--safe-bottom)); margin-top: 20px; }

.navbar { display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; min-height: 44px; margin-bottom: 8px; font-weight: 600; }
.navbar .back { justify-self: start; background: none; border: 0; padding: 8px 0; color: var(--accent); font-weight: 400; }
.page-header { display: flex; justify-content: space-between; align-items: baseline; }

.search { width: 100%; margin-bottom: 4px; padding: 9px 12px; border: 0; border-radius: 10px; background: var(--fill); color: var(--text); font: inherit; }

.demo { display: flex; align-items: center; gap: 4px; height: 244px; padding: 12px; background: var(--card); border-radius: var(--radius); }
.demo .art { flex: 1; min-width: 0; height: 100%; object-fit: contain; }
.demo.wide { flex-direction: column; height: auto; }
.demo.wide .art { width: 100%; height: auto; max-height: 150px; }
.demo-arrow { color: var(--secondary); font-size: 13px; }
.demo.wide .demo-arrow { transform: rotate(90deg); }
.info { display: grid; grid-template-columns: 80px 1fr; gap: 10px 8px; margin: 20px 0 0; }
.info dt { color: var(--secondary); }
.info dd { margin: 0; display: flex; flex-direction: column; }
.tips { list-style: none; margin: 0; padding: 0; counter-reset: tip; display: grid; gap: 12px; }
.tips li { counter-increment: tip; display: flex; gap: 10px; align-items: flex-start; }
.tips li::before {
  content: counter(tip); flex: none; width: 24px; height: 24px; border-radius: 50%;
  display: grid; place-items: center; font-size: 15px; font-weight: 700;
  color: var(--accent); background: var(--accent-soft);
}

.videos { display: flex; gap: 12px; overflow-x: auto; scroll-snap-type: x mandatory; padding-bottom: 4px; }
.video { flex: 0 0 220px; scroll-snap-align: start; display: flex; flex-direction: column; gap: 2px; color: inherit; transition: transform 0.15s var(--ease-out); }
.video:active { transform: scale(0.97); }
.video-thumb { position: relative; aspect-ratio: 16 / 9; border-radius: 10px; overflow: hidden; background: var(--fill); }
.video-thumb img { width: 100%; height: 100%; object-fit: cover; }
.badge { position: absolute; top: 6px; left: 6px; padding: 1px 6px; border-radius: 4px; color: #fff; font-size: 11px; font-weight: 600; }
.badge.bilibili { background: #00a1d6; }
.badge.youtube { background: #e62117; }
.video-duration { position: absolute; right: 6px; bottom: 6px; padding: 1px 5px; border-radius: 4px; background: rgba(0, 0, 0, 0.6); color: #fff; font-size: 12px; font-variant-numeric: tabular-nums; }
.video-title { font-size: 15px; line-height: 1.3; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }

.field { display: flex; align-items: center; gap: 12px; padding: 6px 16px; }
.field > span { width: 48px; flex: none; }
.field input { flex: 1; min-width: 0; padding: 8px 0; border: 0; background: none; color: var(--text); font: inherit; }

body.in-workout .tabbar { display: none; }
body.in-workout main { padding-bottom: calc(24px + var(--safe-bottom)); }
body.in-workout .bottom-action { bottom: calc(16px + var(--safe-bottom)); }
.workout-header { display: flex; justify-content: space-between; align-items: center; font-size: 15px; }
progress { display: block; width: 100%; height: 4px; margin: 6px 0 16px; border: 0; border-radius: 2px; overflow: hidden; background: var(--fill); appearance: none; -webkit-appearance: none; }
progress::-webkit-progress-bar { background: var(--fill); }
progress::-webkit-progress-value { background: var(--accent); }
progress::-moz-progress-bar { background: var(--accent); }
.set-card { padding: 16px 16px 8px; background: var(--card); border-radius: var(--radius); }
.set-card .title { margin-top: 0; }
.set-count { margin: 12px 0 2px; font-size: 20px; font-weight: 600; }
.stepper { display: grid; grid-template-columns: 1fr 44px 88px 24px 44px; align-items: center; gap: 8px; margin-top: 12px; padding: 12px 16px; background: var(--card); border-radius: var(--radius); }
.stepper input { width: 100%; padding: 6px 0; border: 0; border-radius: 10px; background: var(--fill); color: var(--text); font: inherit; font-size: 28px; font-weight: 600; font-variant-numeric: tabular-nums; text-align: center; }
.round { width: 44px; height: 44px; border: 0; border-radius: 50%; background: var(--accent-soft); color: var(--accent); font-size: 24px; font-weight: 600; transition: transform 0.15s var(--ease-out); }
.round:active { transform: scale(0.9); }
.hint { margin: 8px 16px 0; color: var(--orange); font-size: 13px; }
.rest { padding-top: 40px; text-align: center; }
.countdown { margin: 8px 0 16px; font-size: 96px; font-weight: 700; letter-spacing: -0.02em; font-variant-numeric: tabular-nums; }
.row-buttons { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 32px; }
.done { padding-top: 32px; text-align: center; }
.done .list { margin: 24px 0 8px; text-align: left; }
.done .button { margin-top: 24px; }
.done-mark { width: 72px; height: 72px; margin: 0 auto; border-radius: 50%; display: grid; place-items: center; background: var(--accent-soft); color: var(--accent); font-size: 36px; font-weight: 700; animation: pop 0.4s var(--ease-out); }
@keyframes pop { from { transform: scale(0.6); opacity: 0; } }

.tabbar {
  position: fixed; left: 0; right: 0; bottom: 0;
  display: flex; justify-content: space-around;
  padding: 6px 0 calc(6px + var(--safe-bottom));
  background: color-mix(in srgb, var(--card) 80%, transparent);
  -webkit-backdrop-filter: saturate(180%) blur(20px);
  backdrop-filter: saturate(180%) blur(20px);
  border-top: 0.5px solid var(--separator);
}
.tabbar a { display: flex; flex-direction: column; align-items: center; gap: 2px; min-width: 64px; padding: 2px; color: var(--secondary); font-size: 10px; font-weight: 500; }
.tabbar a.active { color: var(--accent); }
.tabbar svg { width: 26px; height: 26px; }

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { transition: none !important; animation: none !important; }
  .button:active, .video:active, .round:active { transform: none; }
}
```

- [ ] **Step 3: `web/js/views/common.js`**

```js
import { html } from '../dom.js';

export const art = name => html`<img class="art" src="img/${name}.svg" alt="">`;

/** 缩略图用结束姿势：多数动作的结束姿势最有辨识度（比如推起、拉到底） */
export const thumb = exercise => html`<span class="thumb">${art(exercise.images.at(-1))}</span>`;

export const tag = (text, color) => html`<span class="tag ${color}">${text}</span>`;

export const templateName = (catalog, id) => catalog.template(id)?.nameZh ?? id;
```

- [ ] **Step 4: `web/js/views/workout.js`（先只放 `startSession`）**

```js
import { WorkoutFlow } from '../flow.js';

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
```

- [ ] **Step 5: `web/js/views/today.js`**

```js
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
```

- [ ] **Step 6: `web/js/app.js`**

```js
import { html } from './dom.js';
import { loadCatalog } from './catalog.js';
import { createStore, memoryStorage } from './store.js';
import { mergeWorkouts } from './merge.js';
import { syncWorkouts } from './sync.js';
import { todayView } from './views/today.js';

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
```

- [ ] **Step 7: 本地预览，检查今天页**

Run: `scripts/build_web.sh && python3 -m http.server 8000 -d _site`（另开一个终端或后台运行）

在浏览器打开 `http://localhost:8000/`，用手机尺寸（375×812）检查：
- 显示「今天」大标题、卡片里「下次训练 / 训练 A / 5 个动作 · 15 组 · 约 30 分钟 / 第一次训练，点下面的「开始训练」」
- 5 个动作，每个有黑色线条缩略图（深色模式下是白线）、中英文名、`3 × 8-12 次`，负重动作有橙色「首次，开始后填重量」，平板支撑是 `3 × 20-40 秒` 且没有标签
- 「开始训练」按钮在标签栏上方；点了跳回今天页（`#/workout` 还没有页面），按钮变成「继续训练」
- 底部标签栏「今天」高亮
- 控制台没有报错

然后在浏览器控制台运行 `localStorage.clear()` 再刷新，按钮变回「开始训练」。

- [ ] **Step 8: 运行测试，提交**

Run: `node --test web/test/*.test.js`
Expected: PASS

```bash
git add web/index.html web/app.css web/js/app.js web/js/views
git commit -m "Add web app shell and today page"
```

---

### Task 7: 动作库和动作详情

**Files:**
- Create: `web/js/views/library.js`
- Modify: `web/js/app.js`（加 import 和两条路由）

**Interfaces:**
- Consumes: `BODY_PARTS`、`filterExercises`、`watchURL`、`thumbnailURL`（catalog.js）；`art`、`thumb`（common.js）；`F.muscleZh`、`F.duration`
- Produces: `libraryView(app)`、`exerciseView(app, id)`；路由 `#/library`、`#/exercise/<id>`

- [ ] **Step 1: `web/js/views/library.js`**

```js
import { html } from '../dom.js';
import { BODY_PARTS, filterExercises, thumbnailURL, watchURL } from '../catalog.js';
import * as F from '../format.js';
import { art, thumb } from './common.js';

export function libraryView(app) {
  const { catalog } = app;
  return {
    html: html`
      <h1 class="large-title">动作库</h1>
      <input class="search" type="search" placeholder="中文或英文名、器材" data-search>
      <div data-results>${groups(catalog.exercises)}</div>
      <p class="section-footer">动作插图来自 <a href="https://github.com/bryllim/workout-guide" target="_blank" rel="noopener">Workout Guide</a>，作者 Bryl Lim，基于 Everkinetic 的作品，按 <a href="https://creativecommons.org/licenses/by-sa/4.0/" target="_blank" rel="noopener">CC BY-SA 4.0</a> 协议使用。</p>`,
    mount(root) {
      const results = root.querySelector('[data-results]');
      root.querySelector('[data-search]').addEventListener('input', event => {
        const query = event.target.value;
        const list = filterExercises(catalog.exercises, query);
        results.innerHTML = String(list.length ? html`${groups(list)}` : html`<p class="empty">没有找到「${query.trim()}」</p>`);
      });
    },
  };
}

function groups(list) {
  return BODY_PARTS.map(([part, name]) => {
    const items = list.filter(e => e.bodyPart === part);
    return items.length ? html`<h3 class="section-header">${name}</h3><ul class="list">${items.map(row)}</ul>` : '';
  });
}

function row(exercise) {
  return html`<li><a class="row" href="#/exercise/${exercise.id}">
    ${thumb(exercise)}
    <div class="row-text">
      <strong>${exercise.nameZh}</strong>
      <span class="secondary">${exercise.nameEn}</span>
      <span class="footnote secondary">${exercise.equipmentZh}</span>
    </div>
  </a></li>`;
}

export function exerciseView(app, id) {
  const exercise = app.catalog.exercise(id);
  if (!exercise) return { html: html`<p class="empty">找不到这个动作</p>` };
  const videos = app.catalog.videosFor(id);

  return {
    html: html`
      <nav class="navbar"><button class="back" data-action="back">‹ 返回</button><span>${exercise.nameZh}</span></nav>
      <div class="demo" data-demo role="img" aria-label="${exercise.nameZh}示范图">
        ${exercise.images.map((name, i) => html`${i > 0 ? html`<span class="demo-arrow" aria-hidden="true">→</span>` : ''}${art(name)}`)}
      </div>
      <h1 class="title">${exercise.nameZh}</h1>
      <p class="subtitle secondary">${exercise.nameEn}</p>
      ${videos.length ? html`<h3 class="section-header">示范视频</h3><div class="videos">${videos.map(videoCard)}</div>` : ''}
      <dl class="info">
        <dt>器材</dt><dd>${exercise.equipmentZh}<span class="footnote secondary">${exercise.equipmentEn}</span></dd>
        <dt>主要练到</dt><dd>${exercise.primaryMuscles.map(F.muscleZh).join('、')}</dd>
        <dt>计数</dt><dd>${exercise.unit === 'reps' ? '按次数' : '按秒数'}</dd>
      </dl>
      <h3 class="section-header">动作要点</h3>
      <ol class="tips">${exercise.tipsZh.map(tip => html`<li>${tip}</li>`)}</ol>`,
    mount(root) {
      root.querySelector('[data-action=back]').addEventListener('click', () => {
        if (history.length > 1) history.back();
        else app.navigate('#/library');
      });
      // 横向的图（比如腿举）上下排，竖向的图（比如深蹲）左右排，让图尽量大
      const demo = root.querySelector('[data-demo]');
      const first = demo.querySelector('img');
      const layout = () => demo.classList.toggle('wide', first.naturalWidth / first.naturalHeight > 1.2);
      if (first.complete) layout();
      else first.addEventListener('load', layout);
    },
  };
}

/** B 站封面图有防盗链，不带来源（referrer）才能加载 */
function videoCard(video) {
  const cover = thumbnailURL(video);
  return html`<a class="video" href="${watchURL(video)}" target="_blank" rel="noopener">
    <span class="video-thumb">
      ${cover ? html`<img src="${cover}" alt="" loading="lazy" referrerpolicy="no-referrer">` : ''}
      <span class="badge ${video.platform}">${video.platform === 'youtube' ? 'YouTube' : 'bilibili'}</span>
      ${video.durationSeconds ? html`<span class="video-duration">${F.duration(video.durationSeconds)}</span>` : ''}
    </span>
    <span class="video-title">${video.title}</span>
    <span class="footnote secondary">${video.author}</span>
  </a>`;
}
```

- [ ] **Step 2: 在 `web/js/app.js` 注册路由**

把：

```js
import { todayView } from './views/today.js';
```

改成：

```js
import { todayView } from './views/today.js';
import { exerciseView, libraryView } from './views/library.js';
```

把：

```js
  [/^#\/today$/, todayView],
];
```

改成：

```js
  [/^#\/today$/, todayView],
  [/^#\/library$/, libraryView],
  [/^#\/exercise\/([^/]+)$/, exerciseView],
];
```

- [ ] **Step 3: 本地预览检查**

Run: `scripts/build_web.sh`，刷新 `http://localhost:8000/`（手机尺寸）

- 点「动作库」：按「腿和臀 / 胸 / 背 / 肩 / 手臂 / 核心」分组，30 个动作，底部有 CC BY-SA 4.0 说明
- 搜索框输入「leg」只剩含 leg 的动作；输入「哑铃」显示哑铃动作；输入「zzz」显示「没有找到「zzz」」；清空恢复全部
- 点「腿举」：两张示范图上下排（横向图），箭头朝下；点「高脚杯深蹲」：两张图左右排
- 示范视频卡片：有 B 站封面、「bilibili」角标、时长、标题、UP 主；点了在新标签页打开 B 站视频页
- 器材、主要练到、计数、动作要点（带绿色序号）都显示
- 「‹ 返回」回到上一页；从今天页点动作进详情，标签栏高亮「动作库」
- 切到深色模式（浏览器开发者工具里模拟 `prefers-color-scheme: dark`），线条图变白、背景变黑
- 控制台没有报错

- [ ] **Step 4: 提交**

```bash
git add web/js/views/library.js web/js/app.js
git commit -m "Add web exercise library and detail page"
```

---

### Task 8: 历史、训练详情和设置

**Files:**
- Create: `web/js/views/history.js`
- Create: `web/js/views/settings.js`
- Modify: `web/js/app.js`（加 import 和三条路由）

**Interfaces:**
- Consumes: `app.store`（`visibleWorkouts`、`markDeleted`、`loadSettings`、`saveSettings`、`loadSyncStatus`、`saveSyncStatus`）、`app.sync()`、`app.syncing`；`F.groupSets`、`F.setText`、`F.dateTime`、`F.dateLong`、`F.duration`；`templateName`
- Produces: `historyView(app)`、`workoutDetailView(app, id)`、`settingsView(app)`；路由 `#/history`、`#/history/<id>`、`#/settings`

- [ ] **Step 1: `web/js/views/history.js`**

```js
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
```

- [ ] **Step 2: `web/js/views/settings.js`**

```js
import { html } from '../dom.js';
import * as F from '../format.js';

export function settingsView(app) {
  const { store } = app;
  const settings = store.loadSettings();
  const status = store.loadSyncStatus();

  return {
    html: html`
      <nav class="navbar"><a class="back" href="#/history">‹ 历史</a><span>设置</span></nav>
      <h3 class="section-header">GitHub 同步</h3>
      <form data-form>
        <ul class="list">
          <li><label class="field"><span>仓库</span>
            <input name="repo" value="${settings.repo}" placeholder="用户名/仓库名" autocapitalize="off" autocorrect="off" spellcheck="false">
          </label></li>
          <li><label class="field"><span>令牌</span>
            <input name="token" type="password" autocomplete="off" placeholder="${settings.token ? `已保存，末尾 ${settings.token.slice(-4)}` : 'github_pat_…'}">
          </label></li>
        </ul>
        <p class="section-footer">令牌只存在这台手机上。只需要这个仓库的 Contents 读写权限。令牌留空保存会保留原来的令牌。</p>
        <div class="stack"><button class="button primary" type="submit">保存并同步</button></div>
      </form>
      <h3 class="section-header">状态</h3>
      <ul class="list"><li class="pair"><span>同步</span><span class="secondary">${statusText(settings, status, app.syncing)}</span></li></ul>
      ${status.error ? html`<p class="section-footer error">${status.error}</p>` : ''}
      ${settings.token
        ? html`<div class="stack">
            <button class="button" data-action="sync">立即同步</button>
            <button class="button destructive" data-action="clear">清除令牌</button>
          </div>`
        : ''}`,
    mount(root) {
      root.querySelector('[data-form]').addEventListener('submit', event => {
        event.preventDefault();
        const form = new FormData(event.target);
        const token = String(form.get('token')).trim() || store.loadSettings().token;
        store.saveSettings({ repo: String(form.get('repo')).trim(), token });
        store.saveSyncStatus({ lastSuccessAt: null, error: null });
        app.sync();
        app.refresh();
      });
      root.querySelector('[data-action=sync]')?.addEventListener('click', () => {
        app.sync();
        app.refresh();
      });
      root.querySelector('[data-action=clear]')?.addEventListener('click', () => {
        if (!confirm('清除令牌？训练记录还会留在这台手机上。')) return;
        store.saveSettings({ ...store.loadSettings(), token: '' });
        store.saveSyncStatus({ lastSuccessAt: null, error: null });
        app.refresh();
      });
    },
  };
}

function statusText(settings, status, syncing) {
  if (!settings.token) return '未开启同步';
  if (syncing) return '正在同步…';
  return status.lastSuccessAt ? `上次成功：${F.dateTime(status.lastSuccessAt)}` : '还没有同步成功过';
}
```

- [ ] **Step 3: 在 `web/js/app.js` 注册路由**

把：

```js
import { exerciseView, libraryView } from './views/library.js';
```

改成：

```js
import { exerciseView, libraryView } from './views/library.js';
import { historyView, workoutDetailView } from './views/history.js';
import { settingsView } from './views/settings.js';
```

把：

```js
  [/^#\/exercise\/([^/]+)$/, exerciseView],
];
```

改成：

```js
  [/^#\/exercise\/([^/]+)$/, exerciseView],
  [/^#\/history$/, historyView],
  [/^#\/history\/([^/]+)$/, workoutDetailView],
  [/^#\/settings$/, settingsView],
];
```

- [ ] **Step 4: 本地预览检查**

Run: `scripts/build_web.sh`，刷新浏览器。先在控制台塞两条假记录：

```js
localStorage.setItem('fitness.workouts', JSON.stringify([
  { id: 't1', date: '2026-10-08T10:00:00.000Z', durationSeconds: 1800, templateId: 'A', deleted: false,
    sets: [{ exerciseId: 'Leg_Press', setIndex: 0, value: 12, weightLb: 90 }, { exerciseId: 'Plank', setIndex: 0, value: 30, weightLb: 0 }] },
  { id: 't2', date: '2026-10-10T10:00:00.000Z', durationSeconds: 1500, templateId: 'B', deleted: false, sets: [] },
])); location.reload();
```

- 「历史」：训练 B 在上、训练 A 在下，显示日期时间、「2 组 · 30:00」
- 点训练 A：日期、时长；「腿举  Leg Press / 第 1 组 / 12 次 × 90 lb」，「平板支撑  Plank / 第 1 组 / 30 秒」
- 「删除这次训练」→ 确认后回到历史，只剩训练 B；控制台 `JSON.parse(localStorage.getItem('fitness.workouts'))` 里 t1 的 `deleted` 是 `true`
- 今天页：上次是 10 月 10 日训练 B，所以下次是训练 A
- 「设置」：显示「未开启同步」，没有「立即同步」按钮
- 填一个假令牌 `bad` 保存：状态先显示「正在同步…」，然后出现红字「令牌无效或已过期，请在设置里重新填写」；令牌框提示「已保存，末尾 bad」
- 「清除令牌」→ 确认后回到「未开启同步」
- 用浏览器开发者工具把网络设成离线，保存一个令牌：红字「网络连接失败，下次打开时会重试」

- [ ] **Step 5: 提交**

```bash
git add web/js/views/history.js web/js/views/settings.js web/js/app.js
git commit -m "Add web history and sync settings pages"
```

---

### Task 9: 训练流程页面（做组、休息、结束）

**Files:**
- Modify: `web/js/views/workout.js`（在 `startSession` 后面加页面代码）
- Modify: `web/js/app.js`（加 import 和两条路由）

**Interfaces:**
- Consumes: `WorkoutFlow`（flow.js）、`isWeighted`（catalog.js）、`F.parseCount`、`F.parseWeight`、`F.number`、`F.duration`、`F.target`、`F.weight`、`F.unitZh`；`app.store` 的 `loadSession/saveSession/clearSession/addWorkout/visibleWorkouts/loadSettings/loadSyncStatus`
- Produces: `workoutView(app)`、`doneView(app, id)`；路由 `#/workout`、`#/done/<id>`
- session 结构：`{ id, flow: WorkoutFlow JSON, startedAt: ISO, restEndsAt: 毫秒时间戳|null, draft: { value: string, weight: string }|null }`

- [ ] **Step 1: 把 `web/js/views/workout.js` 换成完整版本**

```js
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
  const weightText = draft.weight ?? (defaultWeight === null ? '' : F.number(defaultWeight));

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
            field.value = F.number(Math.max(0, current + step * Number(button.dataset.delta)));
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
```

- [ ] **Step 2: 在 `web/js/app.js` 注册路由**

把：

```js
import { settingsView } from './views/settings.js';
```

改成：

```js
import { settingsView } from './views/settings.js';
import { doneView, workoutView } from './views/workout.js';
```

把：

```js
  [/^#\/settings$/, settingsView],
];
```

改成：

```js
  [/^#\/settings$/, settingsView],
  [/^#\/workout$/, workoutView],
  [/^#\/done\/([^/]+)$/, doneView],
];
```

- [ ] **Step 3: 本地预览，走一遍训练**

Run: `scripts/build_web.sh`，浏览器控制台 `localStorage.clear()` 后刷新（手机尺寸）

- 今天页点「开始训练」：标签栏消失；顶部「训练 A · 第 1 / 15 组」和「结束训练」，进度条为空
- 腿举：「第 1 组 / 共 3 组」「目标 8-12 次」；次数框是 12；重量框空，下面橙色「第一次做这个动作，先填一个重量」；「完成这组」不可点
- 重量点 `+` 变成 10（腿举加重步长 10），按钮可点；次数框改成 `abc` 按钮变灰，改回 `11` 恢复
- 点「完成这组」：进入休息，倒计时从 1:30 开始走，「下一组：腿举 第 2 组」；点「+30 秒」时间加 30 秒
- 刷新页面：仍在休息页，倒计时接着走（没有重置）
- 点「跳过」：腿举第 2 组，次数和重量预填 11 和 10
- 在做组页刷新：输入框保留刚才改的值
- 点「看示范」进腿举详情，「‹ 返回」回到做组页，状态不变
- 点「结束训练」→ 取消：什么都不变；再点 → 确认：进入「训练完成」，时长和「1 组」；没填令牌时显示「记录已保存在这台手机上…」
- 「回到今天」：下次训练变成训练 B，「上次：…训练 A」
- 历史页能看到这次训练
- 再开始一次，什么都不做直接「结束训练」：提示「还没有完成任何一组，不会保存记录」，确认后回今天页，历史没有新增
- 平板支撑（训练 A 最后一个动作）：秒数步长 5，没有重量框

- [ ] **Step 4: 运行测试，提交**

Run: `node --test web/test/*.test.js`
Expected: PASS

```bash
git add web/js/views/workout.js web/js/app.js
git commit -m "Add web workout flow pages"
```

---

### Task 10: 离线和添加到主屏幕（PWA）

**Files:**
- Create: `web/manifest.webmanifest`
- Create: `web/sw.js`
- Modify: `web/index.html`（加 manifest 链接）
- Modify: `web/js/app.js`（注册 Service Worker）

**Interfaces:**
- Consumes: `scripts/build_web.sh` 生成的 `_site/files.json`（站内所有文件的相对路径数组）

- [ ] **Step 1: `web/manifest.webmanifest`**

```json
{
  "name": "健身",
  "short_name": "健身",
  "start_url": "./#/today",
  "scope": "./",
  "display": "standalone",
  "background_color": "#f2f2f7",
  "theme_color": "#f2f2f7",
  "icons": [{ "src": "icon.png", "sizes": "1024x1024", "type": "image/png", "purpose": "any" }]
}
```

- [ ] **Step 2: `web/sw.js`**

```js
// 先用缓存（离线和信号差时也能马上打开），同时在后台更新缓存，下次打开就是新版本。
// 只管本站文件；GitHub API 和 B 站不经过这里。
const CACHE = 'fitness-v1';

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const files = await (await fetch('files.json', { cache: 'no-store' })).json();
    const cache = await caches.open(CACHE);
    await cache.addAll(['./', ...files]);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(event.request, { ignoreSearch: true });
    const network = fetch(event.request)
      .then(response => {
        if (response.ok) cache.put(event.request, response.clone());
        return response;
      })
      .catch(() => cached);
    event.waitUntil(network.then(() => undefined));
    return cached ?? network;
  })());
});
```

- [ ] **Step 3: 在 `web/index.html` 加 manifest**

把：

```html
  <link rel="apple-touch-icon" href="icon.png">
```

改成：

```html
  <link rel="apple-touch-icon" href="icon.png">
  <link rel="manifest" href="manifest.webmanifest">
```

- [ ] **Step 4: 在 `web/js/app.js` 注册 Service Worker**

把：

```js
  render();
  syncNow();
}
```

改成：

```js
  render();
  syncNow();
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
}
```

- [ ] **Step 5: 本地检查离线**

Run: `scripts/build_web.sh`，刷新 `http://localhost:8000/` 两次

- 开发者工具 → Application → Service Workers：`sw.js` 已激活；Cache Storage 里 `fitness-v1` 有 `index.html`、JS、`data/*.json`、`img/*.svg`、`icon.png`
- Manifest 面板显示名字「健身」和图标，没有报错
- Network 设成 Offline 后刷新：页面照常打开；动作库所有示范图都能显示（包括之前没打开过的动作）；能开始训练、完成一组
- 恢复网络

- [ ] **Step 6: 提交**

```bash
git add web/manifest.webmanifest web/sw.js web/index.html web/js/app.js
git commit -m "Make web app installable and work offline"
```

---

### Task 11: 部署到 GitHub Pages 和更新 README

**Files:**
- Create: `.github/workflows/pages.yml`
- Modify: `README.md`

- [ ] **Step 1: `.github/workflows/pages.yml`**

```yaml
name: Deploy web

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: node --test web/test/*.test.js
      - run: python3 scripts/validate_data.py
      - run: scripts/build_web.sh
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: _site
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: 更新 `README.md`**

把开头两行：

```markdown
# 个人健身 app

iPhone + Apple Watch 的新手力量训练 app。设计见 `docs/superpowers/specs/`，实现计划见 `docs/superpowers/plans/`。
```

改成：

````markdown
# 个人健身 app

新手力量训练 app 的网页版，在 iPhone 上添加到主屏幕使用：https://ym820.github.io/personal-fitness-app/

设计见 `docs/superpowers/specs/`，实现计划见 `docs/superpowers/plans/`。心率和卡路里用 Apple Watch 自带「体能训练」里的「传统力量训练」记录。

## 网页版

代码在 `web/`，没有编译步骤，不用 npm 依赖。动作、计划、视频数据和示范图沿用 iOS 版的文件。

本地预览：

```sh
scripts/build_web.sh
python3 -m http.server 8000 -d _site
```

然后打开 http://localhost:8000/

测试：

```sh
node --test web/test/*.test.js
python3 scripts/validate_data.py
```

部署：推送到 `main` 后，GitHub Actions（`.github/workflows/pages.yml`）跑测试、组装 `_site/` 并发布到 GitHub Pages。

### 在 iPhone 上安装

1. 用 Chrome 打开上面的网址，点地址栏右边的分享按钮 → 「添加到主屏幕」
2. 以后都从主屏幕图标打开。主屏幕 app 和浏览器标签页的数据不互通

### 训练记录同步到 GitHub

记录存在手机上，填了令牌后会在打开 app、练完、点「立即同步」时自动同步到私有仓库的 `workouts.json`。换手机时填上令牌同步一次就能拉回全部记录。

1. 在 GitHub 新建私有仓库 `fitness-data`，勾选「Add a README file」
2. 生成令牌：GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token
   - Repository access 选 Only select repositories → `fitness-data`
   - Permissions → Repository permissions → Contents 选 Read and write
3. 在 app 里「历史 → 设置」填仓库 `ym820/fitness-data` 和令牌，点「保存并同步」
4. 令牌过期后，app 会提示「令牌无效或已过期」，重新生成一个填进去。手机丢了的话，去 GitHub 删掉这个令牌

## iOS app（不再维护）

下面是原来 iPhone + Apple Watch 版本的说明，代码还在仓库里，不再更新。
````

- [ ] **Step 3: 本地完整检查一次**

Run: `node --test web/test/*.test.js && python3 scripts/validate_data.py && scripts/build_web.sh`
Expected: 测试全部通过，`OK：30 个动作…`，`_site/` 生成成功

- [ ] **Step 4: 提交**

```bash
git add .github/workflows/pages.yml README.md
git commit -m "Deploy web app to GitHub Pages"
```

---

### Task 12: 公开仓库前的检查和上线（需要用户操作）

这一步不改代码。仓库改公开、开 GitHub Pages、建 `fitness-data`、生成令牌都由用户自己在 GitHub 上操作。

- [ ] **Step 1: 检查提交历史里有没有不该公开的东西**

Run:

```bash
git log --all -p | grep -nE 'ghp_|github_pat_|gho_|sk-[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY|password[[:space:]]*[:=]' | head -20
git log --all --format='%an <%ae>' | sort -u
git log --all --format=%B | grep -c 'Claude-Session' || true
```

Expected: 第一条没有输出。把第二条（会公开的作者名字和邮箱）和第三条（提交说明里 Claude 会话链接的数量，这些链接别人打不开）的结果给用户看。

- [ ] **Step 2: 用户确认后，推送代码**

```bash
git push
```

- [ ] **Step 3: 用户在 GitHub 上操作**

1. 仓库 Settings → General → 最下面 Danger Zone → Change repository visibility → Public
2. Settings → Pages → Build and deployment → Source 选 GitHub Actions
3. Actions 页面找到「Deploy web」，点 Run workflow（或者再推送一次）
4. 按 README「训练记录同步到 GitHub」的步骤建 `fitness-data`、生成令牌

- [ ] **Step 4: 线上检查**

- 打开 `https://ym820.github.io/personal-fitness-app/`，示范图、视频封面都能显示
- iPhone 上用 Chrome 添加到主屏幕，从图标打开：全屏，没有地址栏
- 「历史 → 设置」填令牌，保存后显示「上次成功：…」；GitHub 上 `fitness-data` 出现 `workouts.json`
- 实际练一次（或者做两组后结束），结束页显示「已同步到 GitHub。」，`workouts.json` 里有这次记录
- 练的时候观察屏幕是否会自动锁屏（检查屏幕常亮是否生效），把结果记到 README 的「在 iPhone 上安装」一节
