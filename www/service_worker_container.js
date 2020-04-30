
var ServiceWorkerContainer;
if (typeof cordova !== "undefined") {
    var exec = require('cordova/exec'),
    deviceReadyPromise = new Promise(function (resolve, reject) {
        document.addEventListener('deviceready', resolve, false);
    });
    ServiceWorkerContainer = {
        //The ready promise is resolved when there is an active Service Worker with registration and the device is ready
        register: function (scriptURL, options) {
            var successCallback = this._makeRegistration.bind(this),
                failureCallback = this._rejectRegistrationPromise,
                absoluteScriptURL = this._resolveURL(scriptURL);
    
            deviceReadyPromise.then(function () {
                exec(successCallback, failureCallback, "ServiceWorker", "register", [scriptURL, options, absoluteScriptURL]);
            });
            return this._registrationPromise;
        },
        _makeRegistration: function (nativeRegisterResult) {
            var registration = new ServiceWorkerRegistration(nativeRegisterResult.installing, nativeRegisterResult.waiting, new ServiceWorker(), nativeRegisterResult.registeringScriptUrl, nativeRegisterResult.scope);
            this._resolveRegistrationPromise(registration);
        },
        _resolveURL: function (url) {
            var anchor = document.createElement("a");
            anchor.setAttribute("href", url);
            return anchor.href;
        },
        addEventListener: function (type, handler, bubble) {
            //Event Target will be window instead of serviceWorker
            window.addEventListener(type, handler, bubble);
        }
    };
    Object.defineProperties(ServiceWorkerContainer, {
        ready: {
            get: function () {
                var self = this;
                if (!this._readyPromise) {
                    this._readyPromise = new Promise(function (resolve, reject) {
                        self._registrationPromise.then(function (registration) {
                            var callback = function () {
                                resolve(registration);
                            };
                            exec(callback, null, "ServiceWorker", "serviceWorkerReady", []);
                        });
                    });
                }
                return this._readyPromise;
            }
        },
        _registrationPromise: {
            get: function () {
                var self = this;
                if (!this.__registrationPromise) {
                    this.__registrationPromise = new Promise(function (resolve, reject) {
                        self._rejectRegistrationPromise = reject;
                        self._resolveRegistrationPromise = resolve;
                    });
                }
                return this.__registrationPromise;
            }
        }
    });
    
    
    module.exports = ServiceWorkerContainer;
} else {
    //TODO implement
    window.skipWaiting = function () {};
    ServiceWorkerContainer = function ServiceWorkerContainer(scriptURL) {
        this.scriptURL = scriptURL;
    };
}

