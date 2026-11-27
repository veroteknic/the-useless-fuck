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

const NOTE_DIR_NAME := "jeremy_notes"
const NOTE_WINDOW_SIZE := Vector2i(380, 230)
const LAUNCH_SCRIPT_NAME := "jeremy_open_notepad.ps1"
const CLOSE_SCRIPT_NAME := "jeremy_close_notepad.ps1"

var notes: Array[Dictionary] = []
var next_note_timer := 0.0
var next_note_number := 1

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
	"\"pid=$($proc.Id)\"",
	"\"hwnd=$($hwnd.ToInt64())\""
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
	var file_path := _write_note_file(text)
	if file_path.is_empty():
		return

	var hint := Vector2(DisplayServer.mouse_get_position())
	var position := _random_note_position(NOTE_WINDOW_SIZE, hint)
	var info_file := _user_path("jeremy_notepad_info.txt")
	var script_path := _write_user_script(LAUNCH_SCRIPT_NAME, launch_ps)
	if script_path.is_empty():
		return

	var output: Array[String] = []
	OS.execute("powershell.exe", PackedStringArray([
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
	]), output, true)

	var info := _parse_info(output)
	var pid := int(info.get("pid", "-1"))
	var hwnd := int(info.get("hwnd", "0"))

	notes.append({
		"file": file_path,
		"pid": pid,
		"hwnd": hwnd,
		"remaining": note_lifetime,
		"closing": false
	})


func _write_note_file(text: String) -> String:
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

	var file_name := "jeremy-note-%s-%02d.txt" % [stamp, next_note_number]
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


func _parse_info(output: Array[String]) -> Dictionary:
	var info := {}
	for raw_line in output:
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

	OS.execute("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-File",
		script_path,
		str(hwnd)
	]), [], true)
