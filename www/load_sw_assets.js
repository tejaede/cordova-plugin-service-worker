var head = document.querySelector("head"),
    scripts = [
        {{SERVICE_WORKER_ASSETS}}
    ],
    resolvePolyfillIsReady,
    polyfillIsReady = new Promise(function (resolve) {
        resolvePolyfillIsReady = resolve;
    }), 
    scriptsLoaded = 0;


function loadScript(script) {
   var el = document.createElement("script");
   el.setAttribute("type", "text/javascript");
   el.setAttribute("src", script);
   el.onload = function () {
       scriptsLoaded++;
       if (scriptsLoaded === scripts.length) {
          resolvePolyfillIsReady();
       }
   };
   head.appendChild(el);
}

scripts.forEach(function (script) {
    loadScript(script);
});
