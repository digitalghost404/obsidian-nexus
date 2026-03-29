# autoloads/note_graph.gd
extends RefCounted
class_name NoteGraph

const VaultParser = preload("res://autoloads/vault_parser.gd")

# note_id → NoteData
var _notes: Dictionary = {}
# note_id → Array[String] of backlink source IDs
var _backlinks: Dictionary = {}
# tag → Array[String] of note IDs
var _tag_index: Dictionary = {}

signal note_added(note_id: String)
signal note_updated(note_id: String)
signal note_removed(note_id: String)
signal graph_rebuilt()

func add_note(note: VaultParser.NoteData) -> void:
	_notes[note.id] = note
	for tag in note.tags:
		if not _tag_index.has(tag):
			_tag_index[tag] = []
		if note.id not in _tag_index[tag]:
			_tag_index[tag].append(note.id)
	note_added.emit(note.id)

func remove_note(note_id: String) -> void:
	if _notes.has(note_id):
		var note: VaultParser.NoteData = _notes[note_id]
		for tag in note.tags:
			if _tag_index.has(tag):
				_tag_index[tag].erase(note_id)
				if _tag_index[tag].is_empty():
					_tag_index.erase(tag)
		_notes.erase(note_id)
		_backlinks.erase(note_id)
		note_removed.emit(note_id)

func update_note(note: VaultParser.NoteData) -> void:
	remove_note(note.id)
	add_note(note)
	compute_backlinks()
	note_updated.emit(note.id)

func get_note(note_id: String) -> VaultParser.NoteData:
	return _notes.get(note_id)

func get_all_notes() -> Array:
	return _notes.values()

func get_all_note_ids() -> Array:
	return _notes.keys()

func compute_backlinks() -> void:
	_backlinks.clear()
	for note_id in _notes:
		var note: VaultParser.NoteData = _notes[note_id]
		for link in note.outgoing_links:
			if not _backlinks.has(link):
				_backlinks[link] = []
			if note_id not in _backlinks[link]:
				_backlinks[link].append(note_id)

func get_backlinks(note_id: String) -> Array:
	return _backlinks.get(note_id, [])

func get_connection_count(note_id: String) -> int:
	var note: VaultParser.NoteData = _notes.get(note_id)
	if not note:
		return 0
	return note.outgoing_links.size() + get_backlinks(note_id).size()

func get_notes_by_tag(tag: String) -> Array:
	var note_ids: Array = _tag_index.get(tag, [])
	var notes: Array = []
	for nid in note_ids:
		if _notes.has(nid):
			notes.append(_notes[nid])
	return notes

func get_all_tags() -> Array:
	var tags := _tag_index.keys()
	tags.sort()
	return tags

func get_notes_by_folder(folder: String) -> Array:
	var result: Array = []
	for note in _notes.values():
		if note.folder == folder:
			result.append(note)
	return result

func get_all_folders() -> Array:
	var folders: Dictionary = {}
	for note in _notes.values():
		if not note.folder.is_empty():
			folders[note.folder] = true
	var result := folders.keys()
	result.sort()
	return result

func get_note_count() -> int:
	return _notes.size()

func get_link_count() -> int:
	var count := 0
	for note in _notes.values():
		count += note.outgoing_links.size()
	return count

func clear() -> void:
	_notes.clear()
	_backlinks.clear()
	_tag_index.clear()

func to_cache_dict() -> Dictionary:
	var data := {}
	for note_id in _notes:
		var note: VaultParser.NoteData = _notes[note_id]
		data[note_id] = {
			"title": note.title,
			"content": note.content,
			"folder": note.folder,
			"tags": note.tags,
			"outgoing_links": note.outgoing_links,
			"word_count": note.word_count,
			"last_modified": note.last_modified,
		}
	return data

func from_cache_dict(data: Dictionary) -> void:
	clear()
	for note_id in data:
		var d: Dictionary = data[note_id]
		var note := VaultParser.NoteData.new()
		note.id = note_id
		note.title = d.get("title", "")
		note.content = d.get("content", "")
		note.folder = d.get("folder", "")
		note.tags.assign(d.get("tags", []))
		note.outgoing_links.assign(d.get("outgoing_links", []))
		note.word_count = d.get("word_count", 0)
		note.last_modified = d.get("last_modified", 0)
		add_note(note)
	compute_backlinks()
	graph_rebuilt.emit()
