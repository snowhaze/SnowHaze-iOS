"use strict";
(function() {
	var blacklist = $blacklist$;
	var preventDefault = Event.prototype.preventDefault;
	var indexOf = Array.prototype.indexOf;
	document.addEventListener("beforeload", function(event) {
		if (event.target.src) {
			var url = new URL(event.target.src);
			if (event.target.nodeName == "SCRIPT" && ~indexOf.call(blacklist, url.hostname)) {
				preventDefault.call(event);
			}
		}
	}, true);
})();
