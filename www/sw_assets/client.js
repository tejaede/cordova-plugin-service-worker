Clients = function(clientList) {
  this.clientList = clientList;
  return this;
};

Clients.prototype.claim = function () {
  return Promise.resolve(null);
};

// TODO: Add `options`.
Clients.prototype.getAll = function() {
  return this.clientList;
};

// TODO: Add `options`.
Clients.prototype.matchAll = function () {
  return Promise.resolve(this.clientList);
};

var clients = new Clients([]);

Client = function(url) {
  this.url = url;

  // Add this new client to the list of clients.
  clients.clientList.push(this);

  return this;
};

// TODO: Add `transfer`.
Client.prototype.postMessage = function(message) {
  postMessageInternal(Kamino.stringify(message));
};


postMessageInternal = function (message) {
  cordovaExec("postMessage", message);
};
