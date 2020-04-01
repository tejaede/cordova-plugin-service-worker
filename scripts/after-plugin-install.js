'use strict';
/* globals require, module */
const fs = require('fs');
const path = require("path");

const ASSET_DIR_PATH = "www/sw_assets",
      IOS_PLATFORM_PATH = "platforms/ios",
      POLYFILL_LOADER_SCRIPT_FILE_NAME = "load_sw_assets.js",
      SW_LOADER_SCRIPT_FILE_NAME = "load_sw.js",
      WEB_DIR_NAME = "www",
      PLATFORM_WEB_DIR_NAME = "platform_www";

const SERVICE_WORKER_ASSETS_TOKEN_REGEXP = /\n(\s*){{SERVICE_WORKER_ASSETS}}/;


function readDir(pathToDir) {
    return new Promise(function (resolve, reject) {
        fs.readdir(pathToDir, function (error, data) {
            if (error) {
                reject(error);
            } else {
                resolve(data);
            }
        });
    });
}

function copyFile(src, destination) {
    if (fs.existsSync(destination)) {
        fs.unlinkSync(destination);
    }
    fs.writeFileSync(destination, fs.readFileSync(src, "utf8"));
}

function pluginDirectory(context) {
    const options = context.opts,
        plugin = options && options.plugin;
    return plugin && plugin.dir;
}


function getPluginContext(buildContext) {
    var iosBuildRoot = path.join(buildContext.opts.projectRoot, IOS_PLATFORM_PATH),
        assetsDir = path.join(iosBuildRoot, ASSET_DIR_PATH),
        pluginDir = pluginDirectory(buildContext),
        polyfillLoaderScriptPath = path.join(pluginDir || iosBuildRoot, WEB_DIR_NAME, POLYFILL_LOADER_SCRIPT_FILE_NAME),
        swLoaderScriptPath = path.join(pluginDir || iosBuildRoot, WEB_DIR_NAME, SW_LOADER_SCRIPT_FILE_NAME);

    return {
        pathToSWPolyfillAssets: assetsDir,
        pathToPolyfillLoader: polyfillLoaderScriptPath,
        pathToSWLoader: swLoaderScriptPath,
        targetPolyfillLoaderPaths: [
            path.join(iosBuildRoot, WEB_DIR_NAME, POLYFILL_LOADER_SCRIPT_FILE_NAME),
            path.join(iosBuildRoot, PLATFORM_WEB_DIR_NAME, POLYFILL_LOADER_SCRIPT_FILE_NAME)
        ],
        targetSWLoaderPaths: [
            path.join(iosBuildRoot, WEB_DIR_NAME, SW_LOADER_SCRIPT_FILE_NAME),
            path.join(iosBuildRoot, PLATFORM_WEB_DIR_NAME, SW_LOADER_SCRIPT_FILE_NAME)
        ]
    };
}

function readAndNormalizePolyfillAssets(assetsDir, indent) {
    return readDir(assetsDir).then(function (assets) {
        return assets.map(function (assetPath) {
            return indent + "'" + assetPath + "'";
        });
    });
}

function replaceTokensInLoader(loaderContent, assetArray) {
    return loaderContent.replace(SERVICE_WORKER_ASSETS_TOKEN_REGEXP, "\n" + assetArray.join(",\n"));
}

module.exports = function(context) {
    const pluginContext = getPluginContext(context),
        assetsDir = pluginContext.pathToSWPolyfillAssets,
        srcPolyfillLoaderScript = pluginContext.pathToPolyfillLoader,
        srcSWLoaderScript = pluginContext.pathToSWLoader,
        srcLoaderContent = fs.readFileSync(srcPolyfillLoaderScript, "utf8"),
        match = SERVICE_WORKER_ASSETS_TOKEN_REGEXP.exec(srcLoaderContent),
        indent = match && match[1] || "";

    return readAndNormalizePolyfillAssets(assetsDir, indent).then(function (assets) {
        var content = replaceTokensInLoader(srcLoaderContent, assets.filter(function (assetPath) {
            return assetPath.indexOf(".js") !== -1;
        }));
        pluginContext.targetPolyfillLoaderPaths.forEach(function (targetFile) {
            fs.writeFileSync(targetFile, content, "utf8");
        });
        pluginContext.targetSWLoaderPaths.forEach(function (targetFile) {
            copyFile(srcSWLoaderScript, targetFile);
        });
        return null;
    });
}