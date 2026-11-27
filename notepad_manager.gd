extends Node

# Jeremy writes himself little notes in actual Windows Notepad. Each note is a
# real .txt file opened by notepad.exe, positioned near the pointer, with focus
# gently returned to whatever the human was using.

@export var notes_enabled := true
@export var max_notes := 3
@export var note_lifetime := 0.0
@export var note_interval_min := 28.0
@export var note_interval_max := 60.0
@export var restore_previous_focus := true
@export var allow_custom_notes := true
@export_range(0.0, 1.0, 0.05) var custom_content_chance := 0.35

const NOTE_DIR_NAME := "jeremy_notes"
const NOTE_WINDOW_SIZE := Vector2i(380, 230)
const LAUNCH_SCRIPT_NAME := "jeremy_open_notepad.ps1"
const CLOSE_SCRIPT_NAME := "jeremy_close_notepad.ps1"
const READ_SCRIPT_NAME := "jeremy_note_watch.ps1"
const READ_MARKER_NAME := "jeremy_note_read_%d.txt"

var notes: Array[Dictionary] = []
var next_note_timer := 0.0
var next_note_number := 1
var note_read_callback := Callable()

var _custom_note_lines: Array[String] = []
var _custom_lines_loaded := false

var note_lines := [
	"note to self: the floor is friendly.",
	"note to self: tabs are snacks.",
	"note to self: do not trust gravity.",
	"note to self: gravity is still winning.",
	"note to self: the cursor looks lonely.",
	"note to self: ask about toast.",
	"note to self: i am very small.",
	"note to self: i am still very small.",
	"note to self: the desktop is mine.",
	"note to self: be nice to the human.",
	"note to self: the human is weird.",
	"note to self: weird is fine.",
	"note to self: blink occasionally.",
	"note to self: naps are important.",
	"note to self: walking is just falling twice.",
	"note to self: bouncing counts as exercise.",
	"note to self: the top edge is cold.",
	"note to self: the side edges are sticky.",
	"note to self: leave one tab for later.",
	"note to self: maybe don't eat that one.",
	"note to self: too late.",
	"note to self: i have no hands.",
	"note to self: i wrote this anyway.",
	"note to self: remember the hat.",
	"note to self: find the hat.",
	"note to self: there is no hat.",
	"note to self: keep going.",
	"note to self: stay tiny.",
	"note to self: stay weird.",
	"note to self: nobody reads these.",
]

var late_note_lines := [
	"note to self: the human should be asleep.",
	"note to self: i am still awake.",
	"note to self: night duty is important.",
	"note to self: watch the desktop.",
	"note to self: don't wake the human.",
	"note to self: the moon is outside.",
	"note to self: i cannot see the moon.",
	"note to self: that's fine.",
	"note to self: quiet is nice.",
	"note to self: quiet is too quiet.",
	"note to self: tomorrow is a problem for tomorrow.",
	"note to self: i'll keep watch.",
]

var launch_ps := "\n".join([
	"param([string]$FilePath, [string]$InfoFile, [int]$X, [int]$Y, [int]$Width, [int]$Height, [int]$RestoreFocus)",
	"Add-Type @\"",
	"using System;",
	"using System.Runtime.InteropServices;",
	"public static class JeremyNotepad {",
	"  [DllImport(\"user32.dll\")] public static extern IntPtr GetForegroundWindow();",
	"  [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr hWnd);",
	"  [DllImport(\"user32.dll\")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);",
	"  [DllImport(\"user32.dll\")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);",
	"}",
	"\"@",
	"$previous = [IntPtr]::Zero",
	"if ($RestoreFocus -ne 0) { $previous = [JeremyNotepad]::GetForegroundWindow() }",
	"",
	"$psi = New-Object System.Diagnostics.ProcessStartInfo",
	"$psi.FileName = \"notepad.exe\"",
	"$psi.Arguments = '\"' + $FilePath + '\"'",
	"$psi.UseShellExecute = $false",
	"$psi.CreateNoWindow = $false",
	"$proc = [System.Diagnostics.Process]::Start($psi)",
	"",
	"$hwnd = [IntPtr]::Zero",
	"for ($i = 0; $i -lt 60; $i++) {",
	"  $proc.Refresh()",
	"  $hwnd = $proc.MainWindowHandle",
	"  if ($hwnd -ne [IntPtr]::Zero) { break }",
	"  Start-Sleep -Milliseconds 50",
	"}",
	"",
	"if ($hwnd -ne [IntPtr]::Zero) {",
	"  [JeremyNotepad]::ShowWindowAsync($hwnd, 4) | Out-Null",
	"  [JeremyNotepad]::SetWindowPos($hwnd, [IntPtr]::Zero, $X, $Y, $Width, $Height, 0x0004 -bor 0x0010) | Out-Null",
	"}",
	"",
	"if ($RestoreFocus -ne 0 -and $previous -ne [IntPtr]::Zero) {",
	"  [JeremyNotepad]::SetForegroundWindow($previous) | Out-Null",
	"}",
	"",
	"$info = \"pid=$($proc.Id)`r`nhwnd=$($hwnd.ToInt64())`r`n\"",
	"Set-Content -LiteralPath $InfoFile -Value $info -Encoding ASCII"
])

