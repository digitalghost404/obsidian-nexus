extends RefCounted
class_name ResponseParser

## Parses LLM response text to extract:
## - [[note title]] references (resolved to note IDs via vault graph)
## - NAVIGATE:note_id commands
## - HIGHLIGHT:search_query commands

var _wikilink_regex: RegEx
var _navigate_regex: RegEx
var _highlight_regex: RegEx

func _init() -> void:
	_wikilink_regex = RegEx.new()
	_wikilink_regex.compile("\\[\\[([^\\]]+?)\\]\\]")

	_navigate_regex = RegEx.new()
	_navigate_regex.compile("NAVIGATE:([^\\s]+(?:\\s[^\\s]+)*?)\\s*$")

	_highlight_regex = RegEx.new()
	_highlight_regex.compile("HIGHLIGHT:([^\\s]+(?:\\s[^\\s]+)*?)\\s*$")

func parse(response_text: String, vault_graph: NoteGraph) -> Dictionary:
	## Returns:
	## {
	##   "text": String,                # Cleaned response (commands stripped)
	##   "referenced_notes": Array,     # Array of note IDs found via [[title]]
	##   "navigate_to": String,         # Note ID to navigate to (empty if none)
	##   "highlight_query": String,     # Search query for highlighting (empty if none)
	## }
	var result: Dictionary = {
		"text": "",
		"referenced_notes": [],
		"navigate_to": "",
		"highlight_query": "",
	}

	var text: String = response_text.strip_edges()

	# Extract NAVIGATE: command (must be at end of response)
	var nav_match: RegExMatch = _navigate_regex.search(text)
	if nav_match:
		var nav_target: String = nav_match.get_string(1).strip_edges()
		result["navigate_to"] = _resolve_note_id(nav_target, vault_graph)
		# Remove the command from text
		text = text.substr(0, nav_match.get_start()).strip_edges()

	# Extract HIGHLIGHT: command (must be at end of response, or before NAVIGATE)
	var hl_match: RegExMatch = _highlight_regex.search(text)
	if hl_match:
		result["highlight_query"] = hl_match.get_string(1).strip_edges()
		text = text.substr(0, hl_match.get_start()).strip_edges()

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

func _resolve_note_id(title_or_id: String, vault_graph: NoteGraph) -> String:
	## Tries to find a note matching the given title or ID.
	## First tries exact ID match, then title match (case-insensitive).

	# Direct ID match
	var note: RefCounted = vault_graph.get_note(title_or_id)
	if note:
		return title_or_id

	# Case-insensitive title search
	var lower_title: String = title_or_id.to_lower()
	for n in vault_graph.get_all_notes():
		if n.title.to_lower() == lower_title:
			return n.id

	# Partial match — title contains the search string
	for n in vault_graph.get_all_notes():
		if lower_title in n.title.to_lower():
			return n.id

	# Not found — return the raw input so callers can decide what to do
	return title_or_id
