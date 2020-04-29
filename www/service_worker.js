var ServiceWorker = function() {
    return this;
};

ServiceWorker.prototype.postMessage = function(message, targetOrigin) {
    // TODO: Validate the target origin.
    // Serialize the message.
    // var serializedMessage;
    // if (typeof message === "string") {
    //     serializedMessage = message;
    // } else {
        // serializedMessage = Kamino.stringify(message);
        // var serializedMessage = JSON.stringify(message);
        if (typeof message === "string") {
            serializedMessage = message;
        } else {
            serializedMessage = JSON.stringify(message);
        }
        console.log("ServiceWorker.postMessage", serializedMessage);

    // }

    // Send the message to native for delivery to the JSContext.
    cordova.exec(null, null, "ServiceWorker", "postMessage", [serializedMessage, targetOrigin]);
};
module.exports = ServiceWorker;

if (typeof cordova === 'undefined') {
    self.skipWaiting = function () {
        //TODO implement
    };
    self.serviceWorker = new ServiceWorker();
} else {

    window.restartWorker = function () {
        cordova.exec(null, null, "ServiceWorker", "restartWorker");
    };
}