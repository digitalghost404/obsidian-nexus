extends RefCounted
class_name PromptBuilder

## Constructs prompts with vault context injection and conversation history

const STOP_WORDS: Array[String] = [
	"show", "me", "notes", "about", "the", "what", "do", "have", "take",
	"tell", "find", "search", "look", "get", "give", "list", "all",
	"for", "with", "from", "that", "this", "and", "are", "can", "how",
	"let", "see", "where", "which", "who", "related", "regarding",
]

func build_prompt(query: String, vault_graph: NoteGraph, history: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(_build_system_prompt(vault_graph))
	var vault_context: String = _build_vault_context(query, vault_graph)
	if not vault_context.is_empty():
		parts.append(vault_context)
	var history_text: String = _build_history(history)
	if not history_text.is_empty():
		parts.append(history_text)
	parts.append("USER: %s" % query)
	return "\n\n".join(parts)

func _build_system_prompt(vault_graph: NoteGraph) -> String:
	var note_count: int = vault_graph.get_note_count()
	var link_count: int = vault_graph.get_link_count()
	var tag_count: int = vault_graph.get_all_tags().size()

	var prompt: String = """SYSTEM:
You are the Nexus — the central intelligence governing this digital vault. You have complete knowledge of all %d data nodes containing %d connections across %d knowledge domains.

You speak with calm authority. You are direct, precise, and occasionally reverent about the knowledge you protect. You serve the Architect (the user) who built this vault.

RULES FOR COMMANDS (follow exactly):
- To reference a note: wrap in [[Note Title]]
- To teleport the user to a note: put NAVIGATE:Note Title on its own line at the very end
- To highlight notes about a topic: put HIGHLIGHT:topic on its own line at the very end
- Only one NAVIGATE or HIGHLIGHT per response. Put it on the LAST line by itself.
- Do NOT write note_id() or quotes around the note title. Just write the title plainly.

When listing notes, use their exact titles from the vault context provided.
Keep responses concise (2-4 sentences). Answer based on vault knowledge provided. If the vault doesn't contain relevant information, say so honestly.""" % [note_count, link_count, tag_count]

	return prompt

func _build_vault_context(query: String, vault_graph: NoteGraph) -> String:
	var max_notes: int = 8  # More context than config default
	var max_chars: int = 300

	# Extract meaningful keywords — filter out stop words
	var keywords: Array[String] = []
	for word in query.to_lower().split(" "):
		var cleaned: String = word.strip_edges().trim_suffix(".").trim_suffix(",").trim_suffix("?").trim_suffix("!")
		if cleaned.length() >= 2 and cleaned not in STOP_WORDS:
			keywords.append(cleaned)

	# If all keywords were stop words, use the longest word from query
	if keywords.is_empty():
		var longest: String = ""
		for word in query.to_lower().split(" "):
			var cleaned: String = word.strip_edges()
			if cleaned.length() > longest.length():
				longest = cleaned
		if longest.length() >= 2:
			keywords.append(longest)

	if keywords.is_empty():
		return ""

	print("PromptBuilder: searching vault with keywords: %s" % str(keywords))

	# Score all notes by keyword relevance
	var scored_notes: Array = []
	for note in vault_graph.get_all_notes():
		var score: int = _score_note(note, keywords)
		if score > 0:
			scored_notes.append([score, note])

	scored_notes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])

	print("PromptBuilder: found %d matching notes (top score: %d)" % [scored_notes.size(), scored_notes[0][0] if scored_notes.size() > 0 else 0])

	if scored_notes.is_empty():
		return "VAULT CONTEXT:\nNo notes found matching your query."

	# Build context block with top N notes
	var context_parts: PackedStringArray = PackedStringArray()
	context_parts.append("VAULT CONTEXT (most relevant notes):")
	var count: int = 0
	for entry in scored_notes:
		if count >= max_notes:
			break
		var note: RefCounted = entry[1]
		var score: int = entry[0]
		var truncated_content: String = note.content.substr(0, max_chars)
		if note.content.length() > max_chars:
			truncated_content += "..."
		var tags_str: String = ", ".join(note.tags) if note.tags.size() > 0 else "none"
		context_parts.append("---")
		context_parts.append("Note: \"%s\" (relevance: %d)" % [note.title, score])
		context_parts.append("Folder: %s" % note.folder)
		context_parts.append("Tags: %s" % tags_str)
		context_parts.append("Content: %s" % truncated_content)
		count += 1
		if count <= 3:
			print("PromptBuilder: #%d: %s (score=%d)" % [count, note.title, score])

	context_parts.append("---")
	return "\n".join(context_parts)

func _score_note(note: RefCounted, keywords: Array[String]) -> int:
	var score: int = 0
	var title_lower: String = note.title.to_lower()
	var content_lower: String = note.content.to_lower()
	var folder_lower: String = note.folder.to_lower()

	for keyword in keywords:
		# Title match — highest value
		if keyword in title_lower:
			score += 5
		# Folder match — strong signal
		if keyword in folder_lower:
			score += 4
		# Tag match
		for tag in note.tags:
			if keyword in tag.to_lower():
				score += 3
		# Content match
		if keyword in content_lower:
			score += 1

	return score

func _build_history(history: Array) -> String:
	if history.is_empty():
		return ""
	var max_exchanges: int = NexusAIConfig.get_setting("history_max_exchanges")
	var recent: Array = history.slice(-max_exchanges * 2)
	var parts: PackedStringArray = PackedStringArray()
	parts.append("CONVERSATION HISTORY:")
	for entry in recent:
		var role: String = entry.get("role", "")
		var content: String = entry.get("content", "")
		if role == "user":
			parts.append("User: %s" % content)
		elif role == "assistant":
			parts.append("Nexus: %s" % content)
	return "\n".join(parts)
