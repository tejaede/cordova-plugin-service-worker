const {
    xmlHelpers
} = require("cordova-common"),
    path = require("path"),
    fs = require("fs");

const cordovaWrapperRegexp = /^(cordova\.define\(\"cordova-plugin-service-worker\.\S*\",\s*function\(require,\sexports,\smodule\)\s*\{)\n(?:.*\n)*(\s*\}\);)$/m;
const cordovaBundledWrapperRegexp = /^(cordova\.define\(\"cordova-plugin-service-worker\.\S*\",\s*function\(require,\sexports,\smodule\)\s*\{)\n(?:.*\n)*(\s*\}\);)$/m;

class PluginModule {
    constructor(pluginName, pathToSource, moduleName) {
        this.pathToSource = pathToSource;
        this.pluginName = pluginName;
        this.moduleName = moduleName;
        this.targets = [];
    }

    syncAllTargets (context) {
        let self = this,
            content = fs.readFileSync(this.pathToSource, "utf8");

        return this.targets.map(function (target) {
            let base = target.isWeb ? context.web : path.join(context.iosBuild, "www"),
                absolute = path.join(base, target.path),
                // regexpString = '(cordova-plugin-service-worker\\.' + moduleName + '\\":\\[function\\(require,module,exports\\){\\s*\\n)(?:.*\\n)*\\s*(\\}\\,\\{)',
                // matcher = target.isBundled ? new RegExp(regexpString) : cordovaBundledWrapperRegexp;
                matcher = cordovaBundledWrapperRegexp;
            
            return self._syncTarget(absolute, content, matcher) && absolute;
        }).filter(function (value) {
            return value;
        });
    }

    _syncTarget (target, content, matcher) {
        let success = false;
        if (fs.existsSync(target)) {
            try {
                const targetContent = fs.readFileSync(target, "utf8");
                const match = matcher.exec(targetContent);
                let newContent;
                if (match) {
                  newContent = match[1] + "\n";
                  newContent += content + "\n";
                  newContent += match[2] + "\n";
                } else {
                  newContent = content;
                }
                fs.writeFileSync(target, newContent, "utf8");
                success = true;
              } catch (e) {
                console.warn("Failed to write content to " + target);
                console.warn(e);
              }
        }
        return success;
    }

    static withPluginNameSourcePathAndModuleName(pluginName, pathToSource, moduleName) {
        if (!PluginModule.modulesBySource[pathToSource]) {
            PluginModule.modulesBySource[pathToSource] = new PluginModule(pluginName, pathToSource, moduleName);
        }
        return PluginModule.modulesBySource[pathToSource];
    }

    static parseModulesWithPluginConfigurationAtPath(pathToConfiguration, isBundled) {
        const configuration = xmlHelpers.parseElementtreeSync(pathToConfiguration);
        const pluginName = configuration.getroot().attrib.id;
        const jsModules = configuration.findall("js-module");
        const assets = configuration.findall("asset");
        jsModules.forEach((jsModuleElement) => {
            /*
             
              Null means the file belongs under plugins/ in the build

              ^^^ If what is null???
            */
            const pathToModule = jsModuleElement.attrib.src,
                moduleName = jsModuleElement.attrib.name,
                module = PluginModule.withPluginNameSourcePathAndModuleName(pluginName, pathToModule, moduleName),
                pathToTarget = path.join("plugins", pluginName, pathToModule);

            module.targets = [new SyncTarget(pathToTarget, false)];
            if (isBundled && false) { //TODO finish support for bundled js
                module.targets.push(new SyncTarget("cordova.js", false));
                module.targets.push(new SyncTarget("cordova.js", true));
            } else {
                module.targets.push(new SyncTarget(pathToTarget, true));
            }
        });
        assets.forEach((assetElement) => {
            var pm = PluginModule.withPluginNameSourcePathAndModuleName(pluginName, assetElement.attrib.src, null);
            pm.targets.push(new SyncTarget(assetElement.attrib.target, false));
        });
    }
}

Object.defineProperty(PluginModule, "modulesBySource", {
    get() {
        if (!this._modulesBySource) {
            this._modulesBySource = {};
        }
        return this._modulesBySource;
    }
});

module.exports = PluginModule;

class SyncTarget {
    constructor(path, isWeb) {
        this.path = path;
        this.isWeb = isWeb;
    }
}