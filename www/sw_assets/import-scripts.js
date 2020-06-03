var globalEval = eval;
var importScriptsRegexp = /importScripts\(['"]([^\"\'\)]*)['"]\)/g;
function parseDependencies(responseText) {
    var matches = responseText.matchAll(importScriptsRegexp),
        scripts = [], match;    
    while ((match = matches.next().value)) {
        scripts.push(match[1]);
    }
    return scripts;
}

var scriptsByPath = {};
function preImportScripts(src) {
    var req = new Request(src, {
        headers: {
            "x-import-scripts": true
        }
    });
    return window.fetch(req).then(function (response) {
        return response.text();
    }).then(function (text) {
        var dependencies = parseDependencies(text);
        scriptsByPath[src] = text;
        return Promise.all(dependencies.map(function (dependency) {
            return preImportScripts(dependency);
        })).then(function () {
            return text;
        });
    });
}

function evaluateScript(script, name) {
    try {
        globalEval(script);
    } catch (e) {
        console.error("Failed to evaluate javascript: " + name);
        console.error(e);
    }
}

window.importScripts = function (src) {
    if (scriptsByPath[src]) {
        evaluateScript(scriptsByPath[src], src);
    } else {
        //This should only happen on the initial script
        return this.preImportScripts(src).then(function (text) {
            evaluateScript(text);
        });
    }
};