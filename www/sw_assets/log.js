(function () {
    var toOverride = ["log", "error", "warn"];

    function stringifyArguments(args) {
        for (var i = 0, n = args.length; i < n; ++i) {
            if (typeof args[i] == "object") {
                try {
                    args[i] = JSON.stringify(args[i], null, 2);
                } catch(e) {
                    args[i] = altStringify(args[i]);
                }
            }
        }
        return args;
    }
    function altStringify(item) {
        var keys = Object.keys(item),
            string = "{\n",
            indent = "   ";
        keys.forEach(function (key) {
            string += indent;
            string += key;
            string += ": ";
            string += item[value];
            string += ",";
            string += "\n";
        });
        string += "}\n";
        return string;
    }
    function override(name) {
        var orig = console[name],
            tag = "[" + name + "]";
        console[name] = function () {
            var args = Array.from(arguments);
            args = stringifyArguments(args);
            args.unshift(tag);
            window.webkit.messageHandlers.log.postMessage(args.join(' '));
            orig.apply(console, arguments);
        };
    }
    toOverride.forEach(function (name) {
        override(name);
    });
})();