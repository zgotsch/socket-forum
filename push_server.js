var crypto = require('crypto')

function HMAC(message, secret) {
	var inner_padding = 0x8d;
	var outer_padding = 0x94;

	var inner_key = "";
	var outer_key = "";

	for(var i = 0; i < 256; i++) {
		var key_char = 0;
		if(i < secret.length) {
			key_char = secret.charCodeAt(i);
		}
		inner_key += String.fromCharCode(inner_padding ^ key_char);
		outer_key += String.fromCharCode(outer_padding ^ key_char);
	}

	var inner_hash = crypto.createHash('sha256').update(inner_key + message).digest("hex");
	return crypto.createHash('sha256').update(outer_key + inner_hash).digest("hex");
}

var fs = require('fs')
fs.readFile('shared_secret.key', 'ascii', function (err, secret) {
	if (err) {
		return console.log(err);
	}

	var io = require('socket.io').listen(80);

	io.sockets.on('connection', function (socket) {
		socket.on('new_post', function (data) {
			var hmac = HMAC(data.body, secret);
			if(hmac == data.post.auth) {
				socket.broadcast.emit('new_post', data);
			}
			else {
				console.log("Invalid auth code. Got: " + data.auth + " Expected: " + hmac);
			}
		});
	});
});
