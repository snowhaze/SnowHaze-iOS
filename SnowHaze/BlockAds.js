"use strict";
(function() {
	const call = Function.prototype.call;
	const urlConstructor = URL;
	var blacklist = $blacklist$;
	var blockedElements = ["SCRIPT", "IMG", "FRAME", "IFRAME", "VIDEO", "AUDIO", "STYLE", "SOURCE"];

	var preventDefault = Event.prototype.preventDefault;
	var indexOf = Array.prototype.indexOf;
	document.addEventListener("beforeload", function(event) {
		if (event.target.src) {
			Function.prototype.call = call;
			var url = new urlConstructor(event.target.src);
			if (~indexOf.call(blockedElements, event.target.nodeName) && ~indexOf.call(blacklist, url.hostname)) {
				preventDefault.call(event);
			}
		}
	}, true);

	var getAttribute = Element.prototype.getAttribute;
	var setAttribute = Element.prototype.setAttribute;
	var observer = new window.MutationObserver(function (changes) {
		Function.prototype.call = call;
		for (var index = 0; index < changes.length; index++) {
			var change = changes[index];
			var node;
			if (change.type == "attributes") {
				if (change.attributeName == "src") {
					node = change.target;
					if (~indexOf.call(blockedElements, node.nodeName) && getAttribute.call(node, "src")) {
						var url = new URL(getAttribute.call(node, "src"));
						if (url && ~indexOf.call(blacklist, url.hostname)) setAttribute.call(node, "src", "");
					}
				}
			} else if (change.type == "childList") {
				for (var i = 0; i < change.addedNodes.length; i++) {
					node = change.addedNodes[i];
					if (~indexOf.call(blockedElements, node.nodeName) && getAttribute.call(node, "src")) {
						var url = new URL(getAttribute.call(node, "src"));
						if (url && ~indexOf.call(blacklist, url.hostname)) setAttribute.call(node, "src", "");
					}
				}
			}
		}
	});
	observer.observe(document.documentElement, {attributes: true, childList: true, subtree: true, attributeFilter: ["src"]});
})();
