/**
 * Just add this script as `after_build` and `after_prepare` hook in config.xml for ios platform.
 */

var join = require('path').join;
var fs = require('fs');

// TODO: Remove this after https://issues.apache.org/jira/browse/CB-11311 is fixed
module.exports = function(ctx) {
  if (!ctx.opts.browserify) {
    return;
  }

  var pathToCordova = join(ctx.opts.projectRoot, 'platforms', 'ios', 'www', 'cordova.js');
  var content = fs.readFileSync(pathToCordova, 'utf8');
  var newContent = fixWkWebView(content);
  newContent = fixAdvancedHttp(newContent);


  fs.writeFileSync(pathToCordova, newContent, 'utf8');
  console.info('patched browserified build. Fix exec override for iOS WKWebView');


  function fixWkWebView(content) {
    if (content.indexOf('"cordova/exec.o"') !== -1) {
      console.info('skip wkwebview patch because file is already patched');
      return content;
    }

    return content.replace(/"cordova\/exec":\[function/, `
    "cordova/exec":[function(require,module){
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cordova && window.webkit.messageHandlers.cordova.postMessage) {
          module.exports = require("cordova-plugin-wkwebview-engine.ios-wkwebview-exec");
        } else {
          module.exports = require("cordova/exec.o");
        }
    },{"cordova/exec.o":"cordova/exec.o", "cordova-plugin-wkwebview-engine.ios-wkwebview-exec":"cordova-plugin-wkwebview-engine.ios-wkwebview-exec"}],
    "cordova/exec.o":[function`)
    .replace(/(module\.exports\s*=\s*[^;]+;\s*)if\s*\(window\.webkit && window\.webkit\.messageHandlers &&/, '$1/* disabled by hook */ if (0 && window.webkit && window.webkit.messageHandlers &&')

  }

  function fixAdvancedHttp(content) {
    if (content.indexOf("module.id.slice(0, module.id.indexOf('.'))") === -1) {
      console.info('skip advanced http patch because file is already patched');
      return content;
    }

    return content.replace(/module\.id\.slice\(0\, module\.id\.indexOf\(\'\.\'\)\)/g, '"cordova-plugin-advanced-http"');
  }

  
}
