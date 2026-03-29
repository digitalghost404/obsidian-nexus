# autoloads/vault_parser.gd
extends RefCounted
class_name VaultParser

## Parsed note data structure
class NoteData:
	var id: String              # Unique ID (relative path without .md)
	var title: String
	var content: String         # Raw markdown body (without frontmatter)
	var folder: String
	var tags: Array[String]
	var outgoing_links: Array[String]
	var word_count: int
	var last_modified: int      # Unix timestamp

var _frontmatter_regex := RegEx.new()
var _wikilink_regex := RegEx.new()
var _inline_tag_regex := RegEx.new()

func _init() -> void:
	_frontmatter_regex.compile("^---\\n([\\s\\S]*?)\\n---")
	_wikilink_regex.compile("\\[\\[([^\\]\\|]+?)(?:\\|[^\\]]*)?\\]\\]")
	_inline_tag_regex.compile("(?:^|\\s)#([a-zA-Z][a-zA-Z0-9_-]*)")

func parse_note(raw_content: String, relative_path: String) -> NoteData:
	var note := NoteData.new()

	# ID from path
	note.id = relative_path.trim_suffix(".md")

	# Folder from path
	var slash_pos := relative_path.rfind("/")
	if slash_pos >= 0:
		note.folder = relative_path.substr(0, slash_pos)
	else:
		note.folder = ""

	# Parse frontmatter
	var frontmatter_tags: Array[String] = []
	var body := raw_content
	var fm_match := _frontmatter_regex.search(raw_content)
	if fm_match:
		var fm_text := fm_match.get_string(1)
		body = raw_content.substr(fm_match.get_end())
		note.title = _extract_fm_value(fm_text, "title")
		frontmatter_tags = _extract_fm_list(fm_text, "tags")

	# Title fallback to filename
	if note.title.is_empty():
		var filename := relative_path.get_file().trim_suffix(".md")
		note.title = filename

	note.content = body.strip_edges()

	# Parse wikilinks (deduplicated)
	var links_set: Dictionary = {}
	for m in _wikilink_regex.search_all(body):
		var link := m.get_string(1).strip_edges()
		if not link.is_empty():
			links_set[link] = true
	note.outgoing_links.assign(links_set.keys())

	# Parse inline tags
	var tags_set: Dictionary = {}
	for tag in frontmatter_tags:
		tags_set[tag] = true
	for m in _inline_tag_regex.search_all(body):
		var tag := m.get_string(1).strip_edges()
		if not tag.is_empty():
			tags_set[tag] = true
	note.tags.assign(tags_set.keys())

	# Word count (body only)
	var words := body.strip_edges().split(" ", false)
	var count := 0
	for word in words:
		var clean := word.strip_edges()
		if not clean.is_empty() and not clean.begins_with("#") and not clean.begins_with("---"):
			count += 1
	note.word_count = count

	return note

func parse_vault_directory(vault_path: String) -> Array[NoteData]:
	var notes: Array[NoteData] = []
	_scan_directory(vault_path, vault_path, notes)
	return notes

func _scan_directory(base_path: String, current_path: String, notes: Array[NoteData]) -> void:
	var dir := DirAccess.open(current_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := current_path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_directory(base_path, full_path, notes)
		elif file_name.ends_with(".md"):
			var relative := full_path.substr(base_path.length() + 1)
			var content := FileAccess.get_file_as_string(full_path)
			var note := parse_note(content, relative)
			note.last_modified = FileAccess.get_modified_time(full_path)
			notes.append(note)
		file_name = dir.get_next()
	dir.list_dir_end()

func _extract_fm_value(fm_text: String, key: String) -> String:
	for line in fm_text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with(key + ":"):
			var value := trimmed.substr(key.length() + 1).strip_edges()
			if value.begins_with("\"") and value.ends_with("\""):
				value = value.substr(1, value.length() - 2)
			return value
	return ""

func _extract_fm_list(fm_text: String, key: String) -> Array[String]:
	var result: Array[String] = []
	for line in fm_text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with(key + ":"):
			var value := trimmed.substr(key.length() + 1).strip_edges()
			if value.begins_with("[") and value.ends_with("]"):
				var inner := value.substr(1, value.length() - 2)
				for item in inner.split(","):
					var clean := item.strip_edges()
					if not clean.is_empty():
						result.append(clean)
			elif not value.is_empty():
				result.append(value)
	return result
