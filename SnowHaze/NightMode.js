"use strict";
(function() {
	var styles = ':not(#map *) {background:#10080880 !important; color:#FFFFFF !important;} :link, :link * {color:snow !important;} html{-webkit-filter:brightness(0.7) !important;}';
	var css = document.createElement('link');
	css.rel = 'stylesheet';
	css.href = 'data:text/css,' + escape(styles);
	var observer = new window.MutationObserver(function (changes) {
		for (var change of changes) {
			for (var node of change.addedNodes) {
				if (node.nodeName == "HEAD") {
					node.appendChild(css);
					observer.disconnect();
				}
			}
		}
	});
	observer.observe(document.documentElement, {childList: true});
})();
