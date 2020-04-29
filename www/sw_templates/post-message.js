var message = '%@';
try {
    message = window.atob(message);
    message = JSON.parse(message);
} catch (e) {
    console.warn("Failed to parse post message");
}
dispatchEvent(new MessageEvent({data:message}));'';