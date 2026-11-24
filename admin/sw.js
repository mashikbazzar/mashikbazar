var CACHE="neer-admin-v54"; var FILES=["./","./index.html","./manifest.webmanifest","./icon.svg","./icon-192.png?v=2","./icon-512.png?v=2"];
self.addEventListener("install",function(e){ e.waitUntil(caches.open(CACHE).then(function(c){ return c.addAll(FILES); })); self.skipWaiting(); });
self.addEventListener("activate",function(e){ e.waitUntil(caches.keys().then(function(ks){ return Promise.all(ks.filter(function(k){ return k!==CACHE; }).map(function(k){ return caches.delete(k); })); })); self.clients.claim(); });
self.addEventListener("fetch",function(e){
  e.respondWith(fetch(e.request,{cache:"no-store"}).then(function(r){ var c=r.clone(); caches.open(CACHE).then(function(cache){ cache.put(e.request, c); }); return r; }).catch(function(){ return caches.match(e.request); }));
});
