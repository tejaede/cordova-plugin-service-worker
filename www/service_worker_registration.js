var ServiceWorkerRegistration = function ServiceWorkerRegistration(installing, waiting, active, registeringScriptURL, scope) {
    this.installing = installing;
    this.waiting = waiting;
    this.active = active;
    this.scope = scope;
    this.registeringScriptURL = registeringScriptURL;
    if (!this.active.scriptURL) {
        this.active.scriptURL = registeringScriptURL;
    }
    this.uninstalling = false;
    // TODO: Update?
};


if (typeof cordova !== 'undefined') {
    var exec = require('cordova/exec');
    ServiceWorkerRegistration.prototype.unregister = function () {
        var registeringScriptURL = this.registeringScriptURL,
            scope = this.scope;
        return new Promise(function (resolve, reject) {
            exec(resolve, reject, "ServiceWorker", "unregister", [registeringScriptURL, scope]);
        });
    };
    module.exports = ServiceWorkerRegistration;
}
