var schema = require("./remote-calculator");
var MainInterface = schema.Main;

//setup
var client = new MainInterface.Client({
	connect: function() {},
	disconnect: function() {},
	send: function(object) { server.receive(0, object); },
	multiplied: function(lhs, rhs, result) {
		console.log("someone multiplied two matrices...");
	}
});

var server = new MainInterface.Server({
	connect: function(socketId) {},
	disconnect: function(socketId) {},
	send: function(socketId, object) { client.receive(object); },
	multiply: function(socketId, lhs, rhs, callback) {
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
		this.muliplied(socketId, lhs, rhs, result);
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
		console.log("ERROR: "+err.message);
	else
		console.log(result);
});