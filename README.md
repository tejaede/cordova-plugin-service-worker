# Service Worker Plugin for iOS

This plugin adds [Service Worker](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API) support to Cordova apps on iOS.  To use it:

1. Install this plugin.
2. Place the service worker file is placed at the root directory of your application. This is true for applications run locally in the cordova app and applications run on remote web servers. For example:
   * The file is named `cache-worker.js` and the application is run internally. The file should be placed at ``your-cordova-app/www/cache-worker.js`
   * The file is named `offline-worker.js` and the application is pointed to `https://example.com/path/to/application/`. The file should be placed at `https://example.com/path/to/application/cache-worker.js`
3. Place the service worker shell at the root directory of your application. The plugin creates a second browser window from which to run the service worker. 
4. Set the `RemoteApplicationURL` in the config.xml
5. Set the `CordovaWebViewEngine` to `CDVSWWKWebViewEngine`

   ```xml
   <preference name="RemoteApplicationURL" value="https://example.com/path/to/application/" />
   <preference name="CordovaWebViewEngine" value="CDVSWWKWebViewEngine" />
   ```
6. Add white entries for the custom url scheme. That is either the value of `ServiceWorkerUrlScheme` or `cordova-sw`
```xml
    <!-- With default url scheme -->
    <access origin="cordova-sw://*" />
    <allow-navigation href="cordova-sw://*" />
```
```xml
    <preference name="ServiceWorkerUrlScheme" value="acme-service-worker" />
    <!-- With custom url scheme -->
    <access origin="acme-service-worker://*" />
    <allow-navigation href="acme-service-worker://*" />
```
That's it!  Your calls to the ServiceWorker API should now work.


## How it works
- A supplemental browser window is opened in the background to act as the service worker thread. This window is called the "shell" throughout this documentation. The Service Worker API in the shell routes javascript calls to native functions like in the usual cordova fashion

- The main web app is loaded with a custom URL scheme so http requests can be intercepted and routed to the service worker thread. As will be noted below, this means the service worker shell is loaded with the same custom URL scheme. 

## config.xml
| Name                   | Required | Default     | Description                                                                                                                                                                                                                                                                                                   |
|------------------------|----------|-------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| CordoveWebViewEngine   | Yes      | n/a         | This value MUST be set to CDVSWWKWebViewEngine                                                                                                                                                                                                                                                                |
| RemoteApplicationUrl   | Yes      | n/a         | The remote location of the web app. If a full path is not provided, the target file is assumed to be `index.html`. For example, https://example.com/path/to/application/ is to load https://example.com/path/to/application/index.html                                                      |
| ServiceWorkerShell     | No       | sw.html     | The name of the html file at the root of the web app that should be loaded into the shell. For example, if RemoteApplicationUrl = https://example.com/path/to/application/ and ServiceWorkerShell = service-worker.html, the shell is loaded from https://example.com/path/to/application/service-worker.html |
| ServiceWorkerUrlScheme | No       | cordova-sw  | The URL scheme used to load both the main web application and the service worker shell.                                                                                                                                                                                                                       |
| MinPeriod              | No       | (1 Hour)    | The minimum amount of time between repetitions of a periodic sync                                                                                                                                                                                                                                             |
| SyncPushBack           | No       | (5 Minutes) | The minimum amount of time a viable one-off or periodic sync will wait after failing before being reassessed                                                                                                                                                                                                  |
| SyncMaxWaitTime        | No       | (2 Hours)   | The maximum amount of time past the expiration of its minimum period that a periodic sync event will wait to be batched with other periodic sync events.  

```xml
<preference name="ServiceWorkerShell" value="service-worker.html" />
<preference name="ServiceWorkerUrlScheme" value="cordova-service-worker" />
<preference name="RemoteApplicationURL" value="https://example.com/path/to/application/" />
<preference name="minperiod" value="2000"></preference>
<preference name="syncpushback" value="1200"></preference>
<preference name="syncmaxwaittime" value="5000"></preference>
```


## Cordova Asset Cache

This plugin automatically creates a cache (called `Cordova Assets`) containing all of the assets in your app's `www/` directory.

To prevent this automatic caching, add the following preference to your config.xml file:

```
<preference name="CacheCordovaAssets" value="false" />
```

## Examples

One use case is to check your caches for any fetch request, only attempting to retrieve it from the network if it's not there.

```javascript
self.addEventListener('fetch', function(event) {
    event.respondWith(
        // Check the caches.
        caches.match(event.request).then(function(response) {
            // If the response exists, return it; otherwise, fetch it from the network.
            return response || fetch(event.request);
        })
    );
});
```

Another option is to go to the network first, only checking the cache if that fails (e.g. if the device is offline).

```javascript
self.addEventListener('fetch', function(event) {
    // If the caches provide a response, return it.  Otherwise, return the original network response.
    event.respondWith(
        // Fetch from the network.
        fetch(event.request).then(function(networkResponse) {
            // If the response exists and has a 200 status, return it.
            if (networkResponse && networkResponse.status === 200) {
                return networkResponse;
            }

            // The network didn't yield a useful response, so check the caches.
            return caches.match(event.request).then(function(cacheResponse) {
                // If the cache yielded a response, return it; otherwise, return the original network response.
                return cacheResponse || networkResponse;
            });
        })
    );
});
```

## Caveats

* Having multiple Service Workers in your app is unsupported.
* Service Worker uninstallation is unsupported.
* IndexedDB is unsupported.

## Release Notes

### 1.0.1

* Significantly enhanced version numbering.

### 1.0.0

* Initial release.
