(function (user, pw) {
	function iterateFrames(target, callback) {
		var result = null;
		var frames = target.querySelectorAll("iframe");
		for (var i = 0; i < frames.length; i++) {
			var doc = frames[i].contentDocument;
			if (!doc) continue;
			if (doc.origin != document.origin) continue;
			if ((result = callback(doc))) break;
		}
		return result;
	}
	
	function findPWField(target) {
		var pwfield = null;
		if (!(pwfield = target.querySelector("input[type='password']"))) pwfield = iterateFrames(target, findPWField);
		return pwfield;
	}
	
	function queryUserField(target) {
		var userqueries = ["input[type='text']#user", "input[type='text']#username", "input[type='text']#user_name", "input[type='text'][name='user']", "input[type='text'][name='username']", "input[type='text'][name='user_name']","input[type='email']","input[type='text']"];
		var userfield = null;
		for (var i = 0; i < userqueries.length; i++) {
			var query = userqueries[i];
			if ((userfield = target.querySelector(query))) break;
		}
		return userfield;
	}
	
	function findUserField(target) {
		var userfield = null;
		if (!(userfield = queryUserField(target))) userfield = iterateFrames(target, findUserField);
		return userfield;
	}
	
	var pwfield = findPWField(document);
	var userfield = null;
	if (pwfield && pwfield.form) userfield = findUserField(pwfield.form);
	if (!userfield) userfield = findUserField(document);
	if (pwfield) pwfield.value = pw;
	if (userfield) userfield.value = user;
})($user$, $pw$);
