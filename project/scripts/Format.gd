class_name Format

static func size(bytes: int) -> String:
	if bytes < 0:          return "—"
	if bytes < 1024:       return "%d B" % bytes
	if bytes < 1048576:    return "%.1f KB" % (bytes / 1024.0)
	if bytes < 1073741824: return "%.1f MB" % (bytes / 1048576.0)
	return "%.2f GB" % (bytes / 1073741824.0)

static func ts(unix: int) -> String:
	if unix <= 0: return "—"
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
