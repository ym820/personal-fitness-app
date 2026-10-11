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
