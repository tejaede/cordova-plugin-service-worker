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

Headers = function (headerDict) {
  this.headerDict = headerDict || {};
};

Headers.prototype.append = function (name, value) {
  if (this.headerDict[name]) {
    this.headerDict[name].push(value);
  } else {
    this.headerDict[name] = [value];
  }
};

Headers.prototype.delete = function (name) {
  delete this.headerDict[name];
};

Headers.prototype.get = function (name) {
  return this.headerDict[name] ? this.headerDict[name][0] : null;
};

Headers.prototype.getAll = function (name) {
  return this.headerDict[name] ? this.headerDict[name] : null;
};

Headers.prototype.has = function (name, value) {
  return this.headerDict[name] !== undefined;
};

Headers.prototype.set = function (name, value) {
  this.headerDict[name] = [value];
};

Headers.prototype.forEach = function (callback) {
    var self = this,
        keys = Object.keys(this.headerDict);
    keys.forEach(function (key) {
        callback(self.headerDict[key], key);
    });
}

Request = function (url, options) {
  options = options || {};
  this.url = URL.absoluteURLfromMainClient(url);
  this.method = options.method || "GET";
  this.headers = options.headers || new Headers({});
};

//TODO Implement abort
Request.prototype.signal = true;

Request.create = function (method, url, headers) {
  return new Request(url, {
    method: method,
    headers: headers
  });
};


function createResponse(body, url, status, headers) {
    return  new Response(body, {
        url: url,
        status: status,
        headers: headers
    });
}

Response.prototype.toDict = function () {
  return {
    "body": window.btoa(this.body),
    "url": this.url,
    "status": this.status,
    "headers": this.headers
  };
};

var protocolRegexp = /^^(file|https?)\:\/\//;
URL.absoluteURLfromMainClient = function (url) {
  var baseURL = window.mainClientURL || window.location.href;
  url = protocolRegexp.test(url) ? url : new URL(url, baseURL).toString();
   return url;
};
// This function returns a promise with a response for fetching the given resource.
function fetch(input) {
  // Assume the passed in input is a resource URL string.
  // TODO: What should the default headers be?
  var method, headers, url;

  if (input instanceof Request) {
    method = input.method;
    url = input.url;
    headers = input.headers;
  } else if (typeof input === "object") {
    method = input.method;
    url = URL.absoluteURLfromMainClient(input.url);
    headers = input.headers;
  } else {
    url = URL.absoluteURLfromMainClient(input);
    method = 'GET';
    headers = {};
  }


  return new Promise(function (innerResolve, reject) {
    // Wrap the resolve callback so we can decode the response body.
    var resolve = function (response) {
        var body;
        if (url.endsWith(".js")) {
            body = response.body;
        } else {
            body = window.atob(response.body);
        }
      var jsResponse = new createResponse(body, response.url, response.status, response.headers);
        if (jsResponse.status < 200 || jsResponse.status >= 400) {
          console.error("Fetch failed with status (" + jsResponse.status + ") for url: " + jsResponse.url);
        }
      innerResolve(jsResponse);
    };

    // Call a native function to fetch the resource.
    handleTrueFetch(method, url, headers, resolve, reject);
  });
}
handleTrueFetch = function (method, url, headers, resolve, reject) {
  var message = {
    method: method,
    url: url,
    headers: headers
  };

  cordovaExec("trueFetch", message, function (response, error) {

    if (error) {
      reject(error);
    } else {
      resolve(response);
    }
  });
}


handleFetchResponse = function (requestId, response) {
  var message = {
    requestId: requestId,
    response: response
  };
  cordovaExec("fetchResponse", message, function (response, error) {
    //intentionally noop
  });
};

handleFetchDefault = function (requestId, request) {
  var message = {
    requestId: requestId,
    request: request
  };
  cordovaExec("fetchDefault", message, function (response, error) {
    //intentionally noop
  });
};
