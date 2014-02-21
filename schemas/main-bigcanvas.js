var schema = require("./bigcanvas");
var MainInterface = schema.Main;

//setup
var client = new MainInterface.ClientStub({
	//route outgoing messages to the server
	send: function(object) { server.receive(0, object); },
	//event implementations
});

var server = new MainInterface.ServerStub({
	//route outgoing messages to a client
	send: function(socketId, object) { client.receive(object); },
	//function implementations
	sendAction: function(socketId, action, callback) {
		callback(null, "1");
	}
});

//tests
client.sendAction({
	$type: "UndoAction"
}, function(err, actionId) {
	if(err)
		console.log("error: "+err.message);
	else
		console.log("actionId="+actionId);
});