// 每次部署 scripts/build_web.sh 会把 __VERSION__ 换成站内文件的校验和，内容变了 sw.js 就变。
// 新版本在后台把整套文件下载进新缓存，全部成功才接管，再删掉旧缓存。
// 这样任何时候都是整套旧版或整套新版，不会新旧文件混在一起导致白屏。
// 只管本站文件；GitHub API 和 B 站不经过这里。
const CACHE = 'fitness-__VERSION__';

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const files = await (await fetch('files.json', { cache: 'no-store' })).json();
    const cache = await caches.open(CACHE);
    // 绕过 HTTP 缓存，拿到的一定是这次部署的文件
    await cache.addAll(['./', ...files].map(url => new Request(url, { cache: 'reload' })));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) if (key !== CACHE) await caches.delete(key);
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  event.respondWith((async () => {
    const cached = await caches.match(event.request, { cacheName: CACHE, ignoreSearch: true });
    return cached ?? fetch(event.request);
  })());
});
