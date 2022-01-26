Cache = function (cacheName) {
  this.name = cacheName;
  return this;
};

Cache.prototype.match = function (request, options) {
  var cacheName = this.name;
  return cacheMatch(cacheName, request, options);
};

Cache.prototype.matchAll = function (request, options) {
  var cacheName = this.name;
  return cacheMatchAll(cacheName, request, options);
};


Cache.prototype.add = function (request) {
  // Fetch a response for the given request, then put the pair into the cache.
  var cache = this;
  return fetch(request).then(function (response) {
    return cache.put(request, response);
  });
};

Cache.prototype.addAll = function (requests) {
  // Create a list of `add` promises, one for each request.
  var promiseList = [];
  for (var i = 0; i < requests.length; i++) {
    promiseList.push(this.add(requests[i]));
  }

  // Return a promise for all of the `add` promises.
  return Promise.all(promiseList);
};


/** 
*  @function Cache#put
*  @param {string|Request} request 
*  @param {Response}       response
*  @returns {Promise}
*
* https://w3c.github.io/ServiceWorker/#cache-put
*/
Cache.prototype.put = function(request, response) {
  var cacheName = this.name;

  return new Promise(function(resolve, reject) {
    // Call the native put function.
      response.toDict().then(function (responseDict) {
          var requestDict;
          if (typeof request === "string") {
              request = new Request(request);
          }
          
          requestDict = request.toDict();
          responseDict.url = requestDict.url;
          cachePut(cacheName, requestDict, responseDict, resolve, reject);
      }).catch(function (e) {
          reject(e);
      });
  });
};

Cache.prototype.delete = function (request, options) {
  var cacheName = this.name;
  return new Promise(function (resolve, reject) {
    // Call the native delete function.
    cacheDelete(cacheName, request, options, resolve, reject);
  });
};

Cache.prototype.keys = function (request, options) {
  var cacheName = this.name;
  return new Promise(function (resolve, reject) {
    // Convert the given request dictionaries to actual requests.
    var innerResolve = function (dicts) {
      var requests = [];
      for (var i = 0; i < dicts.length; i++) {
        var requestDict = dicts[i];
        requests.push(new Request(requestDict.method, requestDict.url, requestDict.headers));
      }
      resolve(requests);
    };

    // Call the native keys function.
    cacheKeys(cacheName, request, options, innerResolve, reject);
  });
};


CacheStorage = function () {
  // TODO: Consider JS cache name caching solutions, such as a list of cache names and a flag for whether we have fetched from CoreData yet.
  // Right now, all calls except `open` go to native.
  this.cachesByName = {};
  this.isPolyfill = true;
  return this;
};


CacheStorage.prototype.match = function (request, options) {
  return cacheMatch(options && options.cacheName, request, options);
};


CacheStorage.prototype.has = function (cacheName) {
  var self = this;
  return new Promise(function (resolve, reject) {
    if (self.cachesByName[cacheName]) {
      resolve(true);
    } else {
      // Check if the cache exists in native.
      cachesHas(cacheName, resolve, reject);
    }
  });
};

CacheStorage.prototype.open = function (cacheName) {
  var self = this;
  return new Promise(function (resolve, reject) {
    if (!self.cachesByName[cacheName]) {
      self.cachesByName[cacheName] = new Cache(cacheName);
    }
    // Resolve the promise with a JS cache.
    resolve(self.cachesByName[cacheName]);
  });
};

// This function returns a promise for a response.
CacheStorage.prototype.delete = function (cacheName) {
  return new Promise(function (resolve, reject) {
    // Delete the cache in native.
    cacheDelete(cacheName, resolve, reject);
  });
};

// This function returns a promise for a response.
CacheStorage.prototype.keys = function () {
  return new Promise(function (resolve, reject) {
    // Resolve the promise with the cache name list.
    cachesKeys(resolve, reject);
  });
};


makeMatchHandler = function () {
  var handler = {};
  handler.promise = new Promise(function (resolve, reject) {
    handler.reject = reject;
    handler.resolve = function (response, error) {
      var jsResponse;
      if (error) {
        handler.reject(error);
      } else {
        jsResponse = Response.createResponseForServiceWorkerResponse(response);
        resolve(jsResponse || null);
      }
    };
  });
  return handler;
};

