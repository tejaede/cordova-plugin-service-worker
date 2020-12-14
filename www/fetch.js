if (typeof cordova === "undefined") { // SW-Only

  FetchEvent = function (eventInitDict) {
    Event.call(this, 'fetch');
    if (eventInitDict) {
      if (eventInitDict.id) {
        Object.defineProperty(this, '__requestId', {
          value: eventInitDict.id
        });
      }
      if (eventInitDict.request) {
        Object.defineProperty(this, 'request', {
          value: eventInitDict.request
        });
      }
      if (eventInitDict.client) {
        Object.defineProperty(this, 'client', {
          value: eventInitDict.client
        });
      }
      if (eventInitDict.isReload) {
        Object.defineProperty(this, 'isReload', {
          value: !!(eventInitDict.isReload)
        });
      }
    }
    Object.defineProperty(this, "type", {
      get: function () {
        return "fetch";
      }
    });
  };


  FetchEvent.prototype = Object.create(Event.prototype);
  FetchEvent.constructor = FetchEvent;

  FetchEvent.prototype.respondWith = function (response) {

    // Prevent the default handler from running, so that it doesn't override this response.
    this.preventDefault();

    // Store the id locally, for use in the `convertAndHandle` function.
    var requestId = this.__requestId;
    var stack = new Error().stack;

    // Send the response to native.
    var convertAndHandle = function (response) {
      try {
        response.body = window.btoa(response.body);
      } catch (e) {
        console.warn("Failed to decode response body for URL: ", response.url);
      }


      handleFetchResponse(requestId, response);
    };

    // TODO: Find a better way to determine whether `response` is a promise.
    if (response.then) {
      // `response` is a promise!
      response.then(convertAndHandle);
    } else {
      convertAndHandle(response);
    }
  };

  FetchEvent.prototype.forwardTo = function (url) {};

  FetchEvent.prototype.default = function (ev) {
    handleFetchDefault(ev.__requestId, {
      url: ev.request.url
    });
  };

  Request = function (url, options) {
    options = options || {};
    this.url = URL.absoluteURLFromMainClient(url);
    this.method = options && options.method || "GET";
    this.headers = options.headers instanceof Headers ? options.headers :
      options.headers ? new Headers(options.headers) :
      new Headers({});
    this.body = options.body;
  };


  var readFileAsArrayBuffer = function (file) {
    return new Promise(function (resolve, reject) {
      var reader = new FileReader();
      reader.onload = function (event) {
        resolve(event.target.result);
      };
      reader.onerror = function (error) {
        reject(error);
      };
      reader.readAsArrayBuffer(file);
    });
  };

  var _arrayBufferToBase64 = function (buffer) {
    var binary = '';
    var bytes = new Uint8Array(buffer);
    var len = bytes.byteLength;
    for (var i = 0; i < len; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return window.btoa(binary);
  };


  var mapFormDataForKey = function (formData, rawForm, key) {
    var value = formData.get(key);
    if (value instanceof File) {
      return readFileAsArrayBuffer(value).then(function (arrayBuffer) {
        rawForm[key] = {
          name: value.name,
          type: value.type,
          size: value.size,
          data: _arrayBufferToBase64(arrayBuffer)
        };
        return null;
      });
    }
    rawForm[key] = value;
    return null;
  };

  var serializeFormData = function (formData) {
    // Setup our serialized data
    var keys = formData.keys(),
      promises = [],
      serialized = null,
      key;

    while ((key = keys.next().value)) {
      serialized = serialized || {};
      promises.push(mapFormDataForKey(formData, serialized, key));
    }
    return Promise.all(promises).then(function () {
      return serialized;
    });
  };


  Request.prototype.text = function () {
    var serializedBody;
    if (this.body instanceof FormData) {
      serializedBody = serializeFormData(this.body);
    } else if (typeof this.body === "object") {
      try {
        serializedBody = JSON.stringify(this.body);
      } catch (e) {}
    } else if (typeof this.body === "string") {
      serializedBody = this.body;
    }
    return Promise.resolve(serializedBody || "");
  };

  Request.prototype.json = function () {
    return this.text().then(function (text) {
      return JSON.parse(text);
    });
  };


  //TODO Implement abort
  Request.prototype.signal = true;

  Request.create = function (method, url, headers) {
    return new Request(url, {
      method: method,
      headers: headers
    });
  };


  var protocolRegexp = /^^(file|https?)\:\/\//;
  URL.absoluteURLFromMainClient = function (url) {
    var baseURL = window.mainClientURL || window.location.href;
    url = protocolRegexp.test(url) ? url : new URL(url, baseURL).toString();
    return url;
  };
  // This function returns a promise with a response for fetching the given resource.
  function fetch(input) {
    // Assume the passed in input is a resource URL string.
    // TODO: What should the default headers be?
    var inputIsRequest = input instanceof Request,
      body, method, headers, url;

    if (inputIsRequest) {
      method = input.method;
      url = input.url;
      headers = input.headers;
    } else if (typeof input === "object") {
      method = input.method;
      url = URL.absoluteURLFromMainClient(input.url);
      headers = input.headers;
      body = input.body;
    } else {
      url = URL.absoluteURLFromMainClient(input);
      method = 'GET';
      headers = {};
    }

    return new Promise(function (innerResolve, reject) {
      // Wrap the resolve callback so we can decode the response body.
      var resolve = function (swResponse) {
        var response = Response.createResponseForServiceWorkerResponse(swResponse);
        innerResolve(response);
      };

      if (inputIsRequest) {
        input.text().then(function (body) {
          // Call a native function to fetch the resource.
          handleTrueFetch(method, url, headers, body, resolve, reject);
        });
      } else {
        // Call a native function to fetch the resource.
        handleTrueFetch(method, url, headers, body, resolve, reject);
      }
    });
  }

  handleTrueFetch = function (method, url, headers, body, resolve, reject) {
    var message = {
      method: method,
      url: url,
      headers: headers instanceof Headers ? mapHeadersToPOJO(headers) : headers,
      body: body
    };

    cordovaExec("trueFetch", message, function (response, error) {

      if (error) {
        reject(error);
      } else {
        resolve(response);
      }
    });
  };


  handleFetchResponse = function (requestId, response) {
    return response.toDict().then(function (response) {
      return {
        requestId: requestId,
        response: response
      };
    }).catch(function (e) {
      return {
        error: e.message,
        stack: e.stack
      };
    }).then(function (message) {
      cordovaExec("fetchResponse", message, function (response, error) {
        //intentionally noop
      });
    });
  };

  handleFetchDefault = function (requestId, request) {
    var message = {
      requestId: requestId,
      request: request
    };

    cordovaExec("fetchDefault", message, function (response, error) {
      //intentionally noop
      if (error) {
        reject(error);
      } else {
        resolve(response);
      }
    });
  };

}
// END SW-Only code

Object.defineProperties(Headers.prototype, {
  toDict: {
    value: function () {
      var dict = {},
        iterator = this.keys(),
        key;
      while ((key = iterator.next().value)) {
        dict[key] = this.get(key);
      }
      return dict;
    }
  }
});

function mapHeadersToPOJO(headers) {
  var dict = {},
    keys = headers.keys(),
    key;

  while ((key = keys.next().value)) {
    dict[key] = headers.get(key);
  }
  return dict;
}


Request.prototype.formData = function () {
  var regExp;
  if (this.body instanceof FormData) {
    return Promise.resolve(this.body);
  } else {
    regExp = /(?:(\w*)=(\w*))/g;
    return this.text().then(function (text) {
      var formData = new FormData(),
        match;
      while ((match = regExp.exec(text))) {
        formData.set(match[1], match[2]);
      }
      return formData;
    });
  }
};

Request.prototype.toDict = function () {
  return {
    url: this.url,
    method: this.method,
    headers: mapHeadersToPOJO(this.headers)
  };
};

Response.create = function (body, url, status, headers) {
  var response = new Response(body, {
    url: url,
    status: status,
    headers: headers
  });

  Object.defineProperty(response, "url", {
    value: url
  });
  return response;

  // return new Response(body, {
  //   url: url,
  //   status: status,
  //   headers: headers
  // });
};


/****
 * Creates a native JS response for a dictionary generated 
 * by objective c ServiceWorkerResponse#toDictionary
 */
Response.createResponseForServiceWorkerResponse = function (serviceWorkerResponse) {
  var response = null,
    isEncoded,
    body;
  if (serviceWorkerResponse) {
    isEncoded = serviceWorkerResponse.isEncoded !== undefined ? parseInt(serviceWorkerResponse.isEncoded) : !serviceWorkerResponse.url.endsWith(".js");
    body = isEncoded ? window.atob(serviceWorkerResponse.body) : serviceWorkerResponse.body;
    response = new Response(body, {
      status: serviceWorkerResponse.status,
      headers: serviceWorkerResponse.headers
    });
    Object.defineProperty(response, "url", {
      value: serviceWorkerResponse.url
    });
  }
  return response;
};

Response.prototype.serializedBody = function () {
  // return this.url.endsWith(".js") ? this.text() : this.base64EncodedString();
  return this.base64EncodedString();
};


Response.prototype.toDict = function () {
  var self = this;
  return this.serializedBody().then(function (base64String) {
    return {
      url: self.url,
      body: base64String,
      headers: mapHeadersToPOJO(self.headers),
      status: self.status
    };
  });
};

function arrayBufferToBase64String(arrayBuffer) {
  var string = arrayBufferToString(arrayBuffer);
  return window.btoa(string)
}

function arrayBufferToString(arrayBuffer) {
  var array = new Uint8Array(arrayBuffer),
      string = "",
      i, n;
  for (i = 0, n = array.length; i < n; ++i) {
      string += String.fromCharCode(array[i])
  }
  return string;
}

Response.prototype.base64EncodedString = function () {
  if (!this._base64EncodedString) {
    this._base64EncodedString = this.arrayBuffer().then(function (arrayBuffer) {
      return arrayBufferToBase64String(arrayBuffer);
    });
  }
  return this._base64EncodedString;
};


  var baseCorsURL = window.location.protocol + "//" + window.location.host + "/cross-origin?",
    protocolRegexp,
    hostRegexp;
  function prepareURL(url) {
    hostRegexp = hostRegexp || new RegExp("^(https?|cordova-main)\:\/\/" + window.location.host.replace(/\./g, "\\."));
    protocolRegexp = protocolRegexp || /(https?|cordova-main):\/\//;
     if (hostRegexp.test(url)) {
      url = url.replace(/https/, "cordova-main");
    } else if (protocolRegexp.test(url)) {
      url = baseCorsURL + url;
    }
    return url;
  }

  function serializedBodyForRequest(request) {
    var contentType = request.headers.get("content-type"),
        isContentTypeJSON = contentType === "application/json";
    if (request.arrayBuffer) {
        return request.arrayBuffer().then(function (arrayBuffer) {
            return isContentTypeJSON ? arrayBufferToString(arrayBuffer) : arrayBufferToBase64String(arrayBuffer);
        });
    } else {
        return request.text().then(function (text) {
            return isContentTypeJSON ? text : window.btoa(text)
        })
    }
  } 
   
  var originalFetch = window.fetch;
  window.fetch = function (requestOrURL, init) {
    var shouldSerializeBody = false,
      isBodyNativeFormData = false,
      url, options;
    if (requestOrURL instanceof Request) {
      url = prepareURL(requestOrURL.url);
      options = requestOrURL;
      isBodyNativeFormData = options.nativeFormData && options.nativeFormData instanceof FormData;
      if (isBodyNativeFormData) {
        options.headers.delete("content-type");
        options = {
          method: options.method,
          headers: options.headers,
          body: options.nativeFormData,
          referrer: options.referrer,
          referrerPolicy: options.referrerPolicy,
          mode: options.mode,
          credentials: options.credentials,
          cache: options.cache,
          redirect: options.redirect,
          integrity: options.integrity,
          keepalive: options.keepalive,
          signal: options.signal
        };
      }
    } else {
      url = prepareURL(requestOrURL);
      options = init || {};
    }
    shouldSerializeBody = options.method === "POST" && !isBodyNativeFormData;

    if (shouldSerializeBody) {
      return serializedBodyForRequest(requestOrURL).then(function (text) {
        options = {
          method: options.method,
          headers: options.headers,
          body: text,
          referrer: options.referrer,
          referrerPolicy: options.referrerPolicy,
          mode: options.mode,
          credentials: options.credentials,
          cache: options.cache,
          redirect: options.redirect,
          integrity: options.integrity,
          keepalive: options.keepalive,
          signal: options.signal
        };
        return originalFetch.call(window, new Request(url, options));
      });
    } else {
      return originalFetch.call(window, new Request(url, options));
    }
  };

  (function () {
    var proxied = window.XMLHttpRequest.prototype.open;
    window.XMLHttpRequest.prototype.open = function () {
      var url = arguments[1],
        args = [].slice.call(arguments);
      if (url) {
        args[1] = prepareURL(url);
      }
      return proxied.apply(this, args);
    };
  })();
