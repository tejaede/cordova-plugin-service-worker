window.isDependencyTwoLoaded = true;
test(!isThirdDependencyLoaded(), "[Dep2] Dependency three is undefined before import");
importScripts("mock/dependency-3.js");
test(isThirdDependencyLoaded(), "[Dep2] Dependency three is defined after import");
// importScripts("mock/bundle-test.js");
// importScripts("mock/bundle-test-2.js");
importScripts("mock/bundle-test-3.js");
