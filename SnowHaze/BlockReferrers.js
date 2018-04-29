"use strict";
(function() {
	var setAttribute = Element.prototype.setAttribute;
	var getAttribute = Element.prototype.getAttribute;
	var removeAttribute = Element.prototype.removeAttribute;
	var contains = Node.prototype.contains;
	var appendChild = Node.prototype.appendChild;
	
	var element = document.createElement("meta");
	element.setAttribute("name", "referrer");
	element.setAttribute("content", "no-referrer");
	
	var elementObserver = new window.MutationObserver(function (changes) {
		if (getAttribute.call(element, "name") != "referrer") {
			setAttribute.call(element, "name", "referrer");
		}
		if (getAttribute.call(element, "content") != "no-referrer") {
			setAttribute.call(element, "content", "no-referrer");
		}
	});
	elementObserver.observe(element, {attributes: true, attributeFilter: ["name", "content"]});
	
	
	var head = null;
	var observer = new window.MutationObserver(function (changes) {
		for (var index = 0; index < changes.length; index++) {
			var change = changes[index];
			var node;
			if (change.type == "attributes") {
				if (change.attributeName == "referrerpolicy") {
					node = change.target;
					if (getAttribute.call(node, "referrerpolicy")) removeAttribute.call(node, "referrerpolicy");
				}
			} else if (change.type == "childList") {
				for (var i = 0; i < change.addedNodes.length; i++) {
					node = change.addedNodes[i];
					if (node.nodeType == 1 && getAttribute.call(node, "referrerpolicy")) { // 1 = ELEMENT_NODE
						removeAttribute.call(node, "referrerpolicy");
					}
					if (!head && node.nodeName == "HEAD") {
						head = node;
						appendChild.call(head, element);
						
						var headObserver = new window.MutationObserver(function (changes) {
							if (!contains.call(head, element)) {
								appendChild.call(head, element);
							}
						});
						headObserver.observe(head, {childList: true});
					}
				}
			}
		}
	});
	observer.observe(document.documentElement, {attributes: true, childList: true, subtree: true, attributeFilter: ["referrerpolicy"]});
})();
