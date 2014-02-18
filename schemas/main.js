var schema = require("./remote-calculator");
var MainInterface = schema.Main;

var client = new MainInterface.Client({
	multiplied: function(lhs, rhs, result) {
	
	}
});

var server = new MainInterface.Server({
	multiply: function(socket, lhs, rhs, callback) {
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
		this.muliplied(socket, lhs, rhs, result);
	}
});