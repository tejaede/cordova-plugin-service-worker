### Build
If the app build fails due to 'file not found' on 'CDVWebViewProcessPoolFactory.h'


1. In `CDVSWWKWebViewEngine.sh` Change import of `#import CDVWebViewProcessPoolFactory.h` to `#import <Cordova/CDVWebViewProcessPoolFactory.h>`
2. In Xcode, open CordovaLib -> Build Phases -> CordovaLib Framework target (might be other target)
3. Under Headers -> Private, find CDVWebViewEngine. Right click and select "Move to Public"
4. In XCode, open `CordovaLib/Private/Plugins/CDVWebViewEngine.h` and add `- (WKWebViewConfiguration*) createConfigurationFromSettings:(NSDictionary*)settings;` to the interface
5. https://stackoverflow.com/questions/24298144/duplicate-symbols-for-architecture-x86-64-under-xcode