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
            messages[messageId] = {
                action: action,
                callback: callback
            };
            parameters.messageId = messageId;
            try {
                handlerForAction.postMessage(parameters);
            } catch (e) {
                console.error("cordovaExec failed on action: " + action);
                console.error(e);
                callback(null, e);
            }
            
        } else {
            console.error("Failed to execute '" + action + "' because it does not exist in window.webkit.messageHandlers");
        }
    };

    window.cordovaCallback = function (messageId, parameters, error) {
            var handler = messages[messageId],
                callback = handler && handler.callback;
            try {
                if (callback) {
                    callback(parameters, error);
                    delete messages[messageId];
                }
            } catch (e) {
                console.error("cordovaCallback failed on action: " + (handler && handler.action));
                console.error(e);
            }
    };
})();
