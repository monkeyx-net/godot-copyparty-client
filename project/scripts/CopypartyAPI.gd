# CopypartyAPI.gd
# Handles all HTTP communication with a copyparty server.
# Each public method is async (use `await api.method()`).
class_name CopypartyAPI
extends Node

var base_url := ""
var password := ""
var _session_cookie := ""

func configure(url: String, pw := "") -> void:
	base_url = url.strip_edges().rstrip("/")
	password = pw
	_session_cookie = ""

func _headers(extra: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var h := PackedStringArray()
	if not OS.has_feature("web"):
		if password:
			h.append("PW: " + password)
		if _session_cookie:
			h.append("Cookie: " + _session_cookie)
	for e in extra:
		h.append(e)
	return h

# Returns [result_int, http_code, response_headers, body_bytes]
func _req(url: String, method := HTTPClient.METHOD_GET,
		extra_headers: PackedStringArray = PackedStringArray(),
		body: PackedByteArray = PackedByteArray()) -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	http.use_threads = not OS.has_feature("web")
	var all_headers := _headers(extra_headers)
	var req_url := url
	if OS.has_feature("web") and password and not _session_cookie:
		req_url += ("&" if "?" in url else "?") + "pw=" + password.uri_encode()
	var err: int
	if body.is_empty():
		err = http.request(req_url, all_headers, method)
	else:
		err = http.request_raw(req_url, all_headers, method, body)
	if err != OK:
		http.queue_free()
		return [err, 0, PackedStringArray(), PackedByteArray()]
	var resp: Array = await http.request_completed
	http.queue_free()
	return resp  # [result, response_code, headers, body]

# Extracts filename from a URL-encoded href (e.g. "/foo/bar%20baz.txt" → "bar baz.txt")
static func href_to_name(href: String) -> String:
	var path := href.rstrip("/")
	if "/" in path:
		path = path.rsplit("/", true, 1)[1]
	return path.uri_decode()

# Parses a single file/dir entry from the ?ls JSON response
static func _parse_entry(e: Dictionary, is_dir: bool) -> Dictionary:
	return {
		"name": href_to_name(e.get("href", "")),
		"href": e.get("href", ""),
		"size": e.get("sz", 0),
		"ext": e.get("ext", ""),
		"ts": e.get("ts", 0),
		"is_dir": is_dir,
		"tags": e.get("tags", {}),
	}

# Lists a directory. Returns {"dirs": [...], "files": [...]} or null on error.
# Each entry: {name, href, size, ext, ts, is_dir, tags}
func list_directory(path: String) -> Variant:
	var url := base_url + _vpath(path) + "?ls"
	var resp := await _req(url)
	if resp[1] != 200:
		return null
	var json: Variant = JSON.parse_string(resp[3].get_string_from_utf8())
	if json == null or not json is Dictionary:
		return null
	var result := {"dirs": [], "files": [], "perms": json.get("perms", []), "acct": json.get("acct", "*"), "raw": json}
	var base := path.rstrip("/")
	for d in json.get("dirs", []):
		var e := _parse_entry(d, true)
		if not e["href"].begins_with("/"):
			e["href"] = base + "/" + e["name"]
		result["dirs"].append(e)
	for f in json.get("files", []):
		var e := _parse_entry(f, false)
		if not e["href"].begins_with("/"):
			e["href"] = base + "/" + e["name"]
		result["files"].append(e)
	return result

# Downloads a file. Returns raw bytes, or empty array on error.
func download_file(vpath: String) -> PackedByteArray:
	var url := base_url + _vpath(vpath)
	var resp := await _req(url)
	if resp[1] == 200:
		return resp[3]
	return PackedByteArray()

# Uploads binary data via PUT to base_url/dir_path/filename.
# Returns true on success.
func upload_file(dir_path: String, filename: String, data: PackedByteArray) -> int:
	if OS.has_feature("web"):
		# PUT with octet-stream triggers a CORS preflight that many servers block.
		# multipart/form-data is a simple CORS content type — no preflight needed.
		var boundary := "----CopypartyBoundary" + str(randi())
		var hdr := ("--" + boundary + "\r\n"
			+ 'Content-Disposition: form-data; name="f"; filename="' + filename + '"\r\n'
			+ "Content-Type: application/octet-stream\r\n\r\n")
		var body := PackedByteArray()
		body.append_array(hdr.to_utf8_buffer())
		body.append_array(data)
		body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())
		var upload_url := base_url + _vpath(dir_path) + "?j"
		var upload_extra := PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary])
		var upload_resp := await _req(upload_url, HTTPClient.METHOD_POST, upload_extra, body)
		return upload_resp[1]
	var url := base_url + _vpath(dir_path) + "/" + filename.uri_encode() + "?j"
	var extra := PackedStringArray(["Content-Type: application/octet-stream"])
	var resp := await _req(url, HTTPClient.METHOD_PUT, extra, data)
	return resp[1]

