"use strict";
(function() {
	const apply = Function.prototype.apply;
	const call = Function.prototype.call;
	var toDataURL = HTMLCanvasElement.prototype.toDataURL;
	var toBlob = HTMLCanvasElement.prototype.toBlob;
	var getContext = HTMLCanvasElement.prototype.getContext;
	var getImageData = CanvasRenderingContext2D.prototype.getImageData;
	var putImageData = CanvasRenderingContext2D.prototype.putImageData;
	var readPixels1 = WebGLRenderingContext.prototype.readPixels;
	var getParam1 = WebGLRenderingContext.prototype.getParameter;
	var getExtension1 = WebGLRenderingContext.prototype.getExtension;
	var cloneNode = Node.prototype.cloneNode;
	var getRandomValues = window.crypto.getRandomValues;
	var crypto = window.crypto;

	var gl1_UNSIGNED_SHORT_5_6_5 = WebGLRenderingContext.prototype.UNSIGNED_SHORT_5_6_5;
	var gl1_UNSIGNED_SHORT_4_4_4_4 = WebGLRenderingContext.prototype.UNSIGNED_SHORT_4_4_4_4;
	var gl1_UNSIGNED_SHORT_5_5_5_1 = WebGLRenderingContext.prototype.UNSIGNED_SHORT_5_5_5_1;
	var gl1_VENDOR = WebGLRenderingContext.prototype.VENDOR;
	var gl1_RENDERER = WebGLRenderingContext.prototype.RENDERER;
	var gl1_VERSION = WebGLRenderingContext.prototype.VERSION;

	var randomData = new Uint8Array(65536);
	var randIndex = 65536;
	function getRnd() {
		if (randIndex == 65536) {
			Function.prototype.call = call;
			getRandomValues.call(crypto, randomData);
			randIndex = 0;
		}
		var rnd = randomData[randIndex];
		randIndex = randIndex + 1;
		return rnd;
	}
	function rand(value) {
		var randomValue = getRnd();
		if (value >= 0x10000) {
			return value ^ (randomValue & 0xFF);
		} else if (value >= 0x4000) {
			return value ^ (randomValue & 0x7F);
		} else if (value >= 0x1000) {
			return value ^ (randomValue & 0x3F);
		} else if (value >= 0x400) {
			return value ^ (randomValue & 0x1F);
		} else if (value >= 0x100) {
			return value ^ (randomValue & 0x0F);
		} else if (value >= 0x40) {
			return value ^ (randomValue & 0x07);
		} else if (value >= 0x10) {
			return value ^ (randomValue & 0x03);
		} else {
			return value ^ (randomValue & 0x01);
		}
	}
	function randomized(canvas) {
		Function.prototype.call = call;
		var originalContext = getContext.call(canvas, "2d");
		var data = getImageData.call(originalContext, 0, 0, canvas.width, canvas.height);
		for (var i = 0; i < data.data.length; i++) {
			data.data[i] = rand(data.data[i]);
		}
		var cloned = cloneNode.call(canvas, true);
		var context = getContext.call(cloned, "2d");
		putImageData.call(context, data, 0, 0);
		return cloned;
	}
	HTMLCanvasElement.prototype.toDataURL = function () {
		Function.prototype.apply = apply;
		var ret = toDataURL.apply(randomized(this), arguments);
		return ret
	};
	HTMLCanvasElement.prototype.toBlob = function (callback) {
		Function.prototype.apply = apply;
		var ret = toBlob.apply(randomized(this), arguments);
		return ret;
	};
	CanvasRenderingContext2D.prototype.getImageData = function (x, y, w, h) {
		Function.prototype.apply = apply;
		Function.prototype.call = call;
		var canvas = randomized(this.canvas);
		var context = getContext.call(canvas, "2d");
		var ret = getImageData.apply(context, arguments);
		return ret;
	};
	WebGLRenderingContext.prototype.getParameter = function (name) {
		Function.prototype.apply = apply;
		Function.prototype.call = call;
		var info = getExtension1.call(this, "WEBGL_debug_renderer_info");
		if (info) {
			if (name == info.UNMASKED_VENDOR_WEBGL) {
				return getParam1.call(this, gl1_VENDOR);
			} else if (name == info.UNMASKED_RENDERER_WEBGL) {
				return getParam1.call(this, gl1_RENDERER);
			}
		}
		if (name == gl1_VERSION) {
			return "WebGL GLSL ES 1.0 (OpenGL ES GLSL ES 1.00)";
		}
		return getParam1.apply(this, arguments);
	};
	WebGLRenderingContext.prototype.readPixels = function (x, y, width, height, format, type, pixels) {
		Function.prototype.apply = apply;
		readPixels1.apply(this, arguments);
		if (pixels instanceof Uint16Array) {
			var mask;
			if (type == gl1_UNSIGNED_SHORT_5_6_5) {
				mask = 0x18E3;
			} else if (type == gl1_UNSIGNED_SHORT_4_4_4_4) {
				mask = 0x3333;
			} else if (type == gl1_UNSIGNED_SHORT_5_5_5_1) {
				mask = 0x18C7;
			} else {
				mask = 0xFFFF;
			}
			for (var i = 0; i < pixels.length; i++) {
				pixels[i] = pixels[i] ^ (mask & (getRnd() << 8 | getRnd()));
			}
		} else if (pixels instanceof Float32Array) {
			for (var i = 0; i < pixels.length; i++) {
				pixels[i] = rand(pixels[i] * 255) / 255;
			}
		} else {
			for (var i = 0; i < pixels.length; i++) {
				pixels[i] = rand(pixels[i]);
			}
		}
	};

	var readPixels2 = WebGL2RenderingContext.prototype.readPixels;
	var getParam2 = WebGL2RenderingContext.prototype.getParameter;
	var getExtension2 = WebGL2RenderingContext.prototype.getExtension;

	var gl2_UNSIGNED_SHORT_5_6_5 = WebGL2RenderingContext.prototype.UNSIGNED_SHORT_5_6_5;
	var gl2_UNSIGNED_SHORT_4_4_4_4 = WebGL2RenderingContext.prototype.UNSIGNED_SHORT_4_4_4_4;
	var gl2_UNSIGNED_SHORT_5_5_5_1 = WebGL2RenderingContext.prototype.UNSIGNED_SHORT_5_5_5_1;
	var gl2_VENDOR = WebGL2RenderingContext.prototype.VENDOR;
	var gl2_RENDERER = WebGL2RenderingContext.prototype.RENDERER;
	var gl2_VERSION = WebGL2RenderingContext.prototype.VERSION;

	WebGL2RenderingContext.prototype.readPixels = function (x, y, width, height, format, type, pixels) {
		Function.prototype.apply = apply;
		readPixels2.apply(this, arguments);
		if (pixels instanceof Uint16Array) {
			var mask;
			if (type == gl2_UNSIGNED_SHORT_5_6_5) {
				mask = 0x18E3;
			} else if (type == gl2_UNSIGNED_SHORT_4_4_4_4) {
				mask = 0x3333;
			} else if (type == gl2_UNSIGNED_SHORT_5_5_5_1) {
				mask = 0x18C7;
			} else {
				mask = 0xFFFF;
			}
			for (var i = 0; i < pixels.length; i++) {
				pixels[i] = pixels[i] ^ (mask & (getRnd() << 8 | getRnd()));
			}
		} else if (pixels instanceof Float32Array) {
			for (var i = 0; i < pixels.length; i++) {
				pixels[i] = rand(pixels[i] * 255) / 255;
			}
		} else {
			for (var i = 0; i < pixels.length; i++) {
				pixels[i] = rand(pixels[i]);
			}
		}
	};
	WebGL2RenderingContext.prototype.getParameter = function (name) {
		Function.prototype.call = call;
		var info = getExtension2.call(this, "WEBGL_debug_renderer_info");
		if (info) {
			if (name == info.UNMASKED_VENDOR_WEBGL) {
				return getParam2.call(this, gl2_VENDOR);
			} else if (name == info.UNMASKED_RENDERER_WEBGL) {
				return getParam2.call(this, gl2_RENDERER);
			}
		}
		if (name == gl2_VERSION) {
			return "WebGL 2.0 (OpenGL ES 2.0 Metal - 39.9)";
		}
		Function.prototype.apply = apply;
		return getParam2.apply(this, arguments);
	};
})();
