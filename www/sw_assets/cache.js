(function () {
    var caches = window.caches,
        origOpen = caches.open;
    Object.defineProperty(caches, "open", {
        value: function (cacheName) {
            return origOpen.call(window.caches, cacheName).then(function (cache) {
                overrideAddMethods(cache);
                return cache;
            });
        }
    });

    function overrideAddMethods(cache) {
        cache.add = function (url) {
            url = URL.absoluteURLfromMainClient(url);
            return fetch(url).then(function(response) {
              if (!response.ok) {
                throw new TypeError('bad response status');
              }
              return cache.put(url, response.fetchResponse);
            }).catch(function (e) {
                console.error("Failed to put response", url);
            });
        };
        cache.addAll = function (urls) {
            return Promise.all(urls.map(function (url) {
                return cache.add(url);
            })).catch(function (e) {
                console.error("Failed to add all", urls);
            });
        };
    }
})();
