setTimeout(function () {
    FireInstallEvent().then(window.installServiceWorkerCallback);
}, 10);
''; //Prevents WKWebView evaluateJavascript from throwing warning