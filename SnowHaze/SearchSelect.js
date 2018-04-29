"use strict";
(function(){
	var deselect = $deselect$;
	var select = $select$;
	var deselectSpan = document.querySelector("span[browser-search-id='" + deselect + "']");
	var selectSpan = document.querySelector("span[browser-search-id='" + select + "']");
	if (deselectSpan) {
		deselectSpan.style.backgroundColor = "#A0A0A0";
	}
	if (selectSpan) {
		selectSpan.style.backgroundColor = "#FFFF00";
		var rect = selectSpan.getBoundingClientRect();
		var midY = (rect.top + rect.bottom) / 2;
		var midX = (rect.left + rect.right) / 2;
		var height = window.innerHeight;
		var width = window.innerWidth;
		var x = midX - width / 2 + window.scrollX;
		var y = midY - height / 3 + window.scrollY;
		window.scroll(x, y);
	}
})();
