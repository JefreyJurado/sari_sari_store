// web/sqflite_sw.js
self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(clients.claim());
});

self.addEventListener('message', function(event) {
  event.waitUntil(
    (async () => {
      if (event.data && event.data.type === 'INIT') {
        // Respond to initialization
        event.source.postMessage({
          type: 'INIT_RESULT',
          success: true
        });
      }
    })()
  );
});

self.postMessage({ type: 'ready' });