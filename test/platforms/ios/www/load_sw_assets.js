var head = document.querySelector("head"),
    scripts = [
        'asset-a.js',
        'asset-b.js',
        'asset-c.js',
        'asset-d.js'
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
