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

var GitHub = function (userName, projectName) {
	this.userName = userName;
	this.projectName = projectName;
}

GitHub.prototype.getProjectLink = function () {
	return "https://github.com/" + this.userName + "/" + this.projectName;
}

GitHub.prototype.getProjectDownloadLink = function () {
	return this.getProjectLink() + "/zipball/master";
}

GitHub.prototype.getRawLink = function () {
	return "https://raw.githubusercontent.com/" + this.userName + "/" + this.projectName + "/master";
}

var DocContext = function (config) {
	this.local = (window.location.protocol.indexOf("file") == 0) ? true : false;

	// If in local merge with local specific config
	if (this.local && config.local) {
		var merge = function (dest, toMerge) {
			for (var key in toMerge) {
				if (typeof dest[key] == "object") {
					merge(dest[key], toMerge[key]);
				}
				else if (toMerge[key]) {
					dest[key] = toMerge[key];
				}
			}
		}
		merge(config, config.local);
	}

	// Setup irRequire
	irRequire.map = (config.irRequire) ? config.irRequire : {};
	irRequire.map["showdown"] = "doc-internal/showdown.min.js";

	this.title = (config.title) ? config.title : "";
	this.github = (config.github) ? new GitHub(config.github[0], config.github[1]) : new GitHub();
	this.download = (config.download) ? config.download : [];
	this.pages = [];
	if (typeof config.pages === "object") {
		this.pages = config.pages;
		// Assign specific pages if any
		this.each(function(i, title, type, urlList) {
			if (!urlList  || urlList.length == 0) {
				switch (type) {
				case "readme":
					this.pages[i] = [title, "markdown", (this.local) ? "../README.md" : this.github.getRawLink() + "/README.md"];
					break;
				case "license":
					this.pages[i] = [title, "text", (this.local) ? "../LICENSE.txt" : this.github.getRawLink() + "/LICENSE.txt"];
					break;
				default:
					console.error("Unknown page type " + type);
				}
			}
		});
	}
}

DocContext.id = 0;

DocContext.loading = function() {
	return "<div class=\"doc-loading\"></div>";
};

DocContext.prototype.initialize = function () {
	// Set the title
	document.getElementById("doc-title").innerHTML = this.title;
	// Construct the menu
	this.each(function (index, title) {
		document.getElementById("doc-menu").innerHTML += "<li onclick=\"javascript:window.docCtx.load(" + index + ");\">" + title + "</li>";
	});
	// Set the github info
	if (this.github) {
		document.getElementById("doc-github").innerHTML = "<a href=\"" + this.github.getProjectLink() + "\">View on GitHub</a>";
		document.getElementById("doc-download").innerHTML = "<button onclick=\"location.href='" + this.github.getProjectDownloadLink() + "';\">Project ZIP File</button>";
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
		callback.call(this, i, this.pages[i][0], this.pages[i][1], this.pages[i][2]);
	}
};

DocContext.prototype.load = function (index) {
	var title = this.pages[index][0];
	var type = this.pages[index][1];
	var urlList = (typeof this.pages[index][2] === "object") ? this.pages[index][2] : [this.pages[index][2]];

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

			var id = "doc-element-" + (DocContext.id++);
			{
				var docElement = document.createElement("div");
				docElement.setAttribute("id", id);
				docElement.setAttribute("class", "doc-element-" + type);
				docElement.innerHTML = DocContext.loading();
				body.appendChild(docElement);
			}

			setTimeout(function() {
				docInternalLoad(urlList[curIndex], function(data) {
					var callNext = function() {
						loadElement(curIndex + 1);
					}

					// If the element does not exists anymore it means that another page is being loaded, abort
					var element = document.getElementById(id);
					if (!element) {
						return;
					}

					switch (type) {
					case "code":
						element.innerHTML = "<div class=\"doc-code-run\">" + data + "</div>";
						// Execute the scripts
						var scriptTagList = [].slice.call(element.getElementsByTagName("script"), 0);
						for (var i in scriptTagList) {
							eval(scriptTagList[i].innerHTML);
						}
						// Show the code below
						{
							var codeElement = document.createElement("pre");
							codeElement.setAttribute("class", "doc-code-display");
							codeElement.innerHTML = data.replace(/</g,"&lt;").replace(/>/g,"&gt;");
							body.appendChild(codeElement);
						}
						callNext();
						break;
					case "markdown":
						irRequire(["showdown"], function() {
							var converter = new showdown.Converter();
							element.innerHTML = converter.makeHtml(data);
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
			}, 1);
		}
	};
	loadElement(0);
};
