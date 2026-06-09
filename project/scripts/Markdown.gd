class_name Markdown

static var _rc: RegEx
static var _rl: RegEx
static var _rb: RegEx
static var _ri: RegEx

static func to_bbcode(text: String) -> String:
	if not _rc:
		_rc = RegEx.new(); _rc.compile("`([^`\n]+)`")
		_rl = RegEx.new(); _rl.compile("\\[([^\\]]+)\\]\\(([^)]+)\\)")
		_rb = RegEx.new(); _rb.compile("\\*\\*(.+?)\\*\\*")
		_ri = RegEx.new(); _ri.compile("\\*(.+?)\\*")

	var lines    := text.split("\n")
	var out      := PackedStringArray()
	var in_fence := false

	for raw in lines:
		if raw.strip_edges().begins_with("```"):
			in_fence = !in_fence
			out.append("[code]" if in_fence else "[/code]")
			continue
		if in_fence:
			out.append(raw)
			continue

		var line := raw

		if line.begins_with("### "):
			line = "[font_size=16][b]" + _il(line.substr(4)) + "[/b][/font_size]"
		elif line.begins_with("## "):
			line = "[font_size=20][b]" + _il(line.substr(3)) + "[/b][/font_size]"
		elif line.begins_with("# "):
			line = "[font_size=26][b]" + _il(line.substr(2)) + "[/b][/font_size]"
		elif line.strip_edges().length() >= 3 and line.strip_edges().replace("-", "").is_empty():
			line = "[color=#666666]" + "─".repeat(40) + "[/color]"
		elif line.begins_with("> "):
			line = "[color=#999999][i]" + _il(line.substr(2)) + "[/i][/color]"
		elif line.begins_with("- ") or line.begins_with("* "):
			line = "  • " + _il(line.substr(2))
		else:
			line = _il(line)

		out.append(line)

	return "\n".join(out)

static func _il(text: String) -> String:
	text = _rc.sub(text, "[code]$1[/code]", true)
	text = _rl.sub(text, "[url=$2]$1[/url]", true)
	text = _rb.sub(text, "[b]$1[/b]", true)
	text = _ri.sub(text, "[i]$1[/i]", true)
	return text
