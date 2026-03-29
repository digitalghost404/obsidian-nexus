extends CanvasLayer

var hover_panel: PanelContainer
var _crosshair: ColorRect

func _ready() -> void:
	layer = 5

	# Crosshair
	_crosshair = ColorRect.new()
	_crosshair.size = Vector2(4, 4)
	_crosshair.color = Color(1, 1, 1, 0.5)
	_crosshair.anchors_preset = Control.PRESET_CENTER
	_crosshair.position = -Vector2(2, 2)
	add_child(_crosshair)

	# Hover panel
	hover_panel = _create_hover_panel()
	add_child(hover_panel)
	hover_panel.hide()

	# Connect to InputManager signals
	InputManager.note_hovered.connect(_on_note_hovered)
	InputManager.note_unhovered.connect(_on_note_unhovered)
	InputManager.note_clicked.connect(_on_note_clicked)
	InputManager.search_requested.connect(_on_search_requested)
	InputManager.tag_filter_requested.connect(_on_tag_filter_requested)

func _create_hover_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.15, 0.9)
	style.border_color = Color(0.3, 0.4, 0.9, 0.5)
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"

	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	vbox.add_child(title)

	var tags := Label.new()
	tags.name = "Tags"
	tags.add_theme_font_size_override("font_size", 12)
	tags.add_theme_color_override("font_color", Color(0.5, 0.55, 0.85))
	vbox.add_child(tags)

	var preview := RichTextLabel.new()
	preview.name = "Preview"
	preview.custom_minimum_size = Vector2(300, 80)
	preview.bbcode_enabled = false
	preview.scroll_active = false
	preview.add_theme_font_size_override("normal_font_size", 13)
	preview.add_theme_color_override("default_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(preview)

	var connections := Label.new()
	connections.name = "Connections"
	connections.add_theme_font_size_override("font_size", 12)
	connections.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9))
	vbox.add_child(connections)

	panel.add_child(vbox)
	return panel

func _on_note_hovered(note_id: String) -> void:
	var note = VaultDataBus.graph.get_note(note_id)
	if not note:
		hover_panel.hide()
		return

	var vbox = hover_panel.get_node("VBox")
	vbox.get_node("Title").text = note.title
	vbox.get_node("Tags").text = ", ".join(note.tags) if note.tags.size() > 0 else "no tags"
	var preview_text := note.content.substr(0, 200)
	if note.content.length() > 200:
		preview_text += "..."
	vbox.get_node("Preview").text = preview_text
	vbox.get_node("Connections").text = "%d connections" % VaultDataBus.graph.get_connection_count(note_id)

	var mouse_pos := get_viewport().get_mouse_position()
	hover_panel.position = mouse_pos + Vector2(20, 20)
	hover_panel.show()

func _on_note_unhovered() -> void:
	hover_panel.hide()

func _on_note_clicked(note_id: String) -> void:
	if LayerManager.current_layer != LayerManager.Layer.CORRIDOR:
		LayerManager.transition_to(LayerManager.Layer.CORRIDOR, {"note_id": note_id})
	else:
		var corridor = LayerManager.current_scene
		if corridor and corridor.has_method("build_corridor"):
			corridor.build_corridor(note_id)

func _on_search_requested() -> void:
	var search_dialog := AcceptDialog.new()
	search_dialog.title = "Search Vault"
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "Search notes..."
	search_dialog.add_child(line_edit)
	add_child(search_dialog)
	search_dialog.popup_centered(Vector2(400, 100))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	line_edit.text_submitted.connect(func(query: String):
		var results: Array = []
		var lower_q := query.to_lower()
		for note in VaultDataBus.graph.get_all_notes():
			if lower_q in note.title.to_lower() or lower_q in note.content.to_lower():
				results.append(note.id)
		if LayerManager.current_scene and LayerManager.current_scene.has_method("highlight_notes"):
			LayerManager.current_scene.highlight_notes(results)
		search_dialog.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

func _on_tag_filter_requested() -> void:
	var tag_dialog := AcceptDialog.new()
	tag_dialog.title = "Filter by Tag"
	var option := OptionButton.new()
	option.add_item("-- Select Tag --")
	for tag in VaultDataBus.graph.get_all_tags():
		var count := VaultDataBus.graph.get_notes_by_tag(tag).size()
		option.add_item("%s (%d)" % [tag, count])
	tag_dialog.add_child(option)
	add_child(tag_dialog)
	tag_dialog.popup_centered(Vector2(400, 100))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	tag_dialog.confirmed.connect(func():
		var selected := option.get_item_text(option.selected)
		if selected == "-- Select Tag --":
			if LayerManager.current_scene and LayerManager.current_scene.has_method("clear_highlights"):
				LayerManager.current_scene.clear_highlights()
		else:
			var tag := selected.split(" (")[0]
			var tag_notes := VaultDataBus.graph.get_notes_by_tag(tag)
			var ids: Array = []
			for n in tag_notes:
				ids.append(n.id)
			if LayerManager.current_scene and LayerManager.current_scene.has_method("highlight_notes"):
				LayerManager.current_scene.highlight_notes(ids)
		tag_dialog.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
