window.polyfillIsReady = new Promise(function (resolve) {
    window.resolvePolyfillIsReady = resolve;
});
''; //Prevents WKWebView evaluateJavascript from throwing warning