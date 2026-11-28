extends Node

# Phase 3 slice: a restorable "dramatic close" gag. Browser tabs use the
# browser's own close/restore shortcuts. Non-browser windows are only eligible
# when the human explicitly adds them to a local allowlist; the original
# command line is captured and used to bring the app back. Nothing here kills
# a process or closes an allowlisted window without a graceful WM_CLOSE.

const ALLOWLIST_FILE := "jeremy_close_allowlist.cfg"
const INFO_FILE := "jeremy_dramatic_close.json"

const PROBE_SCRIPT := "jeremy_dramatic_probe.ps1"
const CLOSE_TAB_SCRIPT := "jeremy_dramatic_close_tab.ps1"
const RESTORE_TAB_SCRIPT := "jeremy_dramatic_restore_tab.ps1"
const CLOSE_WINDOW_SCRIPT := "jeremy_dramatic_close_window.ps1"
const RESTORE_WINDOW_SCRIPT := "jeremy_dramatic_restore_window.ps1"

const RESTORE_DELAY := 1.1

const DENIED_PROCESSES := [
	"godot",
	"jeremy",
	"explorer",
	"taskmgr",
	"cmd",
	"powershell",
	"pwsh",
	"conhost",
	"windowsterminal",
	"searchhost",
	"startmenuexperiencehost",
	"applicationframehost",
	"dwm",
	"csrss",
	"winlogon",
	"services",
	"lsass"
]

var last_info := {}
var captured_info := {}

var _probe_ps := "\n".join([
	'$ErrorActionPreference = "Stop"',
	'Add-Type @"',
	'using System;',
	'using System.Runtime.InteropServices;',
	'using System.Text;',
	'public static class JeremyDramaticProbe {',
	'  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();',
	'  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);',
	'  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);',
	'  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);',
	'  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);',
	'  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }',
	'}',
	'"@',
	'$h = [JeremyDramaticProbe]::GetForegroundWindow()',
	'if ($h -eq [IntPtr]::Zero) { Write-Output "{}"; exit 0 }',
	'$targetPid = [uint32]0',
	'[JeremyDramaticProbe]::GetWindowThreadProcessId($h, [ref]$targetPid) | Out-Null',
	'$title = New-Object System.Text.StringBuilder 512',
	'[JeremyDramaticProbe]::GetWindowText($h, $title, 512) | Out-Null',
	'$class = New-Object System.Text.StringBuilder 256',
	'[JeremyDramaticProbe]::GetClassName($h, $class, 256) | Out-Null',
	'$rect = New-Object JeremyDramaticProbe+RECT',
	'[JeremyDramaticProbe]::GetWindowRect($h, [ref]$rect) | Out-Null',
	'$proc = Get-CimInstance Win32_Process -Filter "ProcessId=$targetPid" -ErrorAction SilentlyContinue',
	'$procName = ""',
	'$exe = ""',
	'$command = ""',
	'if ($proc) {',
	'  $procName = [string]$proc.Name',
	'  $exe = [string]$proc.ExecutablePath',
	'  $command = [string]$proc.CommandLine',
	'}',
	'$info = [ordered]@{',
	'  class = $class.ToString()',
	'  title = $title.ToString()',
	'  pid = [int]$targetPid',
	'  name = $procName',
	'  exe = $exe',
	'  command = $command',
	'  left = $rect.Left',
	'  top = $rect.Top',
	'  right = $rect.Right',
	'  bottom = $rect.Bottom',
	'}',
	'$info | ConvertTo-Json -Compress -Depth 3'
])

var _close_tab_ps := "\n".join([
	'param([int]$TargetPid)',
	'Add-Type -AssemblyName Microsoft.VisualBasic',
	'Add-Type -AssemblyName System.Windows.Forms',
	'try { [Microsoft.VisualBasic.Interaction]::AppActivate($TargetPid) } catch {}',
	'Start-Sleep -Milliseconds 80',
	'[System.Windows.Forms.SendKeys]::SendWait("^w")',
	'Write-Output "closing"'
])

var _restore_tab_ps := "\n".join([
	'param([int]$TargetPid)',
	'Add-Type -AssemblyName Microsoft.VisualBasic',
	'Add-Type -AssemblyName System.Windows.Forms',
	'try { [Microsoft.VisualBasic.Interaction]::AppActivate($TargetPid) } catch {}',
	'Start-Sleep -Milliseconds 200',
	'[System.Windows.Forms.SendKeys]::SendWait("^+t")',
	'Write-Output "restored"'
])

var _close_window_ps := "\n".join([
	'param([int]$TargetPid)',
	'$p = Get-Process -Id $TargetPid -ErrorAction SilentlyContinue',
	'if (-not $p) { Write-Output "closed"; exit 0 }',
	'if ($p.CloseMainWindow()) { Write-Output "closing" } else { Write-Output "failed" }'
])

var _restore_window_ps := "\n".join([
	'param([string]$InfoFile)',
	'$info = Get-Content -LiteralPath $InfoFile -Raw | ConvertFrom-Json',
	'$cmd = [string]$info.command',
	'if ([string]::IsNullOrWhiteSpace($cmd)) { $cmd = [string]$info.exe }',
	'if ([string]::IsNullOrWhiteSpace($cmd)) { Write-Output "failed"; exit 1 }',
	'Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd } | Out-Null',
	'Write-Output "restored"'
])


