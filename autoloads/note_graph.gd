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
# note_id → Vector3
var _positions: Dictionary = {}

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
	_positions.clear()

func compute_layout(iterations: int = 500) -> void:
	var note_ids := get_all_note_ids()
	for nid in note_ids:
		if not _positions.has(nid):
			_positions[nid] = Vector3(
				randf_range(-50.0, 50.0),
				randf_range(-50.0, 50.0),
				randf_range(-50.0, 50.0)
			)

	var repulsion_strength := 500.0
	var attraction_strength := 0.01
	var damping := 0.9
	var velocities: Dictionary = {}
	for nid in note_ids:
		velocities[nid] = Vector3.ZERO

	for iteration in range(iterations):
		var temperature := 1.0 - (float(iteration) / float(iterations))
		var forces: Dictionary = {}
		for nid in note_ids:
			forces[nid] = Vector3.ZERO

		# Repulsion between all pairs
		for i in range(note_ids.size()):
			for j in range(i + 1, note_ids.size()):
				var id_a: String = note_ids[i]
				var id_b: String = note_ids[j]
				var delta: Vector3 = _positions[id_a] - _positions[id_b]
				var dist := delta.length()
				if dist < 0.1:
					delta = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
					dist = delta.length()
				var force := delta.normalized() * (repulsion_strength / (dist * dist))
				forces[id_a] += force
				forces[id_b] -= force

		# Attraction along edges
		for nid in note_ids:
			var note: VaultParser.NoteData = _notes.get(nid)
			if not note:
				continue
			for link in note.outgoing_links:
				if _positions.has(link):
					var delta: Vector3 = _positions[link] - _positions[nid]
					var force := delta * attraction_strength
					forces[nid] += force
					if forces.has(link):
						forces[link] -= force

		# Apply forces with damping
		for nid in note_ids:
			velocities[nid] = (velocities[nid] + forces[nid]) * damping * temperature
			_positions[nid] += velocities[nid]

func get_position(note_id: String) -> Vector3:
	return _positions.get(note_id, Vector3.ZERO)

func set_position(note_id: String, pos: Vector3) -> void:
	_positions[note_id] = pos

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
			"position": var_to_str(_positions.get(note_id, Vector3.ZERO)),
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
		if d.has("position"):
			_positions[note_id] = str_to_var(d["position"])
	compute_backlinks()
	graph_rebuilt.emit()
