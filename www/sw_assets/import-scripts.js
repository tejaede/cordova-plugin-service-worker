var globalEval = eval;
var importScriptsRegexp = /importScripts\(['"]([^\"\'\)]*)['"]\)/g;
function parseDependencies(responseText, debug) {
    var matches = responseText.matchAll(importScriptsRegexp),
        scripts = [], match;    
    while ((match = matches.next().value)) {
        scripts.push(match[1]);
    }
    return scripts;
}

var scriptsByPath = {};
function preImportScripts(src) {
    return window.fetch(src).then(function (response) {
        return response.text();
    }).then(function (text) {
        var dependencies = parseDependencies(text, src.indexOf("bundle") !== -1);
        scriptsByPath[src] = text;
        return Promise.all(dependencies.map(function (dependency) {
            return preImportScripts(dependency);
        })).then(function () {
            return text;
        });
    });
}

window.collected = {};
//[TJ] This allows one to collect scripts "imported" with a 
// variable, but it's brittle.
function collectImports(text) {
    var script = `(function () {
        window.importScripts = function (src) {
            window.collected[src] = true;
        };
        ${text};
    })()`;
    try {
        globalEval(script);
    } catch (e) {
        console.error(e);
    }
    console.log(window.collected);
    debugger;
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