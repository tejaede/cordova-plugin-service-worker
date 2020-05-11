window.isMainImportLoaded = true;
test(!isFirstDependencyLoaded(), "[Main] Dependency one is undefined before import");
test(!isSecondDependencyLoaded(), "[Main] Dependency two is undefined before import");
importScripts("mock/dependency-1.js");
test(isFirstDependencyLoaded(), "[Main] Dependency one is defined after import");
test(!isSecondDependencyLoaded(), "[Main] Dependency two is STILL undefined before import");
test(!isThirdDependencyLoaded(), "[Main] Dependency three is STILL undefined before import");
importScripts("mock/dependency-2.js");
test(isFirstDependencyLoaded(), "[Main] Dependency one is STILL defined after import");
test(isSecondDependencyLoaded(), "[Main] Dependency two is defined after import");
test(isThirdDependencyLoaded(), "[Main] Dependency three is defined after import");

var module = "mock/bundle-test-2.js";
importScripts(module);