makeMatchAllHandler = function () {
  var handler = {};
  handler.promise = new Promise(function (resolve, reject) {
    handler.reject = reject;
    handler.resolve = function (responses, error) {
      if (error) {
        reject(error);
      } else if (Array.isArray(responses)) {
        resolve(responses.map(function (response) {
          return Response.createResponseForServiceWorkerResponse(response);
        }));
      } else {
        resolve(null);
      }
    };
  });
  return handler;
};

if (typeof cordova !== 'undefined') {
  var exec = require('cordova/exec');

  cacheMatch = function (cacheName, request, options) {
    var handler = makeMatchHandler();
    if (!(request instanceof Request)) {
      request = new Request(request);
    }
    var requestDict = request.toDict();
    exec(handler.resolve, handler.reject, "ServiceWorkerCacheApi", "match", [cacheName, requestDict, options]);
    return handler.promise;
  };

  cacheMatchAll = function (cacheName, request, options, resolve, reject) {
    var handler = makeMatchAllHandler();
    if (!(request instanceof Request)) {
      request = new Request(request);
    }
    var requestDict = request.toDict();
    exec(handler.resolve, handler.reject, "ServiceWorkerCacheApi", "matchAll", [cacheName, requestDict, options]);
    return handler.promise;
  };

  cachePut = function (cacheName, request, response, resolve, reject) {
    exec(resolve, reject, "ServiceWorkerCacheApi", "put", [cacheName, request, response]);
  };
  cacheDelete = function (cacheName, resolve, reject) {
    exec(resolve, reject, "ServiceWorkerCacheApi", "delete", [cacheName, request, options]);
  };
    
   cachesKeys = function (resolve, reject) {
      exec(resolve, reject, "ServiceWorkerCacheApi", "keys");
   };
  /**
   *  Overwrites window.caches.
   *  This is configured by in plugin.xml by
   *   <js-module src="www/cache.js" name="CacheStorage">
   *      <clobbers target="caches" />
   *   </js-module>
   */
  module.exports = new CacheStorage();
} else {

  cachesHas = function (cacheName, resolve, reject) {
    var message = {
      cacheName: cacheName
    };
    cordovaExec("cachesHas", message, function (response, error) {
      if (error) {
        reject(error);
      } else {
        resolve(response.result);
      }
    });
  };

  cacheMatch = function (cacheName, request, options) {
    var message = {
      cacheName: cacheName,
      request: request instanceof Request ? request.toDict() : request,
      options: options
    },
    handler = makeMatchHandler();
    cordovaExec("cacheMatch", message, handler.resolve);
    return handler.promise;
  };

  cacheMatchAll = function (cacheName, request, options, resolve, reject) {
    var message = {
      cacheName: cacheName,
      request: request,
      options: options
    },
    handler = makeMatchAllHandler();
    cordovaExec("cacheMatchAll", message, handler.resolve);
    return handler.promise;
  };

  cachePut = function (cacheName, request, response, resolve, reject) {
    var message = {
      cacheName: cacheName,
      request: request,
      response: response,
      options: {}
    };

    cordovaExec("cachePut", message, function (response, error) {
      if (error) {
        reject(error);
      } else {
        resolve(response);
      }
    });
  };

  cacheDelete = function (cacheName, resolve, reject) {
    var message = {
      cacheName: cacheName,
      options: {}
    };

    cordovaExec("cacheDelete", message, function (response, error) {
      if (error) {
        reject(error);
      } else {
        resolve(response.success);
      }
    });
  };
    
    cachesKeys = function (resolve, reject) {
        var message = {
          options: {}
        };
        cordovaExec("cachesKeys", message, function (response, error) {
          if (error) {
            reject(error);
          } else {
            resolve(response.result);
          }
        });
    };
}

try {
  window.contourCaches = new CacheStorage();
  Object.defineProperty(window, "caches", {
      get: function () {
          return window.contourCaches;
      }
  });
  if (!window.caches.isPolyfill) {
      console.error("Failed to overwrite native CacheStorage, but no error was thrown");
  }
} catch (e) {
  console.error("Failed to overwrite native CacheStorage");
  console.error(e);
}
