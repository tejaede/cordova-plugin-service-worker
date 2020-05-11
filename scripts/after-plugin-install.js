'use strict'
/* globals require, module */
const fs = require('fs');
const path = require("path");

const ASSET_DIR_PATH = "www/sw_assets",
      IOS_PLATFORM_PATH = "platforms/ios",
      SW_LOADER_SCRIPT_FILE_NAME = "load_sw.js",
      WEB_DIR_NAME = "www",
      PLATFORM_WEB_DIR_NAME = "platform_www";

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
        swLoaderScriptPath = path.join(pluginDir || iosBuildRoot, WEB_DIR_NAME, SW_LOADER_SCRIPT_FILE_NAME);

    return {
        pathToSWPolyfillAssets: assetsDir,
        pathToSWLoader: swLoaderScriptPath,
        targetSWLoaderPaths: [
            path.join(iosBuildRoot, WEB_DIR_NAME, SW_LOADER_SCRIPT_FILE_NAME),
            path.join(iosBuildRoot, PLATFORM_WEB_DIR_NAME, SW_LOADER_SCRIPT_FILE_NAME)
        ]
    };
}

module.exports = function(context) {
    const pluginContext = getPluginContext(context),
        srcSWLoaderScript = pluginContext.pathToSWLoader;

    pluginContext.targetSWLoaderPaths.forEach(function (targetFile) {
        copyFile(srcSWLoaderScript, targetFile);
    });
    return null;
}