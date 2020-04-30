var globalEval = eval;
window.importScripts = importScripts = function importer() {

    var urls = [].slice.call(arguments).filter(function (arg) {
        return (typeof arg === 'string');
    });
    // Sync get each URL and return as one string to be eval'd.
    // These requests are done in series. TODO: Possibly solve?
    return urls.map(function(url) {
        var absoluteUrl = URL.absoluteURLfromMainClient(url),
            xhr = new XMLHttpRequest();
        xhr.open('GET', absoluteUrl, false);
        xhr.setRequestHeader("x-import-scripts", "true");
        xhr.send(null);
        xhr.status = parseInt(xhr.status, 10);
        if (xhr.status === 200) {
            try {
                globalEval(xhr.responseText);
            } catch (e) {
                console.error("Faild to evaluate javascript: " + url);
                console.error(e);
            }
            
            return xhr.responseText;
        } else {
            throw new Error('Network error while calling importScripts() (code: '+ xhr.status + ", url: " + absoluteUrl + ")");
        }
    });
};
