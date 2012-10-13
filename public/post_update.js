var socket = io.connect(':1234/');

function displayPost(post) {
	new_div = $(post.html);
	new_div.css('display', 'none');
	$('#post_container').prepend(new_div);
	var new_div_final_height = new_div.height();
	new_div.css('height', 0);
	new_div.css('opacity', 0);
	new_div.css('display', 'block');
	new_div.animate({
		opacity: 1,
		height: new_div_final_height
	}, 500);
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

