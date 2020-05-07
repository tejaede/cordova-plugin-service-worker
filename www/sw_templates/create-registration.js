var container = new ServiceWorkerContainer('%@');
self.registration = new ServiceWorkerRegistration(undefined, undefined, container);
''; //Prevents WKWebView evaluateJavascript from throwing warning