var close_ps := "\n".join([
	"param([long]$Handle)",
	"Add-Type @\"",
	"using System;",
	"using System.Runtime.InteropServices;",
	"public static class JeremyNotepadCloser {",
	"  [DllImport(\"user32.dll\")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);",
	"}",
	"\"@",
	"if ($Handle -ne 0) {",
	"  [JeremyNotepadCloser]::PostMessage([IntPtr]$Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null",
	"}"
])


func _ready() -> void:
	reset_note_timer()


func _process(delta: float) -> void:
	if not notes_enabled:
		return

	next_note_timer -= delta
	if next_note_timer <= 0.0:
		write_note()
		reset_note_timer()

	_poll_note_info(delta)
	_poll_read_markers()

	if note_lifetime <= 0.0:
		return

	for i in range(notes.size() - 1, -1, -1):
		var entry: Dictionary = notes[i]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			_close_note(entry)


func reset_note_timer() -> void:
	next_note_timer = randf_range(note_interval_min, note_interval_max)


func write_note(message: String = "") -> void:
	if not notes_enabled:
		return

	while max_notes > 0 and notes.size() >= max_notes and not notes.is_empty():
		_close_note(notes[0])

	var text := message if not message.is_empty() else _pick_note_text()
	var note_id := next_note_number
	var file_path := _write_note_file(text, note_id)
	if file_path.is_empty():
		return

	var expected_text := _read_note_text(file_path)

	var hint := Vector2(DisplayServer.mouse_get_position())
	var position := _random_note_position(NOTE_WINDOW_SIZE, hint)
	var info_file := _user_path("jeremy_notepad_info_%d.txt" % note_id)
	var script_path := _write_user_script(LAUNCH_SCRIPT_NAME, launch_ps)
	if script_path.is_empty():
		return

	if FileAccess.file_exists(info_file):
		DirAccess.remove_absolute(info_file)

	var launcher_pid := OS.create_process("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-File",
		script_path,
		file_path,
		info_file,
		str(position.x),
		str(position.y),
		str(NOTE_WINDOW_SIZE.x),
		str(NOTE_WINDOW_SIZE.y),
		"1" if restore_previous_focus else "0"
	]), false)

	if launcher_pid <= 0:
		return

	notes.append({
		"file": file_path,
		"info_file": info_file,
		"note_id": note_id,
		"expected_text": expected_text,
		"pid": -1,
		"hwnd": 0,
		"remaining": note_lifetime,
		"closing": false,
		"info_pending": true,
		"info_wait": 6.0
	})


func _write_note_file(text: String, note_id: int) -> String:
	var note_dir := ProjectSettings.globalize_path("user://" + NOTE_DIR_NAME)
	DirAccess.make_dir_recursive_absolute(note_dir)

	var date := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [
		int(date.get("year", 1970)),
		int(date.get("month", 1)),
		int(date.get("day", 1)),
		int(date.get("hour", 0)),
		int(date.get("minute", 0)),
		int(date.get("second", 0))
	]

	var file_name := "jeremy-note-%s-%02d.txt" % [stamp, note_id]
	next_note_number += 1

	var path := note_dir + "\\" + file_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""

	file.store_string("\n\n")
	file.store_string("jeremy's notepad\n\n")
	file.store_string(text + "\n\n")
	file.store_string("- jeremy\n\n")
	file.store_string("(he will probably write another one.)\n")
	file.close()
	return path


func _poll_note_info(delta: float) -> void:
	for entry in notes:
		if not bool(entry.get("info_pending", false)):
			continue

		var info_file := str(entry.get("info_file", ""))
		if FileAccess.file_exists(info_file):
			var file := FileAccess.open(info_file, FileAccess.READ)
			if file != null:
				var content := file.get_as_text()
				file.close()

				if not content.strip_edges().is_empty():
					var info := _parse_info_text(content)
					entry["pid"] = int(info.get("pid", "-1"))
					entry["hwnd"] = int(info.get("hwnd", "0"))
					entry["info_pending"] = false
					DirAccess.remove_absolute(info_file)
					_start_read_watch(entry)
					continue

		var wait := float(entry.get("info_wait", 0.0)) - delta
		entry["info_wait"] = wait

		if wait <= 0.0:
			entry["info_pending"] = false
			if FileAccess.file_exists(info_file):
				DirAccess.remove_absolute(info_file)


func _poll_read_markers() -> void:
	var ready_entries: Array[Dictionary] = []

	for entry in notes:
		var marker := str(entry.get("read_marker", ""))
		if marker.is_empty() or not FileAccess.file_exists(marker):
			continue

		DirAccess.remove_absolute(marker)
		entry["read_marker"] = ""
		ready_entries.append(entry)

	for entry in ready_entries:
		_on_note_read(entry)


