extends CanvasLayer

var hover_panel: PanelContainer
var note_viewer: Control
var _crosshair: ColorRect
var _viewer_open: bool = false

func _ready() -> void:
	layer = 5

	# Crosshair
	_crosshair = ColorRect.new()
	_crosshair.size = Vector2(4, 4)
	_crosshair.color = Color(1, 1, 1, 0.5)
	_crosshair.anchors_preset = Control.PRESET_CENTER
	_crosshair.position = -Vector2(2, 2)
	add_child(_crosshair)

	# Hover panel (small tooltip)
	hover_panel = _create_hover_panel()
	add_child(hover_panel)
	hover_panel.hide()

	# Note viewer (full overlay)
	note_viewer = _create_note_viewer()
	add_child(note_viewer)
	note_viewer.hide()

	# Connect signals
	InputManager.note_hovered.connect(_on_note_hovered)
	InputManager.note_unhovered.connect(_on_note_unhovered)
	InputManager.note_clicked.connect(_on_note_clicked)
	InputManager.search_requested.connect(_on_search_requested)
	InputManager.tag_filter_requested.connect(_on_tag_filter_requested)

func _unhandled_input(event: InputEvent) -> void:
	if _viewer_open and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_Q:
			_close_viewer()
			get_viewport().set_input_as_handled()

# ============================================================
# NOTE VIEWER — cyberpunk holographic overlay
# ============================================================

func _create_note_viewer() -> Control:
	var root := Control.new()
	root.name = "NoteViewer"
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark semi-transparent backdrop
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.anchors_preset = Control.PRESET_FULL_RECT
	backdrop.color = Color(0.0, 0.005, 0.02, 0.85)
	root.add_child(backdrop)

	# Main panel — centered, sized to 70% of screen
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.15
	panel.anchor_top = 0.05
	panel.anchor_right = 0.85
	panel.anchor_bottom = 0.95
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.02, 0.05, 0.95)
	style.border_color = Color(0.1, 0.2, 0.7, 0.6)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0.05, 0.1, 0.4, 0.3)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 8)
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	panel.add_child(vbox)

	# Header row: title + close button
	var header := HBoxContainer.new()
	header.name = "Header"

	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = " X "
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_close_viewer)
	header.add_child(close_btn)

	vbox.add_child(header)

	# Tags + connections row
	var meta_row := HBoxContainer.new()
	meta_row.name = "MetaRow"
	meta_row.add_theme_constant_override("separation", 16)

	var tags_label := Label.new()
	tags_label.name = "Tags"
	tags_label.add_theme_font_size_override("font_size", 13)
	tags_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.85))
	meta_row.add_child(tags_label)

	var conn_label := Label.new()
	conn_label.name = "Connections"
	conn_label.add_theme_font_size_override("font_size", 13)
	conn_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.8))
	meta_row.add_child(conn_label)

	var folder_label := Label.new()
	folder_label.name = "Folder"
	folder_label.add_theme_font_size_override("font_size", 13)
	folder_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	meta_row.add_child(folder_label)

	vbox.add_child(meta_row)

	# Separator line
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vbox.add_child(sep)

	# Body placeholder — gets replaced dynamically in _open_viewer
	var body_placeholder := Control.new()
	body_placeholder.name = "Body"
	body_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_placeholder)

	# Links section
	var links_sep := HSeparator.new()
	links_sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vbox.add_child(links_sep)

	var links_label := Label.new()
	links_label.name = "LinksHeader"
	links_label.text = "LINKED NOTES"
	links_label.add_theme_font_size_override("font_size", 12)
	links_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7))
	vbox.add_child(links_label)

	var links_flow := FlowContainer.new()
	links_flow.name = "Links"
	links_flow.add_theme_constant_override("h_separation", 6)
	links_flow.add_theme_constant_override("v_separation", 4)
	links_flow.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(links_flow)

	# Hint
	var hint := Label.new()
	hint.text = "Press ESC or Q to close"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	return root