# Creates a directory named `name` inside `parent_path`.
func make_directory(parent_path: String, dir_name: String) -> bool:
	var url := base_url + _vpath(parent_path)
	var body := _multipart({"act": "mkdir", "name": dir_name})
	var extra := PackedStringArray(["Content-Type: multipart/form-data; boundary=" + body[0]])
	var resp := await _req(url, HTTPClient.METHOD_POST, extra, body[1])
	return resp[1] in [200, 201]

# Deletes a path (file or directory) recursively.
# Returns [http_code, body_string].
func delete_path(vpath: String) -> Array:
	var url := base_url + _vpath(vpath) + "?delete"
	var resp := await _req(url, HTTPClient.METHOD_POST)
	return [resp[1], resp[3].get_string_from_utf8().strip_edges()]

# Moves/renames src to dst (both server-side virtual paths).
func move_path(src: String, dst: String) -> bool:
	var url := base_url + _vpath(src) + "?move=" + _vpath(dst)
	var resp := await _req(url, HTTPClient.METHOD_POST)
	return resp[1] in [200, 201]

# Copies src to dst.
func copy_path(src: String, dst: String) -> bool:
	var url := base_url + _vpath(src) + "?copy=" + _vpath(dst)
	var resp := await _req(url, HTTPClient.METHOD_POST)
	return resp[1] in [200, 201]

# Searches for files matching query under path.
# Returns the parsed JSON response or null.
func search(query: String, path := "/") -> Variant:
	var url := base_url + _vpath(path) + "?srch"
	var body := JSON.stringify({"q": query})
	var extra := PackedStringArray(["Content-Type: application/json"])
	var resp := await _req(url, HTTPClient.METHOD_POST, extra, body.to_utf8_buffer())
	if resp[1] == 200:
		return JSON.parse_string(resp[3].get_string_from_utf8())
	return null

# Authenticates with username and password.
# On success, stores the password for subsequent requests.
func login(user: String, pw: String) -> bool:
	var url := base_url + "/"
	var fields := {"act": "login"}
	if user:
		fields["uname"] = user
	fields["cppwd"] = pw
	var body := _multipart(fields)
	var extra := PackedStringArray(["Content-Type: multipart/form-data; boundary=" + body[0]])
	var saved_pw := password
	password = ""  # don't send PW header during login — credentials are in the body
	var resp := await _req(url, HTTPClient.METHOD_POST, extra, body[1])
	password = saved_pw
	# Server always returns 200; check body for "naw dude" to detect failure.
	if resp[1] != 200 or "naw" in resp[3].get_string_from_utf8():
		return false
	password = (user + ":" + pw) if user else pw
	for h in resp[2]:
		if h.to_lower().begins_with("set-cookie:"):
			_session_cookie = h.substr(11).strip_edges().split(";")[0].strip_edges()
			break
	return true

# Clears the current session / auth state.
func logout() -> void:
	var url := base_url + "/"
	var body := _multipart({"act": "logout"})
	var extra := PackedStringArray(["Content-Type: multipart/form-data; boundary=" + body[0]])
	await _req(url, HTTPClient.METHOD_POST, extra, body[1])
	password = ""
	_session_cookie = ""

# Returns the full download URL for a virtual path (with pw param if needed).
func get_download_url(vpath: String) -> String:
	var url := base_url + _vpath(vpath)
	if password:
		url += "?pw=" + password.uri_encode()
	return url

# Returns true if a base URL has been configured.
func is_configured() -> bool:
	return not base_url.is_empty()

# Normalises a virtual path: ensures it starts with /, encodes each segment.
func _vpath(path: String) -> String:
	if path == "/":
		return "/"
	var parts := path.strip_edges().split("/")
	var encoded := PackedStringArray()
	for p in parts:
		if p:
			encoded.append(p.uri_decode().uri_encode())
	return "/" + "/".join(encoded)

# Builds a multipart/form-data body. Returns [boundary, body_bytes].
func _multipart(fields: Dictionary) -> Array:
	var boundary := "----CopypartyBoundary" + str(randi())
	var body := ""
	for key in fields:
		body += "--" + boundary + "\r\n"
		body += 'Content-Disposition: form-data; name="%s"\r\n\r\n' % key
		body += str(fields[key]) + "\r\n"
	body += "--" + boundary + "--\r\n"
	return [boundary, body.to_utf8_buffer()]
