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