func _open_viewer(note_id: String) -> void:
	var note = VaultDataBus.graph.get_note(note_id)
	if not note:
		return

	_viewer_open = true
	hover_panel.hide()
	_crosshair.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var panel: PanelContainer = note_viewer.get_node("Panel")
	var content: VBoxContainer = panel.get_node("Content")

	# Title
	content.get_node("Header/Title").text = note.title

	# Meta
	var tags_text: String = ", ".join(note.tags) if note.tags.size() > 0 else "no tags"
	content.get_node("MetaRow/Tags").text = "Tags: %s" % tags_text
	var conns: int = VaultDataBus.graph.get_connection_count(note_id)
	content.get_node("MetaRow/Connections").text = "%d connections" % conns
	content.get_node("MetaRow/Folder").text = note.folder if not note.folder.is_empty() else "root"

	# Body content — use a plain Label inside a ScrollContainer instead
	# Remove old Body if exists, replace with fresh one
	var old_body = content.get_node_or_null("Body")
	if old_body:
		old_body.queue_free()
		await get_tree().process_frame

	var scroll := ScrollContainer.new()
	scroll.name = "Body"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = note.content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88))
	scroll.add_child(label)

	# Insert before links section
	var links_idx: int = content.get_node("LinksHeader").get_index()
	content.add_child(scroll)
	content.move_child(scroll, links_idx - 1)

	print("Viewer: showing '%s' — %d chars" % [note.title, note.content.length()])

	# Links
	var links_flow: FlowContainer = content.get_node("Links")
	for child in links_flow.get_children():
		child.queue_free()

	var all_links: Array = note.outgoing_links
	var back_links: Array = VaultDataBus.graph.get_backlinks(note_id)

	for link_id in all_links:
		var linked_note = VaultDataBus.graph.get_note(link_id)
		var btn := Button.new()
		btn.text = linked_note.title if linked_note else link_id
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(0.3, 0.6, 0.95))
		btn.pressed.connect(func(): _open_viewer(link_id))
		links_flow.add_child(btn)

	for link_id in back_links:
		var linked_note = VaultDataBus.graph.get_note(link_id)
		var btn := Button.new()
		btn.text = "<< %s" % (linked_note.title if linked_note else link_id)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(0.6, 0.4, 0.3))
		btn.pressed.connect(func(): _open_viewer(link_id))
		links_flow.add_child(btn)

	note_viewer.show()

func _close_viewer() -> void:
	_viewer_open = false
	note_viewer.hide()
	_crosshair.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ============================================================
# HOVER PANEL (small tooltip)
# ============================================================

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

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_note_hovered(note_id: String) -> void:
	if _viewer_open:
		return
	var note = VaultDataBus.graph.get_note(note_id)
	if not note:
		hover_panel.hide()
		return

	var vbox = hover_panel.get_node("VBox")
	vbox.get_node("Title").text = note.title
	vbox.get_node("Tags").text = ", ".join(note.tags) if note.tags.size() > 0 else "no tags"
	var preview_text: String = note.content.substr(0, 200)
	if note.content.length() > 200:
		preview_text += "..."
	vbox.get_node("Preview").text = preview_text
	vbox.get_node("Connections").text = "%d connections" % VaultDataBus.graph.get_connection_count(note_id)

	var mouse_pos := get_viewport().get_mouse_position()
	hover_panel.position = mouse_pos + Vector2(20, 20)
	hover_panel.show()

func _on_note_unhovered() -> void:
	if _viewer_open:
		return
	hover_panel.hide()

func _on_note_clicked(note_id: String) -> void:
	_open_viewer(note_id)

func _on_search_requested() -> void:
	if _viewer_open:
		return
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
	if _viewer_open:
		return
	var tag_dialog := AcceptDialog.new()
	tag_dialog.title = "Filter by Tag"
	var option := OptionButton.new()
	option.add_item("-- Select Tag --")
	for tag in VaultDataBus.graph.get_all_tags():
		var count: int = VaultDataBus.graph.get_notes_by_tag(tag).size()
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
			var tag_notes: Array = VaultDataBus.graph.get_notes_by_tag(tag)
			var ids: Array = []
			for n in tag_notes:
				ids.append(n.id)
			if LayerManager.current_scene and LayerManager.current_scene.has_method("highlight_notes"):
				LayerManager.current_scene.highlight_notes(ids)
		tag_dialog.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
