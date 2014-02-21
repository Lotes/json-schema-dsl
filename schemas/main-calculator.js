var schema = require("./remote-calculator");
var MainInterface = schema.Main;

//setup
var client = new MainInterface.ClientStub({
	//route outgoing messages to the server
	send: function(object) { server.receive(0, object); },
	//event implementations
	multiplied: function(lhs, rhs, result) {
		console.log("someone multiplied two matrices...");
	}
});

var server = new MainInterface.ServerStub({
	//route outgoing messages to a client
	send: function(socketId, object) { client.receive(object); },
	//function implementations
	multiply: function(socketId, lhs, rhs, callback) {
		console.log("server: incoming multiply request...");
		console.log("server: lhs="+JSON.stringify(lhs));
		console.log("server: rhs="+JSON.stringify(rhs));
		var result = [
			[0,0,0],
			[0,0,0],
			[0,0,0]
		];
		for(var i=0; i<3; i++)
		  for(var j=0; j<3; j++)
		    for(var k=0; k<3; k++)
				result[i][j] += lhs[i][k] * rhs[k][j];
		callback(null, result);
		console.log("server: multiply request callback...");
		this.multiplied(socketId, lhs, rhs, result);
		console.log("server: multiply request succeeded...");
	}
});

//tests
var a = [
	[1, 2, 3],
	[4, 5, 6],
	[7, 8, 9]
];
var b = [
	[1, 1, 1],
	[0, 1, 1],
	[0, 0, 1]
];

client.multiply(a, b, function(err, result) {
	if(err)
		console.log("client: error: "+err.message);
	else
		console.log("client: result="+JSON.stringify(result));
});