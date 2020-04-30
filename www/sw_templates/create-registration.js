self.registration = new ServiceWorkerRegistration();
registration.active = new ServiceWorkerContainer('%@');
''; //Prevents WKWebView evaluateJavascript from throwing warning

