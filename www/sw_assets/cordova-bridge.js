(function () {
    var messageHandlers = window.webkit.messageHandlers,
        messages = {},
        _id = 0;
    function nextMessageId() {
        _id++;
        return _id;
    }
    window.cordovaExec = function (action, parameters, callback) {
        var handlerForAction = messageHandlers[action],
            messageId;

        if (handlerForAction) {
            messageId = nextMessageId();
            messages[messageId] = callback;
            parameters.messageId = messageId;
            handlerForAction.postMessage(parameters);
        } else {
            console.error("Failed to execute '" + action + "' because it does not exist in window.webkit.messageHandlers");
        }
    };

    window.cordovaCallback = function (messageId, parameters, error) {
        var callback = messages[messageId];
        console.log("cordovaCallback", messageId, parameters, error);
        if (callback) {
            callback(parameters, error);
            delete messages[messageId];
        }
    };
})();

