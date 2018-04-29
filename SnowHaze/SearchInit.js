"use strict";
(function(){
	var pattern = $searchPattern$;
	var backgrounds = document.querySelectorAll("span[browser-search-id]");
	for (var background of backgrounds) {
		while (background.firstChild) {
			background.parentNode.insertBefore(background.firstChild, background);
		}
		background.parentNode.removeChild(background);
	}
	var count = 0;
	if (pattern.length) {
		// Jump to the end
		while (window.find(pattern, false, false, false, false, true, false)) ;
		var wrap = true;
		var ranges = [];
		while (window.find(pattern, false, false, wrap, false, true, false)) {
			wrap = false;
			var range = window.getSelection().getRangeAt(0);
			var rect = range.getBoundingClientRect();
			if (rect.height <= 0 || rect.width <= 0) continue;
			ranges.push(range);
		}
		for (var range of ranges) {
			var background = document.createElement("span");
			background.setAttribute("browser-search-id", ++count);
			range.surroundContents(background)
			if (count > 1) {
				background.style.backgroundColor = "#A0A0A0";
			} else {
				background.style.backgroundColor = "#FFFF00";
				var rect = background.getBoundingClientRect();
				var midY = (rect.top + rect.bottom) / 2;
				var midX = (rect.left + rect.right) / 2;
				var height = window.innerHeight;
				var width = window.innerWidth;
				var x = midX - width / 2 + window.scrollX;
				var y = midY - height / 3 + window.scrollY;
				window.scroll(x, y);
			}
		}
	}
	return count;
 })();
