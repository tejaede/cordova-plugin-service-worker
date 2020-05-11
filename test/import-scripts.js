function test(condition, name) {
    if (!condition) {
        console.error("Failed: " + name);
    } else {
        console.log("PASS: " + name);
    }
}
function isMainLoaded() {
    return !!window.isMainImportLoaded;
}
function isFirstDependencyLoaded() {
    return !!window.isDependencyOneLoaded;
}
function isSecondDependencyLoaded() {
    return !!window.isDependencyTwoLoaded;
}
function isThirdDependencyLoaded() {
    return !!window.isDependencyThreeLoaded;
}
test(!isFirstDependencyLoaded(), "[Root] Dependency one is undefined before import");
test(!isSecondDependencyLoaded(), "[Root] Dependency two is undefined before import");
test(!isThirdDependencyLoaded(), "[Root] Dependency three is undefined before import");
test(!isMainLoaded(), "[Root] Main is undefined before import");
importScripts("mock/main-import.js").then(function () {
    test(isFirstDependencyLoaded(), "[Root] Dependency one is defined after import");
    test(isSecondDependencyLoaded(), "[Root] Dependency two is defined after import");
    test(isThirdDependencyLoaded(), "[Root] Dependency three is defined after import");
    test(isMainLoaded(), "[Root] Main is defined after import");
});
