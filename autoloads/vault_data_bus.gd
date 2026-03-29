# autoloads/vault_data_bus.gd
extends Node

const VaultParserClass = preload("res://autoloads/vault_parser.gd")
const NoteGraphClass = preload("res://autoloads/note_graph.gd")

var parser: VaultParserClass
var graph: NoteGraphClass
var vault_path: String
var cache_path: String

var _watcher_timer: Timer
var _file_mtimes: Dictionary = {}  # path → mtime for change detection

signal vault_loaded()
signal vault_error(message: String)

func _ready() -> void:
	parser = VaultParserClass.new()
	graph = NoteGraphClass.new()

func initialize(p_vault_path: String, p_cache_path: String = "") -> void:
	vault_path = p_vault_path
	if p_cache_path.is_empty():
		cache_path = vault_path.path_join(".obsidian-nexus-cache.json")
	else:
		cache_path = p_cache_path

	if FileAccess.file_exists(cache_path):
		print("VaultDataBus: loading from cache")
		_load_from_cache()
		_diff_and_patch()
	else:
		print("VaultDataBus: full parse (no cache)")
		_full_parse()

	_save_cache()
	_start_watcher()
	vault_loaded.emit()
	print("VaultDataBus: loaded %d notes, %d links" % [graph.get_note_count(), graph.get_link_count()])

func _full_parse() -> void:
	graph.clear()
	var notes := parser.parse_vault_directory(vault_path)
	for note in notes:
		graph.add_note(note)
		var full_path := vault_path.path_join(note.id + ".md")
		_file_mtimes[full_path] = note.last_modified
	graph.compute_backlinks()

func _load_from_cache() -> void:
	var file := FileAccess.open(cache_path, FileAccess.READ)
	if not file:
		_full_parse()
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		_full_parse()
		return
	graph.from_cache_dict(json.data)

func _save_cache() -> void:
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if not file:
		push_warning("VaultDataBus: could not write cache to %s" % cache_path)
		return
	var json := JSON.stringify(graph.to_cache_dict(), "\t")
	file.store_string(json)
	file.close()

func _diff_and_patch() -> void:
	var current_notes := parser.parse_vault_directory(vault_path)
	var current_ids: Dictionary = {}
	for note in current_notes:
		current_ids[note.id] = note
		var cached := graph.get_note(note.id)
		if not cached or cached.last_modified < note.last_modified:
			graph.update_note(note)

	for note_id in graph.get_all_note_ids():
		if not current_ids.has(note_id):
			graph.remove_note(note_id)

	graph.compute_backlinks()

func _start_watcher() -> void:
	_watcher_timer = Timer.new()
	_watcher_timer.wait_time = 2.0
	_watcher_timer.timeout.connect(_check_for_changes)
	add_child(_watcher_timer)
	_watcher_timer.start()

	for note in graph.get_all_notes():
		var full_path := vault_path.path_join(note.id + ".md")
		_file_mtimes[full_path] = note.last_modified

func _check_for_changes() -> void:
	var dir := DirAccess.open(vault_path)
	if not dir:
		return
	_scan_for_changes(vault_path)

func _scan_for_changes(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_for_changes(full_path)
		elif file_name.ends_with(".md"):
			var mtime := FileAccess.get_modified_time(full_path)
			var old_mtime: int = _file_mtimes.get(full_path, 0)
			if mtime != old_mtime:
				_file_mtimes[full_path] = mtime
				_reload_single_note(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _reload_single_note(full_path: String) -> void:
	var relative := full_path.substr(vault_path.length() + 1)
	var content := FileAccess.get_file_as_string(full_path)
	if content.is_empty():
		return
	var note := parser.parse_note(content, relative)
	note.last_modified = FileAccess.get_modified_time(full_path)
	graph.update_note(note)
	_save_cache()
	print("VaultDataBus: hot-reloaded %s" % note.title)
