"use strict";
(function() {
	function httpURL(string) {
		if (!string) return false;
		const url = new URL(string);
		return !!~["http:", "https:"].indexOf(url.protocol);
	}
	function torify(string) {
		var url = new URL(string);
		if (url.protocol == "http:") url.protocol = "tor:";
		if (url.protocol == "https:") url.protocol = "tors:";
		return url;
	}
	function reinject(node, modify) {
		var next = node.nextSibling;
		var parent = node.parentNode
		node.remove();
		modify(node);
		if (next) {
			parent.insertBefore(node, next);
		} else {
			parent.append(node);
		}
	}
	var observer = new window.MutationObserver(function (changes) {
		for (var index = 0; index < changes.length; index++) {
			var change = changes[index];
			if (change.type == "attributes") {
				if (change.attributeName == "src") {
					if (httpURL(change.target.src)) reinject(change.target, node => node.src = torify(node.src));
				}
				if (change.attributeName == "href") {
					if (httpURL(change.target.href)) reinject(change.target, node => node.href = torify(node.href));
				}
			} else if (change.type == "childList") {
				for (var i = 0; i < change.addedNodes.length; i++) {
					var node = change.addedNodes[i];
					if (httpURL(node.src)) reinject(node, node => node.src = torify(node.src));
					if (httpURL(node.href)) reinject(node, node => node.href = torify(node.href));
				}
			}
		}
	});
	observer.observe(document.documentElement, {attributes: true, childList: true, subtree: true, attributeFilter: ["src"]});
})();