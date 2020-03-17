polyfillIsReady.then(function () {
    var el = document.createElement("script"),
    src = "{{SERVICE_WORKER_PATH}}";
    el.setAttribute("type", "text/javascript");
    el.setAttribute("src", src);
    head.appendChild(el);
});