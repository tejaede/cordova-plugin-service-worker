polyfillIsReady.then(function () {
    var el = document.createElement("script"),
    head = document.querySelector("head"),
    src = "{{SERVICE_WORKER_PATH}}";
    el.setAttribute("type", "text/javascript");
    el.setAttribute("src", src);
    head.appendChild(el);
    el.onload = function () {
        cordovaExec("serviceWorkerLoaded", {
            url: src
        });
    }
});
''; //prevents warning when running script from CDVServiceWorker.m
