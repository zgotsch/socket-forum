var socket = io.connect(':1234/');

function displayPost(post) {
	$('#post_container').prepend(
		post.html
	);
}

function addPost(post) {
	//notify
	var target = window.location
	var d = $.post(target, {'post': post}, function(data) {
		//data = $.parseJSON(data);
		if(data == null || data.status != 'success') {
			console.log("There was an error: " + data);
		}
		else {
			socket.emit('new_post', data.post);
			displayPost(data.post);
		}
	}, 'json');
}

socket.on('new_post', function(post) { displayPost(post); });

$(document).ready(function() {
	$("#new_post").submit(function() {
		addPost({'new_post': $("#new_post_body").val()});
		return false;
	});
});

