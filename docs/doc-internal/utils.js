function docInternalLoad (url, callback)
{
	var xhr;
	if (typeof XMLHttpRequest !== "undefined") {
		xhr = new XMLHttpRequest();
	}
	// If not available look for one that is available
	else {
		var versions = ["MSXML2.XmlHttp.5.0", 
				"MSXML2.XmlHttp.4.0",
				"MSXML2.XmlHttp.3.0", 
				"MSXML2.XmlHttp.2.0",
				"Microsoft.XmlHttp"];
		for (var i = 0, len = versions.length; i < len; i++) {
			try {
				xhr = new ActiveXObject(versions[i]);
				break;
			}
			catch(e) {
			}
		}
	}

	xhr.onreadystatechange = function() {
		if(xhr.readyState === 4) {
			if (xhr.status == 200 || (xhr.status == 0 && xhr.responseText)) {
				callback(xhr.responseText);
			}
			else {
				console.error("Unable to load '" + url + "', this might be due to a Cross-Origin issue or the file does not exists");
			}
		}
	}

	xhr.open("GET", url, true);
	xhr.send();
}

function docInternalLoadJson (url, callback)
{
	docInternalLoad(url, function(data) {
		var json = JSON.parse(data);
		callback(json);
	});
}

var DocContext = function (config) {
	this.pages = [];
	if (typeof config.pages === "object") {
		this.pages = config.pages;
	}
	this.title = (config.title) ? config.title : "";
	this.github = (config.github) ? config.github : "";
	this.download = (config.download) ? config.download : [];
	DocContext.id = 0;
}

DocContext.prototype.initialize = function () {
	// Set the title
	document.getElementById("doc-title").innerHTML = this.title;
	// Construct the menu
	this.each(function (index, title) {
		document.getElementById("doc-menu").innerHTML += "<li onclick=\"javascript:window.docCtx.load(" + index + ");\">" + title + "</li>";
	});
	// Set the github info
	if (this.github) {
		document.getElementById("doc-github").innerHTML = "<a href=\"" + this.github + "\">View on GitHub</a>";
		document.getElementById("doc-download").innerHTML = "<button onclick=\"location.href='" + this.github + "/zipball/master';\">Project ZIP File</button>";
	}
	// Set the download links
	for (var i in this.download) {
		var button = document.createElement("button");
		button.setAttribute("onclick", "javascript:location.href='" + this.download[i] + "'");
		button.innerHTML = this.download[i].split('/').reverse()[0];
		document.getElementById("doc-download").appendChild(button);
		// Load the size
		(function(link, element) {
			docInternalLoad(link, function(data) {
				var bytes = data.length;
				var units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB'];
				var u = 0;
				while (Math.abs(bytes) >= 1024 && u < units.length - 1) {
					bytes /= 1024;
					++u;
				}
				element.innerHTML += " (" + bytes.toFixed(1) + " " + units[u] + ")";
			})
		})(this.download[i], button);
	}
	// Load the first page or the one marked with the hash
	var pageIndex = 0;
	if (window.location.hash) {
		var hash = window.location.hash.substring(1);
		this.each(function(i, title) {
			if (title == hash) {
				pageIndex = i;
			}
		});
	}
	this.load(pageIndex);
}

DocContext.prototype.each = function (callback) {
	for (var i in this.pages) {
		callback(i, this.pages[i][0], this.pages[i][1], this.pages[i][2]);
	}
};

DocContext.prototype.load = function (index) {
	var title = this.pages[index][0];
	var type = this.pages[index][1];
	var urlList = this.pages[index][2];

	if(history.pushState) {
		history.pushState(null, null, "#" + title);
	}
	else {
		location.hash = "#" + title;
	}

	// Clear the body
	var body = document.getElementById("doc-body");
	body.innerHTML = "";

	var loadElement = function (curIndex) {
		if (typeof urlList[curIndex] !== "undefined") {
			docInternalLoad(urlList[curIndex], function(data) {
				var id = "doc-element-" + (DocContext.id++);
				body.innerHTML += "<div id=\"" + id + "\" class=\"doc-element-" + type + "\"></div>";

				var callNext = function() {
					loadElement(curIndex + 1);
				}

				switch (type) {
				case "html":
					document.getElementById(id).innerHTML = data;
					// Execute the scripts
					var scriptTagList = [].slice.call(document.getElementById(id).getElementsByTagName("script"), 0);
					for (var i in scriptTagList) {
						eval(scriptTagList[i].innerHTML);
					}
					callNext();
					break;
				case "markdown":
					irRequire(["showdown"], function() {
						var converter = new showdown.Converter();
						document.getElementById(id).innerHTML = converter.makeHtml(data);
						callNext();
					});
					break;
				case "text":
					document.getElementById(id).innerHTML = data;
					callNext();
					break;
				default:
					console.error("Unkown type " + type);
				}
			});
		}
	};
	loadElement(0);
};
