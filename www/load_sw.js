polyfillIsReady.then(function () {
    var src = "{{SERVICE_WORKER_PATH}}";
    window.importScripts(src).then(function () {

        cordovaExec("serviceWorkerLoaded", {
            url: src
        });
    });
});
''; //prevents warning when running script from CDVServiceWorker.m