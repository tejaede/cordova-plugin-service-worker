var ServiceWorkerRegistration = function ServiceWorkerRegistration(installing, waiting, active, registeringScriptURL, scope) {
    this.installing = installing;
    this.waiting = waiting;
    this.active = active;
    this.scope = scope;
    this.registeringScriptURL = registeringScriptURL;
    this.uninstalling = false;
    
    // TODO: Update?
};


if (typeof cordova !== 'undefined') {
    module.exports = ServiceWorkerRegistration;
}
