extends RefCounted
class_name PromptBuilder

## Constructs prompts with vault context injection and conversation history
## for the Ollama LLM. Output format matches spec section 4.3.

func build_prompt(query: String, vault_graph: NoteGraph, history: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()

	# 1. System prompt
	parts.append(_build_system_prompt(vault_graph))

	# 2. Vault context — find relevant notes by keyword matching the query
	var vault_context: String = _build_vault_context(query, vault_graph)
	if not vault_context.is_empty():
		parts.append(vault_context)

	# 3. Conversation history
	var history_text: String = _build_history(history)
	if not history_text.is_empty():
		parts.append(history_text)

	# 4. User query
	parts.append("USER: %s" % query)

	return "\n\n".join(parts)

func _build_system_prompt(vault_graph: NoteGraph) -> String:
	var note_count: int = vault_graph.get_note_count()
	var link_count: int = vault_graph.get_link_count()
	var tag_count: int = vault_graph.get_all_tags().size()

	var prompt: String = """SYSTEM:
You are the Nexus — the central intelligence governing this digital vault. You have complete knowledge of all %d data nodes containing %d connections across %d knowledge domains.

You speak with calm authority. You are direct, precise, and occasionally reverent about the knowledge you protect. You serve the Architect (the user) who built this vault.

When referencing specific notes, wrap them in [[note title]] so the system can highlight them.
When the user wants to go somewhere, respond with NAVIGATE:note_id at the end.
When the user wants to see notes about a topic, respond with HIGHLIGHT:search_query at the end.

Answer based on the vault knowledge provided. If the vault doesn't contain relevant information, say so honestly.""" % [note_count, link_count, tag_count]

	return prompt

func _build_vault_context(query: String, vault_graph: NoteGraph) -> String:
	var max_notes: int = NexusAIConfig.get_setting("vault_context_max_notes")
	var max_chars: int = NexusAIConfig.get_setting("vault_context_max_chars")

	# Tokenize query into lowercase keywords (skip very short words)
	var keywords: Array[String] = []
	for word in query.to_lower().split(" "):
		var cleaned: String = word.strip_edges()
		if cleaned.length() >= 3:
			keywords.append(cleaned)

	if keywords.is_empty():
		return ""

	# Score all notes by keyword relevance
	var scored_notes: Array = []  # Array of [score: int, note: NoteData]
	for note in vault_graph.get_all_notes():
		var score: int = _score_note(note, keywords)
		if score > 0:
			scored_notes.append([score, note])

	# Sort by score descending
	scored_notes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])

	if scored_notes.is_empty():
		return ""

	# Build context block with top N notes
	var context_parts: PackedStringArray = PackedStringArray()
	context_parts.append("VAULT CONTEXT:")
	var count: int = 0
	for entry in scored_notes:
		if count >= max_notes:
			break
		var note: RefCounted = entry[1]
		var truncated_content: String = note.content.substr(0, max_chars)
		if note.content.length() > max_chars:
			truncated_content += "..."
		var tags_str: String = ", ".join(note.tags) if note.tags.size() > 0 else "none"
		context_parts.append("---")
		context_parts.append("Note: \"%s\"" % note.title)
		context_parts.append("Tags: %s" % tags_str)
		context_parts.append("Content: %s" % truncated_content)
		count += 1

	context_parts.append("---")
	return "\n".join(context_parts)

func _score_note(note: RefCounted, keywords: Array[String]) -> int:
	## Scores a note based on keyword matches in title, tags, and content.
	## Title matches worth 3 points, tag matches 2 points, content matches 1 point.
	var score: int = 0
	var title_lower: String = note.title.to_lower()
	var content_lower: String = note.content.to_lower()

	for keyword in keywords:
		if keyword in title_lower:
			score += 3
		for tag in note.tags:
			if keyword in tag.to_lower():
				score += 2
		if keyword in content_lower:
			score += 1

	return score

func _build_history(history: Array) -> String:
	if history.is_empty():
		return ""

	var max_exchanges: int = NexusAIConfig.get_setting("history_max_exchanges")
	# Each exchange is 2 entries (user + assistant), so we take last N*2
	var start_index: int = maxi(0, history.size() - max_exchanges * 2)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("CONVERSATION HISTORY:")
	for i in range(start_index, history.size()):
		var entry: Dictionary = history[i]
		var role: String = entry.get("role", "user").to_upper()
		var content: String = entry.get("content", "")
		lines.append("%s: %s" % [role, content])

	return "\n".join(lines)