func perform(info: Dictionary = {}) -> bool:
	var target := _target_info(info)
	if target.is_empty() or _is_denied(target):
		return false

	var browser := _is_browser(target)
	if not browser and not is_allowlisted(target):
		return false

	var target_pid := int(target.get("pid", 0))
	var ok := false

	if browser:
		ok = _expect(_run_ps(CLOSE_TAB_SCRIPT, _close_tab_ps, [str(target_pid)]), "closing")
	else:
		_write_info(target)
		var output := _run_ps(CLOSE_WINDOW_SCRIPT, _close_window_ps, [str(target_pid)])
		ok = _expect(output, "closing") or _expect(output, "closed")

	if not ok:
		return false

	target["browser"] = browser
	last_info = target
	_restore_after_delay(target, browser)
	return true


func add_foreground_to_allowlist(info: Dictionary = {}) -> bool:
	var target := _target_info(info)
	if target.is_empty() or _is_denied(target) or _is_browser(target):
		return false

	var entry := {
		"class": str(target.get("class", "")),
		"title": str(target.get("title", "")),
		"name": str(target.get("name", "")),
		"exe": str(target.get("exe", ""))
	}

	if entry["name"].is_empty() and entry["class"].is_empty():
		return false

	var entries := get_allowlist()

	for existing in entries:
		if (
			str(existing.get("name", "")) == entry["name"]
			and str(existing.get("class", "")) == entry["class"]
			and str(existing.get("title", "")) == entry["title"]
		):
			return false

	entries.append(entry)

	var config := ConfigFile.new()
	config.set_value("jeremy", "allowed", entries)
	return config.save(_user_path(ALLOWLIST_FILE)) == OK


func get_allowlist() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var config := ConfigFile.new()

	if config.load(_user_path(ALLOWLIST_FILE)) != OK:
		return result

	var entries: Variant = config.get_value("jeremy", "allowed", [])

	if not (entries is Array):
		return result

	for item in entries:
		if item is Dictionary:
			result.append(item as Dictionary)

	return result


func get_allowlist_count() -> int:
	return get_allowlist().size()


# The action menu can cover the target window, so right-click captures the
# current foreground before the menu is created and the buttons use that
# snapshot. Autonomous closes still fall back to a live probe.
func capture_foreground() -> Dictionary:
	captured_info = probe()
	return captured_info.duplicate(true)


func get_captured_info() -> Dictionary:
	return captured_info.duplicate(true)


func clear_capture() -> void:
	captured_info = {}


func _target_info(info: Dictionary) -> Dictionary:
	if not info.is_empty():
		return info.duplicate(true)
	if not captured_info.is_empty():
		return captured_info.duplicate(true)
	return probe()


func probe() -> Dictionary:
	var output := _run_ps(PROBE_SCRIPT, _probe_ps, [])

	for line in output:
		var text := str(line).strip_edges()
		if not text.begins_with("{"):
			continue

		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			return parsed as Dictionary

	return {}


func is_allowlisted(info: Dictionary) -> bool:
	var info_name := str(info.get("name", "")).to_lower()
	var info_class := str(info.get("class", "")).to_lower()
	var info_title := str(info.get("title", ""))

	for entry in get_allowlist():
		var name_match := str(entry.get("name", "")).to_lower() == info_name
		var class_match := str(entry.get("class", "")).to_lower() == info_class
		var title := str(entry.get("title", ""))
		var title_match := title.is_empty() or title == info_title

		if name_match and class_match and title_match:
			return true

	return false


func _is_browser(info: Dictionary) -> bool:
	var window_class := str(info.get("class", "")).to_lower()

	return (
		window_class.begins_with("chrome_widgetwin")
		or window_class.begins_with("mozillawindowclass")
		or window_class.begins_with("chromium")
	)


func _is_denied(info: Dictionary) -> bool:
	var name := str(info.get("name", "")).to_lower()
	var window_class := str(info.get("class", "")).to_lower()
	var title := str(info.get("title", "")).to_lower()
	var exe := str(info.get("exe", "")).to_lower()

	for denied in DENIED_PROCESSES:
		if name == denied or name.begins_with(denied):
			return true

	if window_class.contains("godot") or exe.contains("godot"):
		return true

	if title.contains("jeremy") or title.contains("task manager"):
		return true

	return false


func _restore_after_delay(info: Dictionary, browser: bool) -> void:
	await get_tree().create_timer(RESTORE_DELAY).timeout

	if browser:
		_run_ps(RESTORE_TAB_SCRIPT, _restore_tab_ps, [str(info.get("pid", 0))])
	else:
		_run_ps(RESTORE_WINDOW_SCRIPT, _restore_window_ps, [_user_path(INFO_FILE)])


func _write_info(info: Dictionary) -> void:
	var file := FileAccess.open(_user_path(INFO_FILE), FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(info))
	file.close()


func _run_ps(script_name: String, script: String, args: Array[String]) -> Array[String]:
	var path := _write_script(script_name, script)
	if path.is_empty():
		return []

	var command := PackedStringArray(["-NoProfile", "-File", path])

	for arg in args:
		command.append(arg)

	var output: Array[String] = []

	if OS.execute("powershell.exe", command, output) != 0:
		return []

	return output


func _write_script(file_name: String, script: String) -> String:
	var path := _user_path(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return ""

	file.store_string(script)
	file.close()
	return path


func _expect(output: Array[String], token: String) -> bool:
	for line in output:
		if str(line).strip_edges() == token:
			return true
	return false


func _user_path(file_name: String) -> String:
	return ProjectSettings.globalize_path("user://" + file_name)
