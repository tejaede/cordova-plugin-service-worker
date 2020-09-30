window.polyfillIsReady = new Promise(function (resolve) {
    window.resolvePolyfillIsReady = resolve;
});
window.polyfillIsReady.then(function () {
    cordovaExec("polyfillIsReady", {}, function (data, error) {
        if (error) {
            console.error("Failed to notify service worker that polyfill is ready", error);
        } 
    });
});
''; //Prevents WKWebView evaluateJavascript from throwing warning