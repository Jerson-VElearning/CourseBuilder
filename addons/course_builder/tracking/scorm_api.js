(function (w) {
	if (w.CourseBuilderScorm) {
		return;
	}

	function findAPI(win) {
		var tries = 0;
		while (win && tries < 10) {
			try {
				if (win.API) {
					return win.API;
				}
			} catch (err) {
				break;
			}
			if (!win.parent || win.parent === win) {
				break;
			}
			win = win.parent;
			tries += 1;
		}
		try {
			if (w.opener && w.opener.API) {
				return w.opener.API;
			}
		} catch (err2) {}
		return null;
	}

	function makeMock() {
		var store = {};
		var mock = {
			LMSInitialize: function () {
				console.log("[CourseBuilder LMS mock] LMSInitialize");
				return "true";
			},
			LMSFinish: function () {
				console.log("[CourseBuilder LMS mock] LMSFinish");
				return "true";
			},
			LMSGetValue: function (el) {
				return store[el] != null ? String(store[el]) : "";
			},
			LMSSetValue: function (el, val) {
				store[el] = val;
				console.log("[CourseBuilder LMS mock] LMSSetValue", el, val);
				return "true";
			},
			LMSCommit: function () {
				console.log("[CourseBuilder LMS mock] LMSCommit");
				return "true";
			},
			LMSGetLastError: function () {
				return "0";
			},
			LMSGetErrorString: function () {
				return "No error";
			},
			LMSGetDiagnostic: function () {
				return "";
			}
		};
		w.API = mock;
		return mock;
	}

	var api = findAPI(w);
	var mocked = false;
	if (!api) {
		api = makeMock();
		mocked = true;
	}

	var initialized = false;
	var finished = false;

	function isTrue(value) {
		return value === "true" || value === true;
	}

	w.CourseBuilderScorm = {
		mocked: mocked,
		found: !!api,
		init: function () {
			if (initialized) {
				return "true";
			}
			var result = api.LMSInitialize("");
			initialized = isTrue(result);
			return initialized ? "true" : "false";
		},
		get: function (el) {
			if (!initialized) {
				return "";
			}
			var value = api.LMSGetValue(el);
			return value == null ? "" : String(value);
		},
		set: function (el, val) {
			if (!initialized) {
				return "false";
			}
			var result = api.LMSSetValue(el, val == null ? "" : String(val));
			return isTrue(result) ? "true" : "false";
		},
		commit: function () {
			if (!initialized) {
				return "false";
			}
			var result = api.LMSCommit("");
			return isTrue(result) ? "true" : "false";
		},
		finish: function () {
			if (!initialized || finished) {
				return "true";
			}
			api.LMSCommit("");
			var result = api.LMSFinish("");
			finished = true;
			initialized = false;
			return isTrue(result) ? "true" : "false";
		},
		lastError: function () {
			if (!api || !api.LMSGetLastError) {
				return "0";
			}
			return String(api.LMSGetLastError());
		}
	};

	function onHide() {
		if (w.CourseBuilderScorm) {
			w.CourseBuilderScorm.finish();
		}
	}
	w.addEventListener("pagehide", onHide);
	w.addEventListener("beforeunload", onHide);
})(window);
