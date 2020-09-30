var head = document.querySelector("head"),
    scripts = [
        {{SW_ASSETS}}
    ],
    scriptsLoaded = 0;


function loadScript(script, callback) {
   var el = document.createElement("script");
   el.setAttribute("type", "text/javascript");
   el.setAttribute("src", script);
   el.onload = function () {
        callback();
   };
   head.appendChild(el);
}

function loadNext() {
    var script = scripts[scriptsLoaded];
    loadScript(script, function () {
        scriptsLoaded++;
        if (scriptsLoaded === scripts.length) {
            resolvePolyfillIsReady();
        } else {
            loadNext();
        }
    });
}
loadNext();
