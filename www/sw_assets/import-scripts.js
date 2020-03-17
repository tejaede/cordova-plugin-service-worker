var globalEval = eval;
window.importScripts = importScripts = function importer(workerUrl) {

    var urls = [].slice.call(arguments).filter(function (arg) {
        return (typeof arg === 'string');
    });

    // Sync get each URL and return as one string to be eval'd.
    // These requests are done in series. TODO: Possibly solve?
    return urls.map(function(url) {
        var baseURL = window.baseImportURL || window.location.href,
            absoluteUrl = new URL(url, baseURL),
            xhr = new XMLHttpRequest();
        xhr.open('GET', absoluteUrl, false);
        xhr.send(null);
        xhr.status = parseInt(xhr.status, 10);
        if (xhr.status === 200) {
            globalEval(xhr.responseText);
            return xhr.responseText;
        } else {
            console.log('Status:', xhr.status);
            console.log('URL:', absoluteUrl.toString());
            throw new Error('Network error while calling importScripts()');
        }
    });
};
