const path = require("path");
const fs = require('fs');

const afterPluginInstall = require("../scripts/after-plugin-install");

const ApplicationRoot = path.join(process.cwd(), "test");

const mockContext = {
    opts: {
        projectRoot: ApplicationRoot,
        plugin: {
            dir: path.join(ApplicationRoot, "..")
        }
    }
};

const WORKING_DIR = process.cwd();

var PLATFORM_BUILD_PATH = path.join(ApplicationRoot, "platforms/ios"),
    SRC_LOADER_PATH = path.join(ApplicationRoot, "..", "www","load_sw_assets.js"),
    TARGET_WWW_DIR = path.join(PLATFORM_BUILD_PATH, "www"),
    TARGET_PLATFORM_WWW_DIR = path.join(PLATFORM_BUILD_PATH, "platform_www"),
    TARGET_LOADER_PATHS = [
        path.join(TARGET_WWW_DIR, "load_sw_assets.js"),
        path.join(TARGET_PLATFORM_WWW_DIR,"load_sw_assets.js"),
    ],
    MOCK_ASSETS_PATH = path.join(ApplicationRoot, "mock_sw_assets"),
    APP_ASSETS_PATH = path.join(PLATFORM_BUILD_PATH, "sw_assets");

function prepareTestApplication() {
    var mockAssets;

    touchDir(APP_ASSETS_PATH);
    touchDir(TARGET_WWW_DIR);
    touchDir(TARGET_PLATFORM_WWW_DIR);
    TARGET_LOADER_PATHS.forEach(function (filePath) {
        deleteFile(filePath);
    });
    mockAssets = fs.readdirSync(MOCK_ASSETS_PATH);
    mockAssets.forEach(function (asset) {
        copyFile(path.join(MOCK_ASSETS_PATH, asset), path.join(APP_ASSETS_PATH, asset));
    });
}
    

console.log("****** Prepare*********");
prepareTestApplication();
console.log("****** Run *********");
afterPluginInstall(mockContext).then(function () {
    test(areTokensRemoved(), "Tokens Removed");
    console.log("****** Clean up *********");
}).catch(function (e) {
    console.error(e);
    process.exit(0);
});





function areTokensRemoved() {
    var message = [];
    TARGET_LOADER_PATHS.forEach(function (filePath) {
        var content;
        if (!fs.existsSync(filePath)) {
            message.push("File does not exist: " + filePath);
        } else {
            content = fs.readFileSync(filePath, "utf8");
            if (content.indexOf("SERVICE_WORKER_PATH") !== -1) {
                message.push("SERVICE_WORKER_PATH exists in " + filePath);
            }
            if (content.indexOf("SERVICE_WORKER_ASSETS") !== -1) {
                message.push("SERVICE_WORKER_ASSETS exists in " + filePath);
            }
        }
    });
    return message.length ? message.join("\n") : undefined;
}


function test(failMessage, name) {
    var result = failMessage ? "FAIL" : "SUCCESS";
    console.log("[Spec] " + result + ": " + name);
    if (failMessage) {
        console.log(failMessage);
    }
}


function normalizePath(_path) {
    return _path.replace(WORKING_DIR, "").replace(/^\//, "");
}
var isDebugging = false;
function log() {
    if (isDebugging) {
        console.log.apply(console, arguments);
        console.log("");
    }

}

function copyFile(src, destination) {
    if (fs.existsSync(destination)) {
        log("Deleting www/load_sw_assets.js");
        fs.unlinkSync(destination);
    }
    log("Copying \n      source: "  + normalizePath(src) + " \n destination: " + normalizePath(destination));
    fs.writeFileSync(destination, fs.readFileSync(src, "utf8"));
}

function touchDir(filePath) {
    var parts = filePath.split("/"),
        builder = "";

    if (parts.length && !parts[0]) {
        parts = parts.slice(1);
    }
    parts.forEach(function (part) {
        builder += "/" + part;
        _touchDir(builder);
    });
}


function _touchDir(filePath) {
    if (!fs.existsSync(filePath)) {
        log("Creating " + normalizePath(filePath));
        fs.mkdirSync(filePath);
    }
}

function deleteFile(filePath) {
    if (fs.existsSync(filePath)) {
        log("Deleting " + normalizePath(filePath));
        fs.unlinkSync(filePath);
    }
}
