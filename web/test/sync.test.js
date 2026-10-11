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
