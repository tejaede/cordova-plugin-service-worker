### Build
If the app build fails due to 'file not found' on 'CDVWebViewProcessPoolFactory.h'


1. In `CDVSWWKWebViewEngine.sh` Change import of `#import CDVWebViewProcessPoolFactory.h` to `#import <Cordova/CDVWebViewProcessPoolFactory.h>`
2. In Xcode, open CordovaLib -> Build Phases -> CordovaLib Framework target (might be other target)
3. Under Headers -> Private, find CDVWebViewEngine. Right click and select "Move to Public"
4. In XCode, open `CordovaLib/Private/Plugins/CDVWebViewEngine.h` and add `- (WKWebViewConfiguration*) createConfigurationFromSettings:(NSDictionary*)settings;` to the interface
5. https://stackoverflow.com/questions/24298144/duplicate-symbols-for-architecture-x86-64-under-xcode



### Runtime
#### Preprocessor Macros
1. CordovaPluginServiceWorker uses Preprocessor Macros to enable additional debugging features
    1. To enable/disable Macros,
        1. Select DisasterAlert in the project navigator
        2. Select the DisasterAlert target
        3. Select the info tab
        4. Under Apple Clang - Preprocessing -> Preprocessor Macros, open "Debug" (Never "Release");
    2. The available debugging entries are:
        2. `DEBUG_JAVASCRIPT` - Has 2 functions
            1. Adds logging to the javascript in cordova-plugin-service-worker
            2. Loads the javascript for cordova-plugin-service-worker with script tags which allows you to debug it in the web inspector
            
        3. `DEBUG_CACHE` - Additional logging for the Cache API polyfill in cordova-plugin-service-worker
        4. `DEBUG_SCHEME_HANDLER` - Additional logging for the custom url scheme handler in cordova-plugin-service-worker
    3. Note that these can have a dramatic impact on performance so they should only be enabled when needed and NEVER enabled on the Release macros


#### HTTP Requests Hanging or Failing
If http requests in the main webview are hanging or failing unexpectedly, it may be due to an error in the service worker webview. To debug this
1. Enable `DEBUG_JAVASCRIPT` in the Preprocessor Macros as described above
2. Add a breakpoint just before the assets are loaded into the webview in `CDVServiceWorker.loadServiceWorkerAssetsIntoContext`
```objective-c
- (void)loadServiceWorkerAssetsIntoContext
    
    ## Function code removed for brevity.  
    
    ## ADD A BREAKPOINT HERE ##
    if (useScriptTags) {
        [self loadServiceWorkerAssetsInContextWithScriptTags:baseSWAssetFileNames supplementary:supplementarySWAssetFileNames];
    } else {
        [self evaluateServiceWorkerAssetsInContextDirectly:baseSWAssetFileNames supplementary:supplementarySWAssetFileNames];
    }
```

3. Run the app and wait for the breakpoint to be hit
4. Open the web inspector for `sw.html`
5. Continue past the breakpoint