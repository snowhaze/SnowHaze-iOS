"use strict";
(function(){
	var icon = document.querySelector("link[rel='apple-touch-icon-precomposed']");
	if (icon) return icon.href;
	icon = document.querySelector("link[rel='apple-touch-icon']");
	if (icon) return icon.href;
	icon = document.querySelector("link[rel='icon']");
	if (icon) return icon.href;
	icon = document.querySelector("link[rel='shortcut icon']");
	if (icon) return icon.href;
	return document.location.origin + '/favicon.ico';
})();
