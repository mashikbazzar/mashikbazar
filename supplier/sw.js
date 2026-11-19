var CACHE="masik-bazar-supplier-v5";
self.addEventListener("install", function(e){ self.skipWaiting(); e.waitUntil(caches.open(CACHE).then(function(c){ return c.addAll(["./","index.html","manifest.webmanifest"]); })); });
self.addEventListener("activate", function(e){ e.waitUntil(caches.keys().then(function(ks){ return Promise.all(ks.filter(function(k){ return k!==CACHE; }).map(function(k){ return caches.delete(k); })); }).then(function(){ return self.clients.claim(); })); });
self.addEventListener("fetch", function(e){ if(e.request.method!=="GET") return; var u=new URL(e.request.url); if(u.origin!==location.origin) return; e.respondWith(caches.match(e.request).then(function(r){ return r||fetch(e.request); })); });
