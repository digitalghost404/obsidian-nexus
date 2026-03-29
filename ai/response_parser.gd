extends RefCounted
class_name ResponseParser

## Parses LLM response text to extract:
## - [[note title]] references (resolved to note IDs via vault graph)
## - NAVIGATE: commands (various formats the LLM might use)
## - HIGHLIGHT: commands

var _wikilink_regex: RegEx
var _navigate_regex: RegEx
var _navigate_noteid_regex: RegEx
var _highlight_regex: RegEx

func _init() -> void:
	_wikilink_regex = RegEx.new()
	_wikilink_regex.compile("\\[\\[([^\\]]+?)\\]\\]")

	# Match NAVIGATE: followed by anything until end of line
	_navigate_regex = RegEx.new()
	_navigate_regex.compile("(?m)NAVIGATE:\\s*(.+?)\\s*$")

	# Match note_id("...") format the LLM sometimes uses
	_navigate_noteid_regex = RegEx.new()
	_navigate_noteid_regex.compile('note_id\\("([^"]+)"\\)')

	# Match HIGHLIGHT: followed by anything until end of line
	_highlight_regex = RegEx.new()
	_highlight_regex.compile("(?m)HIGHLIGHT:\\s*(.+?)\\s*$")

func parse(response_text: String, vault_graph: NoteGraph) -> Dictionary:
	var result: Dictionary = {
		"text": "",
		"referenced_notes": [],
		"navigate_to": "",
		"highlight_query": "",
	}

	var text: String = response_text.strip_edges()

	# Extract ALL NAVIGATE: commands (LLM might put multiple)
	var nav_matches: Array[RegExMatch] = _navigate_regex.search_all(text)
	for nav_match in nav_matches:
		var nav_raw: String = nav_match.get_string(1).strip_edges()
		# Check if it uses note_id("...") format
		var noteid_match: RegExMatch = _navigate_noteid_regex.search(nav_raw)
		if noteid_match:
			var nav_target: String = noteid_match.get_string(1).strip_edges()
			if result["navigate_to"].is_empty():
				result["navigate_to"] = _resolve_note_id(nav_target, vault_graph)
		else:
			# Raw text after NAVIGATE:
			var nav_target: String = _clean_command_value(nav_raw)
			if result["navigate_to"].is_empty():
				result["navigate_to"] = _resolve_note_id(nav_target, vault_graph)
		# Remove the command line from text
		text = text.replace(nav_match.get_string(), "").strip_edges()

	# Extract HIGHLIGHT: commands
	var hl_matches: Array[RegExMatch] = _highlight_regex.search_all(text)
	for hl_match in hl_matches:
		var hl_raw: String = hl_match.get_string(1).strip_edges()
		if result["highlight_query"].is_empty():
			result["highlight_query"] = _clean_command_value(hl_raw)
		text = text.replace(hl_match.get_string(), "").strip_edges()

	# Extract [[note title]] references
	var referenced_notes: Array = []
	var wiki_matches: Array[RegExMatch] = _wikilink_regex.search_all(text)
	for m in wiki_matches:
		var title: String = m.get_string(1).strip_edges()
		var note_id: String = _resolve_note_id(title, vault_graph)
		if not note_id.is_empty() and note_id not in referenced_notes:
			referenced_notes.append(note_id)

	result["referenced_notes"] = referenced_notes
	result["text"] = text

	return result

func _clean_command_value(raw: String) -> String:
	## Strip quotes, note_id() wrapper, and other LLM formatting artifacts
	var cleaned: String = raw.strip_edges()
	# Remove note_id("...") wrapper
	var noteid_match: RegExMatch = _navigate_noteid_regex.search(cleaned)
	if noteid_match:
		cleaned = noteid_match.get_string(1)
	# Remove "note_id " prefix (without parens — LLM sometimes writes this)
	if cleaned.begins_with("note_id "):
		cleaned = cleaned.substr(8)
	# Remove surrounding quotes
	if cleaned.begins_with("\"") and cleaned.ends_with("\""):
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	if cleaned.begins_with("'") and cleaned.ends_with("'"):
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	# Remove trailing punctuation the LLM might add
	while cleaned.ends_with(".") or cleaned.ends_with(",") or cleaned.ends_with(";"):
		cleaned = cleaned.substr(0, cleaned.length() - 1)
	return cleaned.strip_edges()

func _resolve_note_id(title_or_id: String, vault_graph: NoteGraph) -> String:
	## Tries to find a note matching the given title or ID.
	## Handles: exact ID, exact title, partial title, filename-only, folder/filename

	var search: String = title_or_id.strip_edges()
	if search.is_empty():
		return ""

	# Direct ID match
	var note: RefCounted = vault_graph.get_note(search)
	if note:
		return search

	# Case-insensitive exact title match
	var lower_search: String = search.to_lower()
	for n in vault_graph.get_all_notes():
		if n.title.to_lower() == lower_search:
			return n.id

	# Filename-only match (strip folder path if present)
	var filename: String = search.get_file() if "/" in search else search
	var lower_filename: String = filename.to_lower()
	for n in vault_graph.get_all_notes():
		var n_filename: String = n.id.get_file()
		if n_filename.to_lower() == lower_filename:
			return n.id

	# Partial title match (search string contained in title)
	for n in vault_graph.get_all_notes():
		if lower_search in n.title.to_lower():
			return n.id

	# Partial ID match (search string contained in ID)
	for n in vault_graph.get_all_notes():
		if lower_search in n.id.to_lower():
			return n.id

	# Word-based match — all words in search appear in the title
	var words: PackedStringArray = lower_search.split(" ", false)
	if words.size() > 1:
		for n in vault_graph.get_all_notes():
			var lower_title: String = n.title.to_lower()
			var all_match: bool = true
			for word in words:
				if word not in lower_title:
					all_match = false
					break
			if all_match:
				return n.id

	print("ResponseParser: could not resolve '%s' to any note" % search)
	return ""
