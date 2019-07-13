"use strict";
(function() {
	const call = Function.prototype.call;
	const urlConstructor = URL;
	var blacklist = $blacklist$;
	var preventDefault = Event.prototype.preventDefault;
	var indexOf = Array.prototype.indexOf;
	document.addEventListener("beforeload", function(event) {
		if (event.target.src) {
			Function.prototype.call = call;
			var url = new urlConstructor(event.target.src);
			if (event.target.nodeName == "SCRIPT" && ~indexOf.call(blacklist, url.hostname)) {
				preventDefault.call(event);
			}
		}
	}, true);
})();
