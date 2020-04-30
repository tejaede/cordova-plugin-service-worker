MessageEvent = function(eventInitDict) {
  ExtendableEvent.call(this, 'message');
  this.target = window;
  if (eventInitDict) {
    if (eventInitDict.data) {
        var data = eventInitDict.data;
        Object.defineProperty(this, 'data', {value: eventInitDict.data, enumerable: true});
    }
    if (eventInitDict.origin) {
      Object.defineProperty(this, 'origin', {value: eventInitDict.origin});
    }
    if (eventInitDict.source) {
      Object.defineProperty(this, 'source', {value: eventInitDict.source});
    }
  }

};
MessageEvent.prototype = Object.create(Event.prototype);
MessageEvent.constructor = MessageEvent;