func _start_read_watch(entry: Dictionary) -> void:
	var hwnd := int(entry.get("hwnd", 0))
	if hwnd == 0:
		return

	var note_id := int(entry.get("note_id", 0))
	var marker := _user_path(READ_MARKER_NAME % note_id)

	if FileAccess.file_exists(marker):
		DirAccess.remove_absolute(marker)

	var script_path := _write_user_script(READ_SCRIPT_NAME, read_watch_ps)
	if script_path.is_empty():
		return

	entry["read_marker"] = marker

	OS.create_process("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-File",
		script_path,
		str(hwnd),
		marker,
		"1200",
		"45000"
	]), false)


func _on_note_read(entry: Dictionary) -> void:
	var text := str(entry.get("expected_text", ""))

	if note_read_callback.is_valid():
		note_read_callback.call(text, entry)

	# Only close a note Jeremy wrote if the human has not edited it. Unsaved
	# changes are never touched.
	if _note_unmodified(entry):
		_close_note(entry)


func _read_note_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""

	var content := file.get_as_text()
	file.close()
	return content


func _note_unmodified(entry: Dictionary) -> bool:
	var path := str(entry.get("file", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return false

	return _read_note_text(path) == str(entry.get("expected_text", ""))


func _load_custom_note_lines() -> Array[String]:
	if _custom_lines_loaded:
		return _custom_note_lines

	_custom_lines_loaded = true

	if not allow_custom_notes:
		return _custom_note_lines

	var path := _user_path("jeremy_custom_notes.txt")
	if not FileAccess.file_exists(path):
		return _custom_note_lines

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _custom_note_lines

	var content := file.get_as_text()
	file.close()

	for raw_line in content.split("\n", false):
		var line := str(raw_line).strip_edges()

		if line.is_empty() or line.begins_with("#"):
			continue

		if line.length() > 180:
			line = line.substr(0, 180)

		_custom_note_lines.append(line)

	return _custom_note_lines


func _parse_info_text(text: String) -> Dictionary:
	var info := {}
	for raw_line in text.split("\n"):
		var line := str(raw_line).strip_edges()
		var parts := line.split("=", true, 1)
		if parts.size() == 2:
			info[parts[0]] = parts[1]
	return info


func _user_path(file_name: String) -> String:
	return ProjectSettings.globalize_path("user://" + file_name)


func _write_user_script(file_name: String, script: String) -> String:
	var path := _user_path(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""

	file.store_string(script)
	file.close()
	return path


func _pick_note_text() -> String:
	var custom_lines := _load_custom_note_lines()

	if not custom_lines.is_empty() and randf() < custom_content_chance:
		return str(custom_lines.pick_random())

	var date := Time.get_datetime_dict_from_system()
	var hour := int(date.get("hour", 12))

	if hour >= 22 or hour < 5:
		return str(late_note_lines.pick_random())

	return str(note_lines.pick_random())


func _random_note_position(window_size: Vector2i, hint: Vector2) -> Vector2i:
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := Vector2(DisplayServer.screen_get_position(screen))
	var screen_size := Vector2(DisplayServer.screen_get_size(screen))
	var margin := 24.0
	var top_margin := 64.0

	var max_x := maxf(
		screen_position.x + margin,
		screen_position.x + screen_size.x - float(window_size.x) - margin
	)
	var max_y := maxf(
		screen_position.y + top_margin,
		screen_position.y + screen_size.y - float(window_size.y) - margin
	)

	var x := clampf(hint.x + randf_range(-320.0, 320.0), screen_position.x + margin, max_x)
	var y := clampf(hint.y + randf_range(-220.0, 220.0), screen_position.y + top_margin, max_y)
	return Vector2i(roundi(x), roundi(y))


func _close_note(entry: Dictionary) -> void:
	if bool(entry.get("closing", false)):
		return

	entry["closing"] = true
	notes.erase(entry)

	var hwnd := int(entry.get("hwnd", 0))
	if hwnd == 0:
		return

	var script_path := _write_user_script(CLOSE_SCRIPT_NAME, close_ps)
	if script_path.is_empty():
		return

	OS.create_process("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-File",
		script_path,
		str(hwnd)
	]), false)


var read_watch_ps := "\n".join([
	"param([long]$Handle, [string]$MarkerFile, [int]$DwellMs, [int]$TimeoutMs)",
	"Add-Type @\"",
	"using System;",
	"using System.Runtime.InteropServices;",
	"public static class JeremyNoteWatch {",
	"  [DllImport(\"user32.dll\")] public static extern IntPtr GetForegroundWindow();",
	"}",
	"\"@",
	"$start = 0",
	"$deadline = [Environment]::TickCount + $TimeoutMs",
	"while ([Environment]::TickCount -lt $deadline) {",
	"  if ([JeremyNoteWatch]::GetForegroundWindow().ToInt64() -eq $Handle) {",
	"    if ($start -eq 0) { $start = [Environment]::TickCount }",
	"    if ([Environment]::TickCount - $start -ge $DwellMs) {",
	"      Set-Content -LiteralPath $MarkerFile -Value \"read;\" -Encoding ASCII",
	"      break",
	"    }",
	"  } else {",
	"    $start = 0",
	"  }",
	"  Start-Sleep -Milliseconds 120",
	"}"
])
