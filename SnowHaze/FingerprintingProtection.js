"use strict";
(function() {
	const apply = Function.prototype.apply;
	const call = Function.prototype.call;
	var addEventListener = window.addEventListener;
	var getAttribute = Element.prototype.getAttribute;
	var removeAttribute = Element.prototype.removeAttribute;

	var originalWindow = window;
	window.webkitAudioContext = undefined;
	window.AudioContext = undefined;
	window.OfflineAudioContext = undefined;
	window.webkitOfflineAudioContext = undefined;
	DynamicsCompressorNode = undefined;
	OscillatorNode = undefined;
	window.addEventListener = function (name, callback) {
		if (name != 'deviceorientation') {
			Function.prototype.apply = apply;
			addEventListener.apply(this, arguments);
		}
	}

	var observer = new window.MutationObserver(function (changes) {
		Function.prototype.call = call;
		for (var index = 0; index < changes.length; index++) {
			var change = changes[index];
			var node;
			if (change.type == "attributes") {
				if (change.attributeName == "ping") {
					node = change.target;
					if (node.nodeName == "A" && getAttribute.call(node, "ping")) removeAttribute.call(node, "ping");
				}
			} else if (change.type == "childList") {
				for (var i = 0; i < change.addedNodes.length; i++) {
					node = change.addedNodes[i];
					if (node.nodeName == "A" && getAttribute.call(node, "ping")) removeAttribute.call(node, "ping");
				}
			}
		}
	});
	observer.observe(document.documentElement, {attributes: true, childList: true, subtree: true, attributeFilter: ["ping"]});
	window.RTCPeerConnection = undefined;

	Navigator.prototype.sendBeacon = function () { return false; };
})();
