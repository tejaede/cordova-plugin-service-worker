var message = '%@';
try {
    message = window.atob(message);
    message = JSON.parse(message);
} catch (e) {
}
dispatchEvent(new MessageEvent({data:message}));'';