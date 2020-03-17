var head = document.querySelector("head"),
    scripts = [
        "www/sw_assets/asset-a.js",
        "www/sw_assets/asset-b.js",
        "www/sw_assets/asset-c.js",
        "www/sw_assets/asset-d.js"
    ];

function loadServiceWorker() {
    var el = document.createElement("script"),
    src = "www/sw.js";
    el.setAttribute("type", "text/javascript");
    el.setAttribute("src", src);
    head.appendChild(el);
}
var scriptsLoaded = 0;
function loadScript(script) {
   var el = document.createElement("script"),
       src = "www/sw_assets/" + script;
   el.setAttribute("type", "text/javascript");
   el.setAttribute("src", src);
   el.onload = function () {
       scriptsLoaded++;
       if (scriptsLoaded === scripts.length) {
          loadServiceWorker();
       }
   };
   head.appendChild(el);
}

scripts.forEach(function (script) {
    loadScript(script);
});
