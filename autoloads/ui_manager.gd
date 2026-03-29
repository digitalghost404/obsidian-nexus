extends CanvasLayer

var hover_panel: PanelContainer
var note_viewer: Control
var _crosshair: ColorRect
var _viewer_open: bool = false

func _ready() -> void:
	layer = 5

	# Screen-space effects — vignette, chromatic aberration, scan lines
	var screen_fx_shader = load("res://shaders/screen_effects.gdshader")
	if screen_fx_shader:
		var fx_rect := ColorRect.new()
		fx_rect.name = "ScreenFX"
		fx_rect.anchors_preset = Control.PRESET_FULL_RECT
		fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fx_mat := ShaderMaterial.new()
		fx_mat.shader = screen_fx_shader
		fx_rect.material = fx_mat
		add_child(fx_rect)
		# Move to back so it doesn't block other UI
		move_child(fx_rect, 0)

	_crosshair = ColorRect.new()
	_crosshair.size = Vector2(4, 4)
	_crosshair.color = Color(1, 1, 1, 0.5)
	_crosshair.anchors_preset = Control.PRESET_CENTER
	_crosshair.position = -Vector2(2, 2)
	add_child(_crosshair)

	hover_panel = _create_hover_panel()
	add_child(hover_panel)
	hover_panel.hide()

	note_viewer = _create_note_viewer()
	add_child(note_viewer)
	note_viewer.hide()

	# Minimap
	_create_minimap()

	InputManager.note_hovered.connect(_on_note_hovered)
	InputManager.note_unhovered.connect(_on_note_unhovered)
	InputManager.note_clicked.connect(_on_note_clicked)
	InputManager.search_requested.connect(_on_search_requested)
	InputManager.tag_filter_requested.connect(_on_tag_filter_requested)

func _process(_delta: float) -> void:
	# Update minimap player position
	var minimap = get_node_or_null("Minimap")
	if minimap and not _viewer_open:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var player_dot = minimap.get_node_or_null("PlayerDot")
			if player_dot:
				var city_size := 120.0
				var map_x: float = (cam.global_position.x / city_size) * 150.0
				var map_z: float = (cam.global_position.z / city_size) * 150.0
				player_dot.position = Vector2(clampf(map_x - 3, 0, 144), clampf(map_z - 3, 0, 144))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_Q:
			if _viewer_open:
				_close_viewer()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M or event.keycode == KEY_TAB:
			if not _viewer_open:
				_on_search_requested()
				get_viewport().set_input_as_handled()

func _create_minimap() -> void:
	var minimap := ColorRect.new()
	minimap.name = "Minimap"
	minimap.size = Vector2(150, 150)
	minimap.position = Vector2(15, get_viewport().get_visible_rect().size.y - 165)
	minimap.color = Color(0.01, 0.015, 0.04, 0.7)
	add_child(minimap)

	# Border
	var border := ColorRect.new()
	border.size = Vector2(152, 152)
	border.position = minimap.position - Vector2(1, 1)
	border.color = Color(0.06, 0.12, 0.4, 0.5)
	border.z_index = -1
	add_child(border)

	# Player dot (updates in _process)
	var player_dot := ColorRect.new()
	player_dot.name = "PlayerDot"
	player_dot.size = Vector2(6, 6)
	player_dot.color = Color(1, 1, 1, 0.9)
	minimap.add_child(player_dot)

	# Hub dot (static center)
	var hub_dot := ColorRect.new()
	hub_dot.size = Vector2(8, 8)
	hub_dot.color = Color(0.3, 0.5, 1.0, 0.8)
	hub_dot.position = Vector2(71, 71) # Center of 150x150 minimap
	minimap.add_child(hub_dot)

# ============================================================
# NOTE VIEWER — cyberpunk holographic overlay
# ============================================================

func _create_note_viewer() -> Control:
	var root := Control.new()
	root.name = "NoteViewer"
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.anchors_preset = Control.PRESET_FULL_RECT
	backdrop.color = Color(0.0, 0.005, 0.02, 0.85)
	root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "Panel"
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
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.name = "Header"
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = " X "
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_close_viewer)
	header.add_child(close_btn)
	vbox.add_child(header)

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

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var body_scroll := ScrollContainer.new()
	body_scroll.name = "BodyScroll"
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body_label := Label.new()
	body_label.name = "BodyLabel"
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("font_size", 14)
	body_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.88))
	body_scroll.add_child(body_label)
	vbox.add_child(body_scroll)

	var links_sep := HSeparator.new()
	vbox.add_child(links_sep)
	var links_header := Label.new()
	links_header.name = "LinksHeader"
	links_header.text = "LINKED NOTES"
	links_header.add_theme_font_size_override("font_size", 12)
	links_header.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7))
	vbox.add_child(links_header)
	var links_flow := FlowContainer.new()
	links_flow.name = "Links"
	links_flow.add_theme_constant_override("h_separation", 6)
	links_flow.add_theme_constant_override("v_separation", 4)
	links_flow.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(links_flow)

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
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	panel.position = Vector2(vp_size.x * 0.1, vp_size.y * 0.03)
	panel.size = Vector2(vp_size.x * 0.8, vp_size.y * 0.94)
	var content: VBoxContainer = panel.get_node("Content")

	content.get_node("Header/Title").text = note.title
	var tags_text: String = ", ".join(note.tags) if note.tags.size() > 0 else "no tags"
	content.get_node("MetaRow/Tags").text = "Tags: %s" % tags_text
	var conns: int = VaultDataBus.graph.get_connection_count(note_id)
	content.get_node("MetaRow/Connections").text = "%d connections" % conns
	content.get_node("MetaRow/Folder").text = note.folder if not note.folder.is_empty() else "root"

	var body_label: Label = content.get_node("BodyScroll/BodyLabel")
	body_label.text = note.content
	var body_scroll: ScrollContainer = content.get_node("BodyScroll")
	body_scroll.scroll_vertical = 0

	var links_flow: FlowContainer = content.get_node("Links")
	for child in links_flow.get_children():
		child.queue_free()

	for link_id in note.outgoing_links:
		var linked_note = VaultDataBus.graph.get_note(link_id)
		var btn := Button.new()
		btn.text = linked_note.title if linked_note else link_id
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): _open_viewer(link_id))
		links_flow.add_child(btn)

	for link_id in VaultDataBus.graph.get_backlinks(note_id):
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
# HOVER PANEL
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
	if note_id == "__nexus_hub__":
		_on_search_requested()
	else:
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
