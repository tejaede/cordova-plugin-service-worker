try {
    var method = '%@',
        url = "%@",
        headers = %@;
    dispatchEvent(new FetchEvent({request:Request.create(method, url, headers), id:'%lld'}));
} catch (e) {
    console.warn("Failed to send fetch event for url:" + url);
    console.warn(e);
}
'';  //Prevents WKWebView evaluateJavascript from throwing warning

