# Obsidian Nexus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 3D cyberpunk data vault in Godot 4 that visualizes a 432-note Obsidian vault across three navigable layers (orbital graph, data cityscape, note corridors) with full visual effects pipeline.

**Architecture:** Layer Scenes + VaultDataBus autoload singleton. Each layer (Graph, City, Corridor) is an independent scene reading from a central data bus. LayerManager handles transitions. All rendering targets Vulkan Forward+ at 1440p/60fps on RTX 4070 Ti.

**Tech Stack:** Godot 4.x, GDScript, Godot Shader Language (GLSL-like), GPUParticles3D, MultiMeshInstance3D, SubViewport (for text rendering)

**Design Spec:** `docs/superpowers/specs/2026-03-28-obsidian-nexus-design.md`

---

## File Structure

```
obsidian-nexus/
├── project.godot                          # Godot project config (autoloads, input map, display settings)
├── icon.svg                               # Project icon
├── main.tscn / main.gd                    # Entry scene — initializes bus, loads default layer
│
├── autoloads/
│   ├── vault_data_bus.gd                  # Singleton: vault parser, cache, note graph, FS watcher
│   ├── vault_parser.gd                    # Markdown parser: frontmatter, wikilinks, tags extraction
│   ├── note_graph.gd                      # In-memory graph: nodes, edges, queries, force-directed layout
│   ├── layer_manager.gd                   # Scene transitions between layers with camera animation
│   ├── input_manager.gd                   # Input mapping, mode switching (grounded vs flight)
│   └── ui_manager.gd                      # CanvasLayer: search overlay, tag wheel, hover panels
│
├── layers/
│   ├── graph/
│   │   ├── graph_layer.tscn / graph_layer.gd          # Orbital graph scene root
│   │   ├── graph_node_mesh.gd                         # Single node visual (mesh, glow, label)
│   │   ├── graph_edge_renderer.gd                     # Edge rendering (ImmediateMesh lines)
│   │   └── graph_environment.tres                     # WorldEnvironment for graph layer
│   │
│   ├── city/
│   │   ├── city_layer.tscn / city_layer.gd            # City scene root
│   │   ├── district_generator.gd                      # Treemap layout for folder→district mapping
│   │   ├── tower_builder.gd                           # Note→tower mesh generation
│   │   ├── city_beam_renderer.gd                      # Link beams between towers
│   │   └── city_environment.tres                      # WorldEnvironment for city layer
│   │
│   └── corridor/
│       ├── corridor_layer.tscn / corridor_layer.gd    # Corridor scene root
│       ├── hallway_generator.gd                       # Procedural hallway from note data
│       ├── wall_panel.tscn / wall_panel.gd            # Text panel on corridor walls
│       ├── doorway.tscn / doorway.gd                  # Link doorway (outgoing) / sealed door (backlink)
│       └── corridor_environment.tres                  # WorldEnvironment for corridor layer
│
├── shaders/
│   ├── holographic_text.gdshader          # Scan-line overlay, jitter, alpha flicker for wall text
│   ├── code_rain.gdshader                 # Matrix-style falling characters
│   ├── energy_pulse.gdshader              # Traveling wave on link beams
│   ├── hex_grid.gdshader                  # Hexagonal pattern overlay for buildings
│   ├── layer_shift.gdshader               # Chromatic aberration during transitions
│   └── node_glow.gdshader                 # Temperature-based emission for graph nodes
│
├── materials/
│   ├── node_base.tres                     # Base material for graph nodes
│   ├── tower_base.tres                    # Base material for city towers
│   ├── corridor_wall.tres                 # Base material for corridor walls
│   ├── corridor_floor.tres                # Reflective floor material
│   └── beam_base.tres                     # Base material for link beams
│
├── particles/
│   ├── ambient_motes.tscn                 # Floating data particles (all layers)
│   ├── link_sparks.tscn                   # Sparks along link beams
│   ├── ember_rise.tscn                    # Rising embers from hot nodes
│   ├── corridor_dust.tscn                 # Low-lying dust in corridors
│   └── note_cascade.tscn                  # Burst effect when opening a note
│
├── ui/
│   ├── hover_panel.tscn / hover_panel.gd  # Floating holographic note preview
│   ├── search_overlay.tscn / search_overlay.gd  # Fullscreen search with beacon system
│   ├── tag_wheel.tscn / tag_wheel.gd     # Radial tag filter menu
│   ├── focus_panel.tscn / focus_panel.gd  # Expanded note content panel
│   └── hud.tscn / hud.gd                 # Minimal HUD (crosshair, current layer indicator)
│
├── camera/
│   ├── player_camera.tscn / player_camera.gd      # First-person camera (grounded mode)
│   ├── flight_camera.tscn / flight_camera.gd      # 6DOF free-flight camera (graph mode)
│   └── transition_camera.gd                        # Animated camera for layer transitions
│
└── tests/
    ├── test_vault_parser.gd               # GdUnit4 tests for markdown parsing
    ├── test_note_graph.gd                 # GdUnit4 tests for graph operations
    ├── test_force_layout.gd               # GdUnit4 tests for force-directed positioning
    ├── test_district_generator.gd         # GdUnit4 tests for treemap layout
    └── test_hallway_generator.gd          # GdUnit4 tests for procedural corridor
```

---

## Phase 1: Foundation (Tasks 1-4)

### Task 1: Godot Project Setup

**Files:**
- Create: `project.godot`
- Create: `main.tscn`
- Create: `main.gd`
- Create: `icon.svg`

- [ ] **Step 1: Create Godot project file**

```ini
; project.godot
; Engine configuration file — DO NOT EDIT with Godot running

config_version=5

[application]

config/name="Obsidian Nexus"
config/description="3D interactive data vault for Obsidian"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.4", "Forward Plus")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=2560
window/size/viewport_height=1440
window/size/mode=2
window/vsync/vsync_mode=0

[rendering]

renderer/rendering_method="forward_plus"
anti_aliasing/quality/msaa_3d=2
environment/defaults/default_clear_color=Color(0.039, 0.055, 0.102, 1)
```

- [ ] **Step 2: Create main scene script**

```gdscript
# main.gd
extends Node3D

func _ready() -> void:
	print("Obsidian Nexus — initializing")
	# Autoloads will be registered in project.godot in later tasks
	# For now, just confirm the scene loads
```

- [ ] **Step 3: Create main.tscn**

Open Godot, create a new Node3D scene, attach `main.gd`, save as `main.tscn`. Alternatively create it manually:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main.gd" id="1"]

[node name="Main" type="Node3D"]
script = ExtResource("1")
```

Save as `main.tscn`.

- [ ] **Step 4: Create a placeholder icon.svg**

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <rect width="128" height="128" rx="16" fill="#0a0e1a"/>
  <circle cx="64" cy="64" r="32" fill="none" stroke="#3b82f6" stroke-width="3"/>
  <circle cx="64" cy="64" r="8" fill="#f97316"/>
  <line x1="64" y1="32" x2="40" y2="80" stroke="#818cf8" stroke-width="1.5" opacity="0.6"/>
  <line x1="64" y1="32" x2="88" y2="80" stroke="#818cf8" stroke-width="1.5" opacity="0.6"/>
  <line x1="40" y1="80" x2="88" y2="80" stroke="#818cf8" stroke-width="1.5" opacity="0.6"/>
</svg>
```

- [ ] **Step 5: Run the project to verify it starts**

Run: Open Godot → import project at `~/projects/obsidian-nexus/` → Run (F5)
Expected: Black window with "Obsidian Nexus — initializing" in output console.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/obsidian-nexus
git add project.godot main.tscn main.gd icon.svg .gitignore docs/
git commit -m "feat: initialize Godot 4 project with Vulkan Forward+ renderer"
```

---

### Task 2: Vault Parser

**Files:**
- Create: `autoloads/vault_parser.gd`
- Create: `tests/test_vault_parser.gd`

- [ ] **Step 1: Install GdUnit4 for testing**

In Godot → AssetLib → search "GdUnit4" → install.
Alternatively clone: `git clone https://github.com/MikeSchulze/gdUnit4.git addons/gdUnit4`

- [ ] **Step 2: Write failing test for frontmatter parsing**

```gdscript
# tests/test_vault_parser.gd
extends GdUnitTestSuite

const VaultParser = preload("res://autoloads/vault_parser.gd")

var parser: VaultParser

func before() -> void:
	parser = VaultParser.new()

func after() -> void:
	parser.free()

func test_parse_frontmatter() -> void:
	var content := """---
title: Test Note
tags: [devops, security]
---
# Body content here

Some text with a [[linked note]] inside.
"""
	var result := parser.parse_note(content, "test-folder/Test Note.md")

	assert_str(result.title).is_equal("Test Note")
	assert_array(result.tags).contains_exactly(["devops", "security"])
	assert_str(result.folder).is_equal("test-folder")

func test_parse_wikilinks() -> void:
	var content := """---
title: Links Test
---
Check out [[Note A]] and also [[folder/Note B]] for details.
And [[Note A]] again (should dedupe).
"""
	var result := parser.parse_note(content, "Links Test.md")

	assert_array(result.outgoing_links).contains_exactly(["Note A", "folder/Note B"])

func test_parse_inline_tags() -> void:
	var content := """Some text with #inline-tag and #another-tag here.
And a #third-tag on line 2.
"""
	var result := parser.parse_note(content, "Tag Test.md")

	assert_array(result.tags).contains_exactly(["inline-tag", "another-tag", "third-tag"])

func test_word_count() -> void:
	var content := """---
title: Word Count Test
---
One two three four five six seven eight nine ten.
"""
	var result := parser.parse_note(content, "Word Count Test.md")

	assert_int(result.word_count).is_equal(10)

func test_title_fallback_to_filename() -> void:
	var content := "Just body text, no frontmatter."
	var result := parser.parse_note(content, "some-folder/My Note.md")

	assert_str(result.title).is_equal("My Note")
	assert_str(result.folder).is_equal("some-folder")
```

- [ ] **Step 3: Run tests to verify they fail**

Run: Godot → GdUnit4 panel → Run All Tests
Expected: All 5 tests fail — `vault_parser.gd` doesn't exist yet.

- [ ] **Step 4: Implement vault_parser.gd**

```gdscript
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
	# Filter out empty strings and markdown syntax
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
			# Remove quotes if present
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
			# Handle [item1, item2] format
			if value.begins_with("[") and value.ends_with("]"):
				var inner := value.substr(1, value.length() - 2)
				for item in inner.split(","):
					var clean := item.strip_edges()
					if not clean.is_empty():
						result.append(clean)
			# Handle single value on same line
			elif not value.is_empty():
				result.append(value)
	return result
```

- [ ] **Step 5: Run tests to verify they pass**

Run: Godot → GdUnit4 panel → Run All Tests
Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add autoloads/vault_parser.gd tests/test_vault_parser.gd
git commit -m "feat: add vault parser with frontmatter, wikilink, and tag extraction"
```

---

### Task 3: Note Graph

**Files:**
- Create: `autoloads/note_graph.gd`
- Create: `tests/test_note_graph.gd`

- [ ] **Step 1: Write failing tests for graph operations**

```gdscript
# tests/test_note_graph.gd
extends GdUnitTestSuite

const NoteGraph = preload("res://autoloads/note_graph.gd")
const VaultParser = preload("res://autoloads/vault_parser.gd")

var graph: NoteGraph

func before() -> void:
	graph = NoteGraph.new()

func after() -> void:
	graph.free()

func test_add_notes_and_query() -> void:
	var note := _make_note("test/Note A", "Note A", ["tag1"], ["Note B"])
	graph.add_note(note)

	var result := graph.get_note("test/Note A")
	assert_str(result.title).is_equal("Note A")

func test_backlinks_computed() -> void:
	var note_a := _make_note("Note A", "Note A", [], ["Note B"])
	var note_b := _make_note("Note B", "Note B", [], [])
	graph.add_note(note_a)
	graph.add_note(note_b)
	graph.compute_backlinks()

	var backlinks := graph.get_backlinks("Note B")
	assert_array(backlinks).contains_exactly(["Note A"])

func test_connection_count() -> void:
	var note_a := _make_note("Note A", "Note A", [], ["Note B", "Note C"])
	var note_b := _make_note("Note B", "Note B", [], ["Note A"])
	var note_c := _make_note("Note C", "Note C", [], [])
	graph.add_note(note_a)
	graph.add_note(note_b)
	graph.add_note(note_c)
	graph.compute_backlinks()

	# Note A: 2 outgoing + 1 backlink = 3
	assert_int(graph.get_connection_count("Note A")).is_equal(3)
	# Note C: 0 outgoing + 1 backlink = 1
	assert_int(graph.get_connection_count("Note C")).is_equal(1)

func test_get_notes_by_tag() -> void:
	var note_a := _make_note("Note A", "Note A", ["devops", "security"], [])
	var note_b := _make_note("Note B", "Note B", ["devops"], [])
	var note_c := _make_note("Note C", "Note C", ["ai"], [])
	graph.add_note(note_a)
	graph.add_note(note_b)
	graph.add_note(note_c)

	var devops_notes := graph.get_notes_by_tag("devops")
	assert_array(devops_notes).has_size(2)

func test_get_all_tags() -> void:
	var note_a := _make_note("Note A", "Note A", ["devops", "security"], [])
	var note_b := _make_note("Note B", "Note B", ["devops", "ai"], [])
	graph.add_note(note_a)
	graph.add_note(note_b)

	var tags := graph.get_all_tags()
	assert_array(tags).contains_exactly(["ai", "devops", "security"])

func _make_note(id: String, title: String, tags: Array, links: Array) -> VaultParser.NoteData:
	var note := VaultParser.NoteData.new()
	note.id = id
	note.title = title
	note.tags.assign(tags)
	note.outgoing_links.assign(links)
	note.content = "Test content"
	note.folder = ""
	note.word_count = 2
	note.last_modified = 0
	return note
```

- [ ] **Step 2: Run tests to verify they fail**

Run: Godot → GdUnit4 → Run All
Expected: FAIL — `note_graph.gd` doesn't exist.

- [ ] **Step 3: Implement note_graph.gd**

```gdscript
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
	# Index tags
	for tag in note.tags:
		if not _tag_index.has(tag):
			_tag_index[tag] = []
		if note.id not in _tag_index[tag]:
			_tag_index[tag].append(note.id)
	note_added.emit(note.id)

func remove_note(note_id: String) -> void:
	if _notes.has(note_id):
		var note: VaultParser.NoteData = _notes[note_id]
		# Remove from tag index
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
	var outgoing := note.outgoing_links.size()
	var incoming := get_backlinks(note_id).size()
	return outgoing + incoming

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: Godot → GdUnit4 → Run All
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add autoloads/note_graph.gd tests/test_note_graph.gd
git commit -m "feat: add note graph with backlinks, tag index, and cache serialization"
```

---

### Task 4: VaultDataBus (Autoload Singleton)

**Files:**
- Create: `autoloads/vault_data_bus.gd`
- Modify: `project.godot` (register autoload)

- [ ] **Step 1: Implement vault_data_bus.gd**

```gdscript
# autoloads/vault_data_bus.gd
extends Node

const VaultParserClass = preload("res://autoloads/vault_parser.gd")
const NoteGraphClass = preload("res://autoloads/note_graph.gd")

var parser: VaultParserClass
var graph: NoteGraphClass
var vault_path: String
var cache_path: String

var _watcher_timer: Timer
var _file_mtimes: Dictionary = {}  # path → mtime for change detection

signal vault_loaded()
signal vault_error(message: String)

func _ready() -> void:
	parser = VaultParserClass.new()
	graph = NoteGraphClass.new()

func initialize(p_vault_path: String, p_cache_path: String = "") -> void:
	vault_path = p_vault_path
	if p_cache_path.is_empty():
		cache_path = vault_path.path_join(".obsidian-nexus-cache.json")
	else:
		cache_path = p_cache_path

	# Try loading from cache first
	if FileAccess.file_exists(cache_path):
		print("VaultDataBus: loading from cache")
		_load_from_cache()
		# Diff against vault for changes
		_diff_and_patch()
	else:
		print("VaultDataBus: full parse (no cache)")
		_full_parse()

	_save_cache()
	_start_watcher()
	vault_loaded.emit()
	print("VaultDataBus: loaded %d notes, %d links" % [graph.get_note_count(), graph.get_link_count()])

func _full_parse() -> void:
	graph.clear()
	var notes := parser.parse_vault_directory(vault_path)
	for note in notes:
		graph.add_note(note)
		var full_path := vault_path.path_join(note.id + ".md")
		_file_mtimes[full_path] = note.last_modified
	graph.compute_backlinks()

func _load_from_cache() -> void:
	var file := FileAccess.open(cache_path, FileAccess.READ)
	if not file:
		_full_parse()
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		_full_parse()
		return
	graph.from_cache_dict(json.data)

func _save_cache() -> void:
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if not file:
		push_warning("VaultDataBus: could not write cache to %s" % cache_path)
		return
	var json := JSON.stringify(graph.to_cache_dict(), "\t")
	file.store_string(json)
	file.close()

func _diff_and_patch() -> void:
	# Scan vault for files newer than cache
	var current_notes := parser.parse_vault_directory(vault_path)
	var current_ids: Dictionary = {}
	for note in current_notes:
		current_ids[note.id] = note
		var cached := graph.get_note(note.id)
		if not cached or cached.last_modified < note.last_modified:
			graph.update_note(note)

	# Remove notes that no longer exist on disk
	for note_id in graph.get_all_note_ids():
		if not current_ids.has(note_id):
			graph.remove_note(note_id)

	graph.compute_backlinks()

func _start_watcher() -> void:
	_watcher_timer = Timer.new()
	_watcher_timer.wait_time = 2.0
	_watcher_timer.timeout.connect(_check_for_changes)
	add_child(_watcher_timer)
	_watcher_timer.start()

	# Build initial mtime map
	for note in graph.get_all_notes():
		var full_path := vault_path.path_join(note.id + ".md")
		_file_mtimes[full_path] = note.last_modified

func _check_for_changes() -> void:
	# Simple polling-based watcher
	var dir := DirAccess.open(vault_path)
	if not dir:
		return
	_scan_for_changes(vault_path)

func _scan_for_changes(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_for_changes(full_path)
		elif file_name.ends_with(".md"):
			var mtime := FileAccess.get_modified_time(full_path)
			var old_mtime: int = _file_mtimes.get(full_path, 0)
			if mtime != old_mtime:
				_file_mtimes[full_path] = mtime
				_reload_single_note(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _reload_single_note(full_path: String) -> void:
	var relative := full_path.substr(vault_path.length() + 1)
	var content := FileAccess.get_file_as_string(full_path)
	if content.is_empty():
		return
	var note := parser.parse_note(content, relative)
	note.last_modified = FileAccess.get_modified_time(full_path)
	graph.update_note(note)
	_save_cache()
	print("VaultDataBus: hot-reloaded %s" % note.title)
```

- [ ] **Step 2: Register autoload in project.godot**

Add to `project.godot`:

```ini
[autoload]

VaultDataBus="*res://autoloads/vault_data_bus.gd"
```

- [ ] **Step 3: Update main.gd to initialize the bus**

```gdscript
# main.gd
extends Node3D

@export var vault_path: String = ""

func _ready() -> void:
	print("Obsidian Nexus — initializing")

	# Determine vault path
	if vault_path.is_empty():
		# Default: look for config or use a known path
		var config_path := "user://vault_config.txt"
		if FileAccess.file_exists(config_path):
			vault_path = FileAccess.get_file_as_string(config_path).strip_edges()
		else:
			# Fallback for development
			vault_path = OS.get_environment("OBSIDIAN_VAULT_PATH")
			if vault_path.is_empty():
				push_error("No vault path configured. Set OBSIDIAN_VAULT_PATH or export vault_path.")
				return

	VaultDataBus.initialize(vault_path)
	VaultDataBus.vault_loaded.connect(_on_vault_loaded)

func _on_vault_loaded() -> void:
	print("Vault loaded: %d notes" % VaultDataBus.graph.get_note_count())
	# LayerManager will be connected here in a later task
```

- [ ] **Step 4: Test manually with your Obsidian vault**

Run the project with environment variable:
```bash
OBSIDIAN_VAULT_PATH=/path/to/your/obsidian/vault godot --path ~/projects/obsidian-nexus
```

Expected output:
```
Obsidian Nexus — initializing
VaultDataBus: full parse (no cache)
VaultDataBus: loaded 432 notes, 1541 links
Vault loaded: 432 notes
```

- [ ] **Step 5: Commit**

```bash
git add autoloads/vault_data_bus.gd main.gd project.godot
git commit -m "feat: add VaultDataBus autoload with hybrid cache and filesystem watcher"
```

---

## Phase 2: Graph Layer (Tasks 5-7)

### Task 5: Force-Directed Layout Algorithm

**Files:**
- Add layout methods to: `autoloads/note_graph.gd`
- Create: `tests/test_force_layout.gd`

- [ ] **Step 1: Write failing tests for force layout**

```gdscript
# tests/test_force_layout.gd
extends GdUnitTestSuite

const NoteGraph = preload("res://autoloads/note_graph.gd")
const VaultParser = preload("res://autoloads/vault_parser.gd")

var graph: NoteGraph

func before() -> void:
	graph = NoteGraph.new()

func after() -> void:
	graph.free()

func test_layout_assigns_positions() -> void:
	var note_a := _make_note("A", "A", [], ["B"])
	var note_b := _make_note("B", "B", [], ["A"])
	graph.add_note(note_a)
	graph.add_note(note_b)
	graph.compute_backlinks()
	graph.compute_layout(100)

	var pos_a := graph.get_position("A")
	var pos_b := graph.get_position("B")
	assert_bool(pos_a != Vector3.ZERO or pos_b != Vector3.ZERO).is_true()

func test_linked_nodes_are_closer_than_unlinked() -> void:
	var note_a := _make_note("A", "A", [], ["B"])
	var note_b := _make_note("B", "B", [], [])
	var note_c := _make_note("C", "C", [], [])
	graph.add_note(note_a)
	graph.add_note(note_b)
	graph.add_note(note_c)
	graph.compute_backlinks()
	graph.compute_layout(200)

	var pos_a := graph.get_position("A")
	var pos_b := graph.get_position("B")
	var pos_c := graph.get_position("C")
	var dist_ab := pos_a.distance_to(pos_b)
	var dist_ac := pos_a.distance_to(pos_c)
	# A and B are linked, so they should be closer than A and C
	assert_bool(dist_ab < dist_ac).is_true()

func test_positions_cached_in_dict() -> void:
	var note_a := _make_note("A", "A", [], [])
	graph.add_note(note_a)
	graph.compute_layout(50)

	var cache := graph.to_cache_dict()
	assert_bool(cache["A"].has("position")).is_true()

func _make_note(id: String, title: String, tags: Array, links: Array) -> VaultParser.NoteData:
	var note := VaultParser.NoteData.new()
	note.id = id
	note.title = title
	note.tags.assign(tags)
	note.outgoing_links.assign(links)
	note.content = "Test"
	note.folder = ""
	note.word_count = 1
	note.last_modified = 0
	return note
```

- [ ] **Step 2: Run tests to verify they fail**

Run: GdUnit4 → Run All
Expected: FAIL — `compute_layout` and `get_position` don't exist.

- [ ] **Step 3: Add force-directed layout to note_graph.gd**

Add these members and methods to `note_graph.gd`:

```gdscript
# Add to class members:
var _positions: Dictionary = {}  # note_id → Vector3

# Add these methods:

func compute_layout(iterations: int = 500) -> void:
	# Initialize random positions on a sphere
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
	var velocities: Dictionary = {}  # note_id → Vector3
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
					var dist := delta.length()
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
```

Also update `to_cache_dict` to include positions:

```gdscript
# In to_cache_dict, add to each note's dict:
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
```

And update `from_cache_dict`:

```gdscript
# In from_cache_dict, after add_note(note):
		if d.has("position"):
			_positions[note_id] = str_to_var(d["position"])
```

- [ ] **Step 4: Run tests to verify they pass**

Run: GdUnit4 → Run All
Expected: All layout tests PASS.

- [ ] **Step 5: Commit**

```bash
git add autoloads/note_graph.gd tests/test_force_layout.gd
git commit -m "feat: add 3D force-directed layout algorithm with position caching"
```

---

### Task 6: Graph Layer Scene

**Files:**
- Create: `layers/graph/graph_layer.tscn`
- Create: `layers/graph/graph_layer.gd`
- Create: `layers/graph/graph_node_mesh.gd`
- Create: `layers/graph/graph_edge_renderer.gd`
- Create: `layers/graph/graph_environment.tres`
- Create: `shaders/node_glow.gdshader`
- Create: `materials/node_base.tres`
- Create: `particles/ambient_motes.tscn`

- [ ] **Step 1: Create the node glow shader**

```glsl
// shaders/node_glow.gdshader
shader_type spatial;
render_mode unshaded;

uniform vec4 cold_color : source_color = vec4(0.14, 0.33, 0.93, 1.0);    // Blue
uniform vec4 warm_color : source_color = vec4(0.98, 0.58, 0.09, 1.0);     // Orange
uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);        // White-hot
uniform float temperature : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float emission_strength : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	// Blend between cold → warm → hot based on temperature
	vec4 base_color;
	if (temperature < 0.5) {
		base_color = mix(cold_color, warm_color, temperature * 2.0);
	} else {
		base_color = mix(warm_color, hot_color, (temperature - 0.5) * 2.0);
	}

	// Pulsing emission
	float pulse = sin(TIME * pulse_speed) * pulse_intensity + 1.0;

	ALBEDO = base_color.rgb;
	EMISSION = base_color.rgb * emission_strength * pulse;
	ALPHA = base_color.a;
}
```

- [ ] **Step 2: Create graph_node_mesh.gd**

```gdscript
# layers/graph/graph_node_mesh.gd
extends Node3D

var note_id: String
var note_title: String
var connection_count: int = 0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D

func setup(p_note_id: String, p_title: String, p_connections: int, p_position: Vector3) -> void:
	note_id = p_note_id
	note_title = p_title
	connection_count = p_connections
	position = p_position

	# Scale based on connections (min 0.3, max 2.0)
	var scale_factor := clampf(0.3 + (connection_count * 0.08), 0.3, 2.0)
	mesh_instance.scale = Vector3.ONE * scale_factor

	# Temperature: 0.0 (cold/isolated) → 1.0 (hot/hub)
	var temperature := clampf(connection_count / 25.0, 0.0, 1.0)
	var mat: ShaderMaterial = mesh_instance.get_surface_override_material(0)
	if mat:
		mat = mat.duplicate()
		mat.set_shader_parameter("temperature", temperature)
		mat.set_shader_parameter("emission_strength", 1.5 + temperature * 4.0)
		mesh_instance.set_surface_override_material(0, mat)

	# Label
	label.text = p_title
	label.position = Vector3(0, scale_factor + 0.5, 0)
	label.font_size = 32
	label.modulate = Color(0.8, 0.85, 0.95, 0.8)

func _process(_delta: float) -> void:
	# Billboard the label toward camera
	if label and get_viewport().get_camera_3d():
		label.look_at(get_viewport().get_camera_3d().global_position)
```

- [ ] **Step 3: Create graph_edge_renderer.gd**

```gdscript
# layers/graph/graph_edge_renderer.gd
extends Node3D

## Renders all edges as a single ImmediateMesh for performance
var _mesh_instance: MeshInstance3D
var _mesh: ImmediateMesh

func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	# Use unshaded material for edges
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.32, 0.4, 0.93, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	_mesh_instance.set_surface_override_material(0, mat)
	add_child(_mesh_instance)

func build_edges(graph: NoteGraph) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for note_id in graph.get_all_note_ids():
		var note = graph.get_note(note_id)
		if not note:
			continue
		var from_pos := graph.get_position(note_id)
		for link in note.outgoing_links:
			var to_pos := graph.get_position(link)
			if to_pos == Vector3.ZERO and not graph.get_note(link):
				continue  # Skip broken links
			# Color based on average temperature of endpoints
			var from_conns := graph.get_connection_count(note_id)
			var to_conns := graph.get_connection_count(link)
			var avg_temp := clampf((from_conns + to_conns) / 50.0, 0.0, 1.0)
			var edge_color := Color(0.32, 0.4, 0.93, 0.2).lerp(Color(0.98, 0.58, 0.09, 0.4), avg_temp)

			_mesh.surface_set_color(edge_color)
			_mesh.surface_add_vertex(from_pos)
			_mesh.surface_set_color(edge_color)
			_mesh.surface_add_vertex(to_pos)

	_mesh.surface_end()
```

- [ ] **Step 4: Create graph_layer.gd**

```gdscript
# layers/graph/graph_layer.gd
extends Node3D

const GraphNodeMeshScene = preload("res://layers/graph/graph_node_mesh.tscn")

var edge_renderer: Node3D
var nodes_container: Node3D
var _node_map: Dictionary = {}  # note_id → GraphNodeMesh instance

func _ready() -> void:
	nodes_container = Node3D.new()
	nodes_container.name = "Nodes"
	add_child(nodes_container)

	var EdgeRenderer = load("res://layers/graph/graph_edge_renderer.gd")
	edge_renderer = Node3D.new()
	edge_renderer.set_script(EdgeRenderer)
	edge_renderer.name = "Edges"
	add_child(edge_renderer)

	build_from_graph(VaultDataBus.graph)
	VaultDataBus.graph.note_updated.connect(_on_note_updated)

func build_from_graph(graph: NoteGraph) -> void:
	# Clear existing
	for child in nodes_container.get_children():
		child.queue_free()
	_node_map.clear()

	# Ensure layout is computed
	if graph.get_position(graph.get_all_note_ids()[0]) == Vector3.ZERO:
		graph.compute_layout(500)

	# Create node meshes
	for note in graph.get_all_notes():
		var node_instance = GraphNodeMeshScene.instantiate()
		node_instance.setup(
			note.id,
			note.title,
			graph.get_connection_count(note.id),
			graph.get_position(note.id)
		)
		nodes_container.add_child(node_instance)
		_node_map[note.id] = node_instance

	# Build edges
	edge_renderer.build_edges(graph)

func _on_note_updated(note_id: String) -> void:
	# Rebuild just the affected node
	if _node_map.has(note_id):
		_node_map[note_id].queue_free()
	var note = VaultDataBus.graph.get_note(note_id)
	if note:
		var node_instance = GraphNodeMeshScene.instantiate()
		node_instance.setup(
			note.id,
			note.title,
			VaultDataBus.graph.get_connection_count(note.id),
			VaultDataBus.graph.get_position(note.id)
		)
		nodes_container.add_child(node_instance)
		_node_map[note_id] = node_instance
	# Rebuild all edges (cheap enough)
	edge_renderer.build_edges(VaultDataBus.graph)

func get_node_at_position(world_pos: Vector3, radius: float = 2.0) -> String:
	var closest_id := ""
	var closest_dist := radius
	for note_id in _node_map:
		var node_pos: Vector3 = _node_map[note_id].global_position
		var dist := node_pos.distance_to(world_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_id = note_id
	return closest_id
```

- [ ] **Step 5: Create the graph_node_mesh.tscn scene**

In Godot editor:
1. Create new scene with Node3D root
2. Attach `graph_node_mesh.gd`
3. Add child MeshInstance3D with SphereMesh (radius 0.5)
4. Create ShaderMaterial using `shaders/node_glow.gdshader`, assign to mesh
5. Add child Label3D, position at (0, 1, 0)
6. Save as `layers/graph/graph_node_mesh.tscn`

- [ ] **Step 6: Create graph environment resource**

In Godot editor, create a WorldEnvironment with:
- Background: Custom Color = `#0a0e1a`
- Ambient Light: Color = `#1a2040`, Energy = 0.3
- Glow: Enabled, Intensity = 0.8, Bloom = 0.3
- Volumetric Fog: Enabled, Density = 0.005, Albedo = `#0d1a3d`
- SSAO: Enabled, Radius = 2.0

Save as `layers/graph/graph_environment.tres`

- [ ] **Step 7: Create graph_layer.tscn**

In Godot editor:
1. Create scene: Node3D root → attach `graph_layer.gd`
2. Add WorldEnvironment child → assign `graph_environment.tres`
3. Add DirectionalLight3D → low intensity blue fill light
4. Save as `layers/graph/graph_layer.tscn`

- [ ] **Step 8: Test by loading graph layer from main**

Temporarily update `main.gd` `_on_vault_loaded`:

```gdscript
func _on_vault_loaded() -> void:
	print("Vault loaded: %d notes" % VaultDataBus.graph.get_note_count())
	var graph_scene = load("res://layers/graph/graph_layer.tscn")
	var graph_layer = graph_scene.instantiate()
	add_child(graph_layer)

	# Add a temporary camera to see the graph
	var camera := Camera3D.new()
	camera.position = Vector3(0, 50, 100)
	camera.look_at(Vector3.ZERO)
	add_child(camera)
```

Run with vault path. Expected: 432 glowing spheres in 3D space with blue edges between them. Hub nodes (facility-7, the foundation) should be larger and more orange.

- [ ] **Step 9: Commit**

```bash
git add layers/graph/ shaders/node_glow.gdshader materials/ particles/
git commit -m "feat: add graph layer with force-directed layout, node glow shader, and edge rendering"
```

---

### Task 7: Flight Camera for Graph Layer

**Files:**
- Create: `camera/flight_camera.tscn`
- Create: `camera/flight_camera.gd`

- [ ] **Step 1: Implement flight_camera.gd**

```gdscript
# camera/flight_camera.gd
extends Camera3D

@export var base_speed: float = 20.0
@export var fast_speed: float = 60.0
@export var mouse_sensitivity: float = 0.002
@export var scroll_speed_step: float = 5.0

var _velocity: Vector3 = Vector3.ZERO
var _speed_multiplier: float = 1.0
var _mouse_captured: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and _mouse_captured:
		rotate_y(-event.relative.x * mouse_sensitivity)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		# Clamp vertical rotation
		rotation.x = clampf(rotation.x, -PI / 2.0, PI / 2.0)

	# Toggle mouse capture
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _mouse_captured:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured = false
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_mouse_captured = true

	# Scroll to adjust speed
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_speed_multiplier = clampf(_speed_multiplier + 0.2, 0.2, 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_speed_multiplier = clampf(_speed_multiplier - 0.2, 0.2, 5.0)

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO

	# WASD movement
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	# QE for vertical
	if Input.is_key_pressed(KEY_Q):
		input_dir -= transform.basis.y
	if Input.is_key_pressed(KEY_E):
		input_dir += transform.basis.y

	input_dir = input_dir.normalized()

	var speed := fast_speed if Input.is_key_pressed(KEY_SHIFT) else base_speed
	speed *= _speed_multiplier

	_velocity = _velocity.lerp(input_dir * speed, 10.0 * delta)
	position += _velocity * delta
```

- [ ] **Step 2: Create flight_camera.tscn**

In Godot: New scene → Camera3D root → attach `flight_camera.gd` → save as `camera/flight_camera.tscn`.

- [ ] **Step 3: Update main.gd to use flight camera**

```gdscript
func _on_vault_loaded() -> void:
	print("Vault loaded: %d notes" % VaultDataBus.graph.get_note_count())
	var graph_scene = load("res://layers/graph/graph_layer.tscn")
	var graph_layer = graph_scene.instantiate()
	add_child(graph_layer)

	var camera_scene = load("res://camera/flight_camera.tscn")
	var camera = camera_scene.instantiate()
	camera.position = Vector3(0, 30, 80)
	camera.look_at(Vector3.ZERO)
	add_child(camera)
```

- [ ] **Step 4: Test — fly through the graph**

Run project. Expected: WASD + mouse look to fly through the 3D graph. Shift to boost. QE for vertical. Scroll to adjust speed. Esc toggles mouse capture.

- [ ] **Step 5: Commit**

```bash
git add camera/
git commit -m "feat: add 6DOF flight camera with speed control for graph navigation"
```

---

## Phase 3: City Layer (Tasks 8-10)

### Task 8: District Generator (Treemap Layout)

**Files:**
- Create: `layers/city/district_generator.gd`
- Create: `tests/test_district_generator.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/test_district_generator.gd
extends GdUnitTestSuite

const DistrictGenerator = preload("res://layers/city/district_generator.gd")

var generator: DistrictGenerator

func before() -> void:
	generator = DistrictGenerator.new()

func after() -> void:
	generator.free()

func test_generates_districts_for_folders() -> void:
	var folders := {"devops": 30, "ai-engineering": 25, "security": 14}
	var districts := generator.generate(folders, Vector2(200, 200))

	assert_int(districts.size()).is_equal(3)
	for d in districts:
		assert_bool(d.has("folder")).is_true()
		assert_bool(d.has("rect")).is_true()

func test_districts_fill_total_area() -> void:
	var folders := {"a": 10, "b": 20, "c": 30}
	var districts := generator.generate(folders, Vector2(100, 100))

	var total_area := 0.0
	for d in districts:
		var rect: Rect2 = d["rect"]
		total_area += rect.size.x * rect.size.y
	# Should be close to 100x100 = 10000
	assert_float(total_area).is_equal_approx(10000.0, 100.0)

func test_districts_do_not_overlap() -> void:
	var folders := {"a": 10, "b": 20, "c": 15, "d": 5}
	var districts := generator.generate(folders, Vector2(100, 100))

	for i in range(districts.size()):
		for j in range(i + 1, districts.size()):
			var r1: Rect2 = districts[i]["rect"]
			var r2: Rect2 = districts[j]["rect"]
			assert_bool(r1.intersects(r2)).is_false()
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement district_generator.gd**

```gdscript
# layers/city/district_generator.gd
extends RefCounted
class_name DistrictGenerator

## Squarified treemap algorithm
## Input: folder_name → note_count, total_size (Vector2)
## Output: Array of { "folder": String, "rect": Rect2 }

func generate(folder_sizes: Dictionary, total_size: Vector2) -> Array:
	if folder_sizes.is_empty():
		return []

	# Sort folders by size descending
	var items: Array = []
	for folder in folder_sizes:
		items.append({"folder": folder, "size": folder_sizes[folder]})
	items.sort_custom(func(a, b): return a["size"] > b["size"])

	# Compute total
	var total := 0.0
	for item in items:
		total += item["size"]

	# Normalize sizes to areas
	var total_area := total_size.x * total_size.y
	for item in items:
		item["area"] = (item["size"] / total) * total_area

	# Run squarified treemap
	var results: Array = []
	_squarify(items, Rect2(Vector2.ZERO, total_size), results)
	return results

func _squarify(items: Array, bounds: Rect2, results: Array) -> void:
	if items.is_empty():
		return

	if items.size() == 1:
		results.append({"folder": items[0]["folder"], "rect": bounds})
		return

	# Determine split direction (split along longer edge)
	var vertical := bounds.size.x >= bounds.size.y

	# Find best split point
	var total_area := 0.0
	for item in items:
		total_area += item["area"]

	var accumulated := 0.0
	var split_idx := 0
	var best_ratio := INF

	for i in range(items.size() - 1):
		accumulated += items[i]["area"]
		var fraction := accumulated / total_area

		# Compute worst aspect ratio for this split
		var ratio: float
		if vertical:
			var w1 := bounds.size.x * fraction
			var w2 := bounds.size.x * (1.0 - fraction)
			ratio = maxf(w1 / bounds.size.y, bounds.size.y / w1) if bounds.size.y > 0 else INF
		else:
			var h1 := bounds.size.y * fraction
			var h2 := bounds.size.y * (1.0 - fraction)
			ratio = maxf(h1 / bounds.size.x, bounds.size.x / h1) if bounds.size.x > 0 else INF

		if ratio < best_ratio:
			best_ratio = ratio
			split_idx = i

	# Split
	var left_items := items.slice(0, split_idx + 1)
	var right_items := items.slice(split_idx + 1)

	var left_area := 0.0
	for item in left_items:
		left_area += item["area"]
	var fraction := left_area / total_area

	var left_bounds: Rect2
	var right_bounds: Rect2

	if vertical:
		var split_x := bounds.size.x * fraction
		left_bounds = Rect2(bounds.position, Vector2(split_x, bounds.size.y))
		right_bounds = Rect2(bounds.position + Vector2(split_x, 0), Vector2(bounds.size.x - split_x, bounds.size.y))
	else:
		var split_y := bounds.size.y * fraction
		left_bounds = Rect2(bounds.position, Vector2(bounds.size.x, split_y))
		right_bounds = Rect2(bounds.position + Vector2(0, split_y), Vector2(bounds.size.x, bounds.size.y - split_y))

	_squarify(left_items, left_bounds, results)
	_squarify(right_items, right_bounds, results)
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add layers/city/district_generator.gd tests/test_district_generator.gd
git commit -m "feat: add squarified treemap district generator for city layout"
```

---

### Task 9: Tower Builder & City Layer Scene

**Files:**
- Create: `layers/city/tower_builder.gd`
- Create: `layers/city/city_layer.gd`
- Create: `layers/city/city_layer.tscn`
- Create: `layers/city/city_beam_renderer.gd`
- Create: `layers/city/city_environment.tres`
- Create: `shaders/hex_grid.gdshader`
- Create: `materials/tower_base.tres`

- [ ] **Step 1: Create hex grid shader**

```glsl
// shaders/hex_grid.gdshader
shader_type spatial;
render_mode blend_add, unshaded;

uniform vec4 line_color : source_color = vec4(0.3, 0.35, 0.93, 0.15);
uniform float scale : hint_range(0.1, 10.0) = 2.0;
uniform float line_width : hint_range(0.01, 0.1) = 0.03;
uniform float scroll_speed : hint_range(0.0, 1.0) = 0.05;

// Hex distance function
float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.73))), p.x);
}

vec4 hex_coords(vec2 uv) {
	vec2 r = vec2(1.0, 1.73);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	vec2 gv = length(a) < length(b) ? a : b;
	float dist = hex_dist(gv);
	return vec4(gv, dist, 0.0);
}

void fragment() {
	vec2 uv = UV * scale;
	uv.y += TIME * scroll_speed;
	vec4 hc = hex_coords(uv);
	float edge = smoothstep(0.5 - line_width, 0.5, hc.z);
	float alpha = (1.0 - edge) * line_color.a;
	ALBEDO = line_color.rgb;
	ALPHA = alpha;
}
```

- [ ] **Step 2: Create tower_builder.gd**

```gdscript
# layers/city/tower_builder.gd
extends RefCounted
class_name TowerBuilder

const VaultParser = preload("res://autoloads/vault_parser.gd")

## Builds a tower mesh for a note
## Height = word_count mapped to range [1.0, 30.0]
## Emission = connection_count mapped to temperature color

static func build_tower(note: VaultParser.NoteData, connection_count: int, position_2d: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Tower_%s" % note.id.replace("/", "_")

	# Height from word count (min 1, max 30)
	var height := clampf(note.word_count / 200.0, 1.0, 30.0)

	# Base tower mesh
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, height, 2.0)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(position_2d.x, height / 2.0, position_2d.y)

	# Material with temperature-based emission
	var mat := StandardMaterial3D.new()
	var temperature := clampf(connection_count / 25.0, 0.0, 1.0)
	var base_color := Color(0.05, 0.08, 0.15)
	mat.albedo_color = base_color
	mat.emission_enabled = true
	var emit_color := Color(0.14, 0.33, 0.93).lerp(Color(0.98, 0.58, 0.09), temperature)
	mat.emission = emit_color
	mat.emission_energy_multiplier = 0.5 + temperature * 3.0
	mesh_instance.set_surface_override_material(0, mat)

	root.add_child(mesh_instance)

	# Hex grid overlay (second mesh slightly larger)
	var hex_shader = load("res://shaders/hex_grid.gdshader")
	if hex_shader:
		var overlay := MeshInstance3D.new()
		var overlay_box := BoxMesh.new()
		overlay_box.size = Vector3(2.05, height + 0.05, 2.05)
		overlay.mesh = overlay_box
		overlay.position = mesh_instance.position
		var hex_mat := ShaderMaterial.new()
		hex_mat.shader = hex_shader
		hex_mat.set_shader_parameter("line_color", Color(emit_color.r, emit_color.g, emit_color.b, 0.12))
		overlay.set_surface_override_material(0, hex_mat)
		root.add_child(overlay)

	# Title label floating above
	var label := Label3D.new()
	label.text = note.title
	label.position = Vector3(position_2d.x, height + 1.0, position_2d.y)
	label.font_size = 24
	label.modulate = Color(0.8, 0.85, 0.95, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)

	# Store metadata for interaction
	root.set_meta("note_id", note.id)
	root.set_meta("connection_count", connection_count)

	return root
```

- [ ] **Step 3: Create city_beam_renderer.gd**

```gdscript
# layers/city/city_beam_renderer.gd
extends Node3D

var _mesh_instance: MeshInstance3D
var _mesh: ImmediateMesh

func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.5, 0.4, 0.93, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.set_surface_override_material(0, mat)
	add_child(_mesh_instance)

func build_beams(tower_positions: Dictionary, graph: NoteGraph) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for note_id in tower_positions:
		var note = graph.get_note(note_id)
		if not note:
			continue
		var from_pos: Vector3 = tower_positions[note_id]
		for link in note.outgoing_links:
			if tower_positions.has(link):
				var to_pos: Vector3 = tower_positions[link]
				# Arc the beam upward
				var mid_y := maxf(from_pos.y, to_pos.y) + 5.0
				# Simple 3-segment arc
				var mid_pos := (from_pos + to_pos) / 2.0
				mid_pos.y = mid_y

				var temp := clampf((graph.get_connection_count(note_id) + graph.get_connection_count(link)) / 50.0, 0.0, 1.0)
				var beam_color := Color(0.32, 0.4, 0.93, 0.15).lerp(Color(0.98, 0.58, 0.09, 0.3), temp)

				_mesh.surface_set_color(beam_color)
				_mesh.surface_add_vertex(from_pos)
				_mesh.surface_set_color(beam_color)
				_mesh.surface_add_vertex(mid_pos)

				_mesh.surface_set_color(beam_color)
				_mesh.surface_add_vertex(mid_pos)
				_mesh.surface_set_color(beam_color)
				_mesh.surface_add_vertex(to_pos)

	_mesh.surface_end()
```

- [ ] **Step 4: Create city_layer.gd**

```gdscript
# layers/city/city_layer.gd
extends Node3D

var _tower_positions: Dictionary = {}  # note_id → Vector3 (tower top center)
var _tower_map: Dictionary = {}        # note_id → Node3D

func _ready() -> void:
	_build_city()

func _build_city() -> void:
	var graph: NoteGraph = VaultDataBus.graph

	# Get folder sizes
	var folder_sizes: Dictionary = {}
	for folder in graph.get_all_folders():
		folder_sizes[folder] = graph.get_notes_by_folder(folder).size()
	# Root-level notes
	var root_notes := graph.get_notes_by_folder("")
	if root_notes.size() > 0:
		folder_sizes["_root"] = root_notes.size()

	# Generate district layout
	var district_gen := DistrictGenerator.new()
	var city_size := Vector2(300.0, 300.0)  # World units
	var districts := district_gen.generate(folder_sizes, city_size)

	# Build ground plane
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = city_size
	ground.mesh = ground_mesh
	ground.position = Vector3(city_size.x / 2.0, 0, city_size.y / 2.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.02, 0.03, 0.06)
	ground_mat.metallic = 0.8
	ground_mat.roughness = 0.2  # Reflective
	ground.set_surface_override_material(0, ground_mat)
	add_child(ground)

	# Build districts
	for district in districts:
		var folder: String = district["folder"]
		var rect: Rect2 = district["rect"]
		var actual_folder := "" if folder == "_root" else folder
		var notes := graph.get_notes_by_folder(actual_folder)

		# District boundary marker (neon sign)
		var sign_label := Label3D.new()
		sign_label.text = folder.get_file() if "/" in folder else folder
		sign_label.position = Vector3(rect.position.x + rect.size.x / 2.0, 0.5, rect.position.y)
		sign_label.font_size = 48
		sign_label.modulate = Color(0.5, 0.3, 0.93, 0.8)
		sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(sign_label)

		# Place towers in grid within district
		var cols := ceili(sqrt(notes.size()))
		var spacing_x := rect.size.x / maxf(cols, 1)
		var spacing_z := rect.size.y / maxf(ceili(float(notes.size()) / cols), 1)

		for i in range(notes.size()):
			var note = notes[i]
			var col := i % cols
			var row := i / cols
			var pos_2d := Vector2(
				rect.position.x + col * spacing_x + spacing_x / 2.0,
				rect.position.y + row * spacing_z + spacing_z / 2.0
			)
			var connections := graph.get_connection_count(note.id)
			var tower := TowerBuilder.build_tower(note, connections, pos_2d)
			add_child(tower)
			_tower_map[note.id] = tower

			# Store position for beam rendering (top of tower)
			var height := clampf(note.word_count / 200.0, 1.0, 30.0)
			_tower_positions[note.id] = Vector3(pos_2d.x, height, pos_2d.y)

	# Build link beams
	var beam_renderer_script = load("res://layers/city/city_beam_renderer.gd")
	var beam_renderer := Node3D.new()
	beam_renderer.set_script(beam_renderer_script)
	beam_renderer.name = "Beams"
	add_child(beam_renderer)
	# Need to wait one frame for _ready
	await get_tree().process_frame
	beam_renderer.build_beams(_tower_positions, graph)
```

- [ ] **Step 5: Create city_layer.tscn**

In Godot editor:
1. Node3D root → attach `city_layer.gd`
2. Add WorldEnvironment child with:
   - Background: Custom Color `#080c18`
   - Volumetric Fog: Enabled, Density = 0.03, Albedo = `#1a1030`
   - Glow: Enabled, Intensity = 1.2, Bloom = 0.5
   - SDFGI: Enabled
   - SSR: Enabled, Max Steps = 64
   - SSAO: Enabled
3. Add DirectionalLight3D (dim purple fill, energy 0.2)
4. Save as `layers/city/city_layer.tscn`

- [ ] **Step 6: Test city layer**

Temporarily update `main.gd` to load city instead of graph:

```gdscript
func _on_vault_loaded() -> void:
	var city_scene = load("res://layers/city/city_layer.tscn")
	var city = city_scene.instantiate()
	add_child(city)
	# Temporary camera
	var cam = load("res://camera/flight_camera.tscn").instantiate()
	cam.position = Vector3(150, 30, 150)
	cam.look_at(Vector3(150, 0, 150))
	add_child(cam)
```

Expected: Cyberpunk cityscape with 58 districts, towers of varying heights, hex grid overlays, link beams arcing between towers. Reflective ground. Volumetric fog.

- [ ] **Step 7: Commit**

```bash
git add layers/city/ shaders/hex_grid.gdshader
git commit -m "feat: add city layer with treemap districts, tower builder, and link beams"
```

---

### Task 10: Player Camera (Grounded First-Person)

**Files:**
- Create: `camera/player_camera.tscn`
- Create: `camera/player_camera.gd`

- [ ] **Step 1: Implement player_camera.gd**

```gdscript
# camera/player_camera.gd
extends CharacterBody3D

@export var walk_speed: float = 8.0
@export var sprint_speed: float = 16.0
@export var mouse_sensitivity: float = 0.002
@export var camera_height: float = 1.7

var _mouse_captured: bool = false

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true
	camera.position.y = camera_height

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_mouse_captured = not _mouse_captured
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	input_dir = input_dir.normalized()
	input_dir = transform.basis * input_dir

	var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed

	# Simple gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0

	move_and_slide()
```

- [ ] **Step 2: Create player_camera.tscn**

In Godot:
1. CharacterBody3D root → attach `player_camera.gd`
2. Add Camera3D child at position (0, 1.7, 0)
3. Add CollisionShape3D child with CapsuleShape3D (radius 0.4, height 1.8)
4. Save as `camera/player_camera.tscn`

- [ ] **Step 3: Test in city layer**

Update `main.gd` to use player camera at street level:

```gdscript
func _on_vault_loaded() -> void:
	var city_scene = load("res://layers/city/city_layer.tscn")
	add_child(city_scene.instantiate())
	var cam = load("res://camera/player_camera.tscn").instantiate()
	cam.position = Vector3(150, 2, 150)
	add_child(cam)
```

Expected: Walk through the city at street level. Towers rise around you. Shift to sprint.

- [ ] **Step 4: Commit**

```bash
git add camera/player_camera.tscn camera/player_camera.gd
git commit -m "feat: add grounded first-person camera with sprint and mouse look"
```

---

## Phase 4: Corridor Layer (Tasks 11-13)

### Task 11: Procedural Hallway Generator

**Files:**
- Create: `layers/corridor/hallway_generator.gd`
- Create: `tests/test_hallway_generator.gd`

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/test_hallway_generator.gd
extends GdUnitTestSuite

const HallwayGenerator = preload("res://layers/corridor/hallway_generator.gd")
const VaultParser = preload("res://autoloads/vault_parser.gd")

var generator: HallwayGenerator

func before() -> void:
	generator = HallwayGenerator.new()

func after() -> void:
	generator.free()

func test_generates_hallway_segments() -> void:
	var note := _make_note("Test", "Some content here for testing the hallway generation.", ["link1", "link2"], ["back1"])
	var layout := generator.compute_layout(note)

	assert_bool(layout.has("segments")).is_true()
	assert_bool(layout["segments"].size() > 0).is_true()

func test_doorways_match_outgoing_links() -> void:
	var note := _make_note("Test", "Content here.", ["link1", "link2", "link3"], [])
	var layout := generator.compute_layout(note)

	assert_int(layout["doorways"].size()).is_equal(3)
	for d in layout["doorways"]:
		assert_bool(d["target"] in ["link1", "link2", "link3"]).is_true()

func test_sealed_doors_match_backlinks() -> void:
	var note := _make_note("Test", "Content.", [], ["back1", "back2"])
	var layout := generator.compute_layout(note)

	assert_int(layout["sealed_doors"].size()).is_equal(2)

func test_wall_panels_generated_from_content() -> void:
	var long_content := "Word " .repeat(100)  # ~100 words
	var note := _make_note("Test", long_content, [], [])
	var layout := generator.compute_layout(note)

	assert_bool(layout["wall_panels"].size() > 0).is_true()

func _make_note(title: String, content: String, links: Array, backlinks: Array) -> Dictionary:
	return {
		"id": title,
		"title": title,
		"content": content,
		"outgoing_links": links,
		"backlinks": backlinks,
		"tags": [],
		"word_count": content.split(" ", false).size(),
	}
```

- [ ] **Step 2: Run tests — verify failure**

- [ ] **Step 3: Implement hallway_generator.gd**

```gdscript
# layers/corridor/hallway_generator.gd
extends RefCounted
class_name HallwayGenerator

const PANEL_CHARS := 500       # Characters per wall panel
const SEGMENT_LENGTH := 8.0    # Meters per hallway segment
const HALLWAY_WIDTH := 4.0
const HALLWAY_HEIGHT := 3.5

## Computes the corridor layout data (positions, sizes, content)
## Does NOT create nodes — that's corridor_layer.gd's job
func compute_layout(note_data: Dictionary) -> Dictionary:
	var content: String = note_data.get("content", "")
	var outgoing: Array = note_data.get("outgoing_links", [])
	var backlinks: Array = note_data.get("backlinks", [])
	var tags: Array = note_data.get("tags", [])

	# Wall panels: chunk content into PANEL_CHARS segments
	var wall_panels: Array = []
	var idx := 0
	var panel_index := 0
	while idx < content.length():
		var end := mini(idx + PANEL_CHARS, content.length())
		var chunk := content.substr(idx, end - idx)
		var side := "left" if panel_index % 2 == 0 else "right"
		var z_pos := panel_index * (SEGMENT_LENGTH / 2.0)
		wall_panels.append({
			"text": chunk,
			"side": side,
			"position_z": z_pos,
			"index": panel_index,
		})
		panel_index += 1
		idx = end

	# Ensure at least one panel
	if wall_panels.is_empty():
		wall_panels.append({
			"text": note_data.get("title", "Empty note"),
			"side": "left",
			"position_z": 0.0,
			"index": 0,
		})

	# Hallway segments
	var total_length := maxf(wall_panels.size() * (SEGMENT_LENGTH / 2.0), SEGMENT_LENGTH * 2.0)
	var num_segments := ceili(total_length / SEGMENT_LENGTH)
	var segments: Array = []
	for i in range(num_segments):
		segments.append({
			"position_z": i * SEGMENT_LENGTH,
			"length": SEGMENT_LENGTH,
			"width": HALLWAY_WIDTH,
			"height": HALLWAY_HEIGHT,
		})

	# Doorways (outgoing links) — placed at the far end, branching
	var doorways: Array = []
	for i in range(outgoing.size()):
		var side_offset := (i - outgoing.size() / 2.0) * 3.0
		doorways.append({
			"target": outgoing[i],
			"position_z": total_length,
			"position_x": side_offset,
			"is_outgoing": true,
		})

	# Sealed doors (backlinks) — placed behind spawn
	var sealed_doors: Array = []
	for i in range(backlinks.size()):
		var side_offset := (i - backlinks.size() / 2.0) * 3.0
		sealed_doors.append({
			"source": backlinks[i],
			"position_z": -SEGMENT_LENGTH / 2.0,
			"position_x": side_offset,
		})

	return {
		"segments": segments,
		"wall_panels": wall_panels,
		"doorways": doorways,
		"sealed_doors": sealed_doors,
		"total_length": total_length,
		"tags": tags,
	}
```

- [ ] **Step 4: Run tests — verify pass**

- [ ] **Step 5: Commit**

```bash
git add layers/corridor/hallway_generator.gd tests/test_hallway_generator.gd
git commit -m "feat: add procedural hallway generator for corridor layout computation"
```

---

### Task 12: Holographic Text Shader & Wall Panels

**Files:**
- Create: `shaders/holographic_text.gdshader`
- Create: `layers/corridor/wall_panel.gd`
- Create: `layers/corridor/wall_panel.tscn`

- [ ] **Step 1: Create holographic text shader**

```glsl
// shaders/holographic_text.gdshader
shader_type spatial;
render_mode blend_mix, unshaded;

uniform sampler2D text_texture : hint_default_white;
uniform vec4 text_color : source_color = vec4(0.98, 0.72, 0.2, 1.0);
uniform float scan_line_density : hint_range(50.0, 500.0) = 200.0;
uniform float scan_line_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float jitter_amount : hint_range(0.0, 0.02) = 0.003;
uniform float flicker_speed : hint_range(0.0, 10.0) = 3.0;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.1;
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;

float random(vec2 st) {
	return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;

	// Horizontal jitter (per-line, time-varying)
	float line = floor(uv.y * scan_line_density);
	float jitter = (random(vec2(line, floor(TIME * 8.0))) - 0.5) * jitter_amount;
	uv.x += jitter;

	// Sample text texture
	vec4 tex = texture(text_texture, uv);

	// Scan lines
	float scan = sin(uv.y * scan_line_density * 3.14159) * 0.5 + 0.5;
	scan = mix(1.0, scan, scan_line_intensity);

	// Flicker
	float flicker = 1.0 - flicker_intensity * (sin(TIME * flicker_speed) * 0.5 + 0.5);
	flicker *= 1.0 - flicker_intensity * 0.5 * random(vec2(floor(TIME * 15.0), 0.0));

	// Compose
	float alpha = tex.a * scan * flicker;
	ALBEDO = text_color.rgb * tex.rgb;
	EMISSION = text_color.rgb * glow_strength * tex.rgb * scan * flicker;
	ALPHA = alpha * text_color.a;
}
```

- [ ] **Step 2: Create wall_panel.gd**

```gdscript
# layers/corridor/wall_panel.gd
extends Node3D

var text_content: String = ""
var panel_side: String = "left"  # "left" or "right"

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var viewport: SubViewport = $SubViewport

const PANEL_WIDTH := 3.5
const PANEL_HEIGHT := 2.5

func _ready() -> void:
	_render_text()

func setup(p_text: String, p_side: String, z_position: float) -> void:
	text_content = p_text
	panel_side = p_side
	var x_offset := -2.0 if p_side == "left" else 2.0
	var y_rot := PI / 2.0 if p_side == "left" else -PI / 2.0
	position = Vector3(x_offset, 1.8, z_position)
	rotation.y = y_rot

func _render_text() -> void:
	# Set up SubViewport for text rendering
	viewport.size = Vector2i(1024, 768)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Add a RichTextLabel to the viewport
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text_content
	label.size = Vector2(1024, 768)
	label.add_theme_font_size_override("normal_font_size", 22)
	label.add_theme_color_override("default_color", Color.WHITE)
	viewport.add_child(label)

	# Wait for viewport to render
	await get_tree().process_frame
	await get_tree().process_frame

	# Apply viewport texture to mesh with holographic shader
	var tex := viewport.get_texture()
	var shader = load("res://shaders/holographic_text.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("text_texture", tex)
	mat.set_shader_parameter("text_color", Color(0.98, 0.72, 0.2, 0.9))
	mesh.set_surface_override_material(0, mat)
```

- [ ] **Step 3: Create wall_panel.tscn**

In Godot:
1. Node3D root → attach `wall_panel.gd`
2. Add MeshInstance3D child with PlaneMesh (size 3.5 x 2.5)
3. Add SubViewport child (size 1024x768, transparent background)
4. Save as `layers/corridor/wall_panel.tscn`

- [ ] **Step 4: Commit**

```bash
git add shaders/holographic_text.gdshader layers/corridor/wall_panel.gd layers/corridor/wall_panel.tscn
git commit -m "feat: add holographic text shader and wall panel with SubViewport text rendering"
```

---

### Task 13: Corridor Layer Scene & Doorways

**Files:**
- Create: `layers/corridor/corridor_layer.gd`
- Create: `layers/corridor/corridor_layer.tscn`
- Create: `layers/corridor/doorway.gd`
- Create: `layers/corridor/doorway.tscn`
- Create: `layers/corridor/corridor_environment.tres`
- Create: `shaders/code_rain.gdshader`
- Create: `particles/corridor_dust.tscn`

- [ ] **Step 1: Create code rain shader**

```glsl
// shaders/code_rain.gdshader
shader_type spatial;
render_mode blend_add, unshaded;

uniform sampler2D glyph_atlas : hint_default_white;
uniform vec4 rain_color : source_color = vec4(0.1, 0.9, 0.3, 0.7);
uniform float scroll_speed : hint_range(0.1, 5.0) = 1.5;
uniform float columns : hint_range(5.0, 50.0) = 20.0;
uniform float brightness_variation : hint_range(0.0, 1.0) = 0.6;

float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Grid
	float col = floor(uv.x * columns);
	float row_speed = 0.5 + random(vec2(col, 0.0)) * scroll_speed;
	float row_offset = random(vec2(col, 1.0)) * 100.0;

	// Scrolling
	float scroll = uv.y + TIME * row_speed + row_offset;
	float row = floor(scroll * columns);

	// Character selection (random per cell)
	float char_idx = random(vec2(col, row));

	// Brightness (fades toward bottom of each "stream")
	float stream_pos = fract(scroll * columns);
	float brightness = (1.0 - stream_pos) * (0.4 + brightness_variation * random(vec2(col, floor(TIME))));

	// Leading character is brighter
	float lead = step(0.9, 1.0 - stream_pos) * 2.0;

	// Compose
	float alpha = brightness * rain_color.a;
	alpha *= step(0.3, random(vec2(col, floor(TIME * 0.5))));  // Some columns off

	ALBEDO = rain_color.rgb * (1.0 + lead);
	EMISSION = rain_color.rgb * (brightness + lead) * 2.0;
	ALPHA = alpha;
}
```

- [ ] **Step 2: Create doorway.gd**

```gdscript
# layers/corridor/doorway.gd
extends Node3D

var target_note_id: String = ""
var is_outgoing: bool = true
var display_title: String = ""

@onready var frame_mesh: MeshInstance3D = $Frame
@onready var portal_mesh: MeshInstance3D = $Portal
@onready var label: Label3D = $Label3D

func setup(p_target_id: String, p_title: String, p_is_outgoing: bool) -> void:
	target_note_id = p_target_id
	display_title = p_title
	is_outgoing = p_is_outgoing

func _ready() -> void:
	label.text = display_title

	if is_outgoing:
		# Glowing portal effect
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.5, 0.98)
		mat.emission_energy_multiplier = 3.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.1, 0.3, 0.8, 0.4)
		portal_mesh.set_surface_override_material(0, mat)
	else:
		# Sealed door — dim red
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.02, 0.02)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.05, 0.05)
		mat.emission_energy_multiplier = 0.5
		portal_mesh.set_surface_override_material(0, mat)

	set_meta("note_id", target_note_id)
	set_meta("is_outgoing", is_outgoing)
```

- [ ] **Step 3: Create doorway.tscn**

In Godot:
1. Node3D root → attach `doorway.gd`
2. Add MeshInstance3D "Frame" with BoxMesh (size 2.5 x 3.0 x 0.2) — doorframe
3. Add MeshInstance3D "Portal" with PlaneMesh (size 2.0 x 2.8) — portal surface
4. Add Label3D above at (0, 3.2, 0)
5. Add Area3D with CollisionShape3D (BoxShape3D matching portal size) for interaction detection
6. Save as `layers/corridor/doorway.tscn`

- [ ] **Step 4: Create corridor_layer.gd**

```gdscript
# layers/corridor/corridor_layer.gd
extends Node3D

const WallPanelScene = preload("res://layers/corridor/wall_panel.tscn")
const DoorwayScene = preload("res://layers/corridor/doorway.tscn")

var current_note_id: String = ""
var _hallway_gen := HallwayGenerator.new()

func _ready() -> void:
	if not current_note_id.is_empty():
		build_corridor(current_note_id)

func build_corridor(note_id: String) -> void:
	current_note_id = note_id
	# Clear existing corridor
	for child in get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			continue
		child.queue_free()

	var note = VaultDataBus.graph.get_note(note_id)
	if not note:
		return

	var backlinks := VaultDataBus.graph.get_backlinks(note_id)
	var layout := _hallway_gen.compute_layout({
		"id": note.id,
		"title": note.title,
		"content": note.content,
		"outgoing_links": note.outgoing_links,
		"backlinks": backlinks,
		"tags": note.tags,
		"word_count": note.word_count,
	})

	# Build hallway geometry
	_build_hallway_geometry(layout)

	# Place wall panels
	for panel_data in layout["wall_panels"]:
		var panel = WallPanelScene.instantiate()
		panel.setup(panel_data["text"], panel_data["side"], panel_data["position_z"])
		add_child(panel)

	# Place outgoing doorways
	for doorway_data in layout["doorways"]:
		var doorway = DoorwayScene.instantiate()
		var target_note = VaultDataBus.graph.get_note(doorway_data["target"])
		var title := target_note.title if target_note else doorway_data["target"]
		doorway.setup(doorway_data["target"], title, true)
		doorway.position = Vector3(doorway_data["position_x"], 0, doorway_data["position_z"])
		add_child(doorway)

	# Place sealed doors (backlinks)
	for door_data in layout["sealed_doors"]:
		var doorway = DoorwayScene.instantiate()
		var source_note = VaultDataBus.graph.get_note(door_data["source"])
		var title := source_note.title if source_note else door_data["source"]
		doorway.setup(door_data["source"], title, false)
		doorway.position = Vector3(door_data["position_x"], 0, door_data["position_z"])
		doorway.rotation.y = PI  # Face backward
		add_child(doorway)

func _build_hallway_geometry(layout: Dictionary) -> void:
	for seg in layout["segments"]:
		var z: float = seg["position_z"]
		var w: float = seg["width"]
		var h: float = seg["height"]
		var l: float = seg["length"]

		# Floor
		var floor_mesh := MeshInstance3D.new()
		var floor_plane := PlaneMesh.new()
		floor_plane.size = Vector2(w, l)
		floor_mesh.mesh = floor_plane
		floor_mesh.position = Vector3(0, 0, z + l / 2.0)
		var floor_mat := StandardMaterial3D.new()
		floor_mat.albedo_color = Color(0.03, 0.04, 0.08)
		floor_mat.metallic = 0.9
		floor_mat.roughness = 0.1
		floor_mesh.set_surface_override_material(0, floor_mat)
		add_child(floor_mesh)

		# Ceiling
		var ceil_mesh := MeshInstance3D.new()
		ceil_mesh.mesh = floor_plane.duplicate()
		ceil_mesh.position = Vector3(0, h, z + l / 2.0)
		ceil_mesh.rotation.x = PI
		var ceil_mat := StandardMaterial3D.new()
		ceil_mat.albedo_color = Color(0.02, 0.02, 0.05)
		ceil_mesh.set_surface_override_material(0, ceil_mat)
		add_child(ceil_mesh)

		# Left wall
		var left_wall := MeshInstance3D.new()
		var wall_plane := PlaneMesh.new()
		wall_plane.size = Vector2(l, h)
		left_wall.mesh = wall_plane
		left_wall.position = Vector3(-w / 2.0, h / 2.0, z + l / 2.0)
		left_wall.rotation.y = PI / 2.0
		# Code rain shader on walls
		var rain_shader = load("res://shaders/code_rain.gdshader")
		var wall_mat := ShaderMaterial.new()
		wall_mat.shader = rain_shader
		wall_mat.set_shader_parameter("rain_color", Color(0.1, 0.8, 0.3, 0.15))
		wall_mat.set_shader_parameter("columns", 25.0)
		left_wall.set_surface_override_material(0, wall_mat)
		add_child(left_wall)

		# Right wall
		var right_wall := MeshInstance3D.new()
		right_wall.mesh = wall_plane.duplicate()
		right_wall.position = Vector3(w / 2.0, h / 2.0, z + l / 2.0)
		right_wall.rotation.y = -PI / 2.0
		var right_mat := wall_mat.duplicate()
		right_wall.set_surface_override_material(0, right_mat)
		add_child(right_wall)

	# Ambient light strip along ceiling center
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.6, 0.2)
	light.light_energy = 2.0
	light.omni_range = 15.0
	light.position = Vector3(0, layout["segments"][0]["height"] - 0.3, layout["total_length"] / 2.0)
	add_child(light)
```

- [ ] **Step 5: Create corridor_layer.tscn**

In Godot:
1. Node3D root → attach `corridor_layer.gd`
2. Add WorldEnvironment:
   - Background: Custom Color `#050308`
   - Volumetric Fog: Enabled, Density = 0.08, Albedo = `#1a0a05`, Height = 1.0 (low-lying)
   - Glow: Enabled, Intensity = 1.5, Bloom = 0.6
   - SSAO: Enabled, Radius = 1.5
   - SSR: Enabled (reflective floors)
3. Save as `layers/corridor/corridor_layer.tscn`

- [ ] **Step 6: Test corridor layer**

Temporarily update `main.gd`:

```gdscript
func _on_vault_loaded() -> void:
	var corridor_scene = load("res://layers/corridor/corridor_layer.tscn")
	var corridor = corridor_scene.instantiate()
	corridor.current_note_id = "void-term-bible/World/Factions/The Foundation"
	add_child(corridor)
	var cam = load("res://camera/player_camera.tscn").instantiate()
	cam.position = Vector3(0, 1, 2)
	add_child(cam)
```

Expected: Walk through a corridor with holographic text on walls showing The Foundation's content. Code rain on background walls. Outgoing link doorways ahead glowing blue. Backlink sealed doors behind glowing dim red. Reflective floor. Volumetric fog at ground level.

- [ ] **Step 7: Commit**

```bash
git add layers/corridor/ shaders/code_rain.gdshader particles/corridor_dust.tscn
git commit -m "feat: add corridor layer with procedural hallways, holographic text, code rain, and doorways"
```

---

## Phase 5: Layer Transitions & Navigation (Tasks 14-16)

### Task 14: Layer Manager

**Files:**
- Create: `autoloads/layer_manager.gd`
- Create: `camera/transition_camera.gd`
- Create: `shaders/layer_shift.gdshader`
- Modify: `project.godot` (register autoload)

- [ ] **Step 1: Create layer shift shader (post-process)**

```glsl
// shaders/layer_shift.gdshader
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float aberration_strength : hint_range(0.0, 0.05) = 0.02;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.05;

void fragment() {
	vec2 uv = UV;
	float center_dist = length(uv - vec2(0.5));

	// Radial distortion
	vec2 distort = (uv - vec2(0.5)) * distortion_strength * progress * center_dist;
	uv += distort;

	// Chromatic aberration
	float aberration = aberration_strength * progress;
	float r = texture(TEXTURE, uv + vec2(aberration, 0.0)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - vec2(aberration, 0.0)).b;
	float a = texture(TEXTURE, uv).a;

	// Brightness flash at midpoint
	float flash = smoothstep(0.3, 0.5, progress) * smoothstep(0.7, 0.5, progress) * 0.5;

	COLOR = vec4(r + flash, g + flash, b + flash, a);
}
```

- [ ] **Step 2: Create transition_camera.gd**

```gdscript
# camera/transition_camera.gd
extends Camera3D

signal transition_completed()

var _tween: Tween

func animate_to(target_pos: Vector3, target_rot: Vector3, duration: float = 1.5) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "global_position", target_pos, duration)
	_tween.tween_property(self, "rotation", target_rot, duration)
	_tween.set_parallel(false)
	_tween.tween_callback(func(): transition_completed.emit())
```

- [ ] **Step 3: Create layer_manager.gd**

```gdscript
# autoloads/layer_manager.gd
extends Node

enum Layer { GRAPH, CITY, CORRIDOR }

var current_layer: Layer = Layer.CITY
var current_scene: Node3D = null
var current_camera: Node = null
var _transition_overlay: ColorRect
var _transition_material: ShaderMaterial

signal layer_changed(new_layer: Layer)
signal transition_started()
signal transition_completed()

const SCENES := {
	Layer.GRAPH: "res://layers/graph/graph_layer.tscn",
	Layer.CITY: "res://layers/city/city_layer.tscn",
	Layer.CORRIDOR: "res://layers/corridor/corridor_layer.tscn",
}

const CAMERAS := {
	Layer.GRAPH: "res://camera/flight_camera.tscn",
	Layer.CITY: "res://camera/player_camera.tscn",
	Layer.CORRIDOR: "res://camera/player_camera.tscn",
}

func _ready() -> void:
	# Post-process overlay for transition effect
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	_transition_overlay = ColorRect.new()
	_transition_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_transition_overlay.visible = false
	var shader = load("res://shaders/layer_shift.gdshader")
	_transition_material = ShaderMaterial.new()
	_transition_material.shader = shader
	_transition_overlay.material = _transition_material
	canvas.add_child(_transition_overlay)
	add_child(canvas)

func load_layer(layer: Layer, context: Dictionary = {}) -> void:
	var scene_res = load(SCENES[layer])
	var scene_instance = scene_res.instantiate()

	# Apply context
	if layer == Layer.CORRIDOR and context.has("note_id"):
		scene_instance.current_note_id = context["note_id"]

	var cam_res = load(CAMERAS[layer])
	var cam_instance = cam_res.instantiate()

	# Position camera based on context
	if context.has("camera_position"):
		cam_instance.global_position = context["camera_position"]
	elif layer == Layer.GRAPH:
		cam_instance.position = Vector3(0, 30, 80)
	elif layer == Layer.CITY:
		cam_instance.position = Vector3(150, 2, 150)
	elif layer == Layer.CORRIDOR:
		cam_instance.position = Vector3(0, 1, 2)

	# Add to tree
	get_tree().root.get_node("Main").add_child(scene_instance)
	get_tree().root.get_node("Main").add_child(cam_instance)

	current_scene = scene_instance
	current_camera = cam_instance
	current_layer = layer
	layer_changed.emit(layer)

func transition_to(target_layer: Layer, context: Dictionary = {}) -> void:
	transition_started.emit()

	# Transition effect
	_transition_overlay.visible = true
	var tween := create_tween()
	tween.tween_method(func(v): _transition_material.set_shader_parameter("progress", v), 0.0, 1.0, 0.75)
	await tween.finished

	# Swap scenes
	if current_scene:
		current_scene.queue_free()
	if current_camera:
		current_camera.queue_free()

	await get_tree().process_frame

	load_layer(target_layer, context)

	# Fade out transition
	var tween2 := create_tween()
	tween2.tween_method(func(v): _transition_material.set_shader_parameter("progress", v), 1.0, 0.0, 0.75)
	await tween2.finished
	_transition_overlay.visible = false

	transition_completed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Space to ascend
		if event.keycode == KEY_SPACE:
			if current_layer == Layer.CORRIDOR:
				var ctx := {"camera_position": Vector3(150, 2, 150)}
				transition_to(Layer.CITY, ctx)
			elif current_layer == Layer.CITY:
				transition_to(Layer.GRAPH)
```

- [ ] **Step 4: Register autoloads in project.godot**

```ini
[autoload]

VaultDataBus="*res://autoloads/vault_data_bus.gd"
LayerManager="*res://autoloads/layer_manager.gd"
```

- [ ] **Step 5: Update main.gd to use LayerManager**

```gdscript
# main.gd
extends Node3D

@export var vault_path: String = ""

func _ready() -> void:
	print("Obsidian Nexus — initializing")

	if vault_path.is_empty():
		vault_path = OS.get_environment("OBSIDIAN_VAULT_PATH")
		if vault_path.is_empty():
			var config_path := "user://vault_config.txt"
			if FileAccess.file_exists(config_path):
				vault_path = FileAccess.get_file_as_string(config_path).strip_edges()

	if vault_path.is_empty():
		push_error("No vault path. Set OBSIDIAN_VAULT_PATH env var.")
		return

	VaultDataBus.vault_loaded.connect(_on_vault_loaded)
	VaultDataBus.initialize(vault_path)

func _on_vault_loaded() -> void:
	print("Vault loaded: %d notes, %d links" % [VaultDataBus.graph.get_note_count(), VaultDataBus.graph.get_link_count()])
	# Start in city layer
	LayerManager.load_layer(LayerManager.Layer.CITY)
```

- [ ] **Step 6: Test layer transitions**

Run project. Walk around city. Press Space → chromatic aberration effect → ascend to graph layer with flight camera. Press Space again → nothing (already at top). Navigate graph.

- [ ] **Step 7: Commit**

```bash
git add autoloads/layer_manager.gd camera/transition_camera.gd shaders/layer_shift.gdshader main.gd project.godot
git commit -m "feat: add layer manager with chromatic aberration transitions between all three layers"
```

---

### Task 15: Input Manager & Interaction System

**Files:**
- Create: `autoloads/input_manager.gd`
- Modify: `project.godot` (register autoload)

- [ ] **Step 1: Implement input_manager.gd**

```gdscript
# autoloads/input_manager.gd
extends Node

signal note_hovered(note_id: String)
signal note_unhovered()
signal note_clicked(note_id: String)
signal search_requested()
signal tag_filter_requested()

var _raycast_distance := 100.0
var _hovered_note_id: String = ""

func _physics_process(_delta: float) -> void:
	_update_hover()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _hovered_note_id.is_empty():
			note_clicked.emit(_hovered_note_id)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SLASH:
			search_requested.emit()
		elif event.keycode == KEY_T:
			tag_filter_requested.emit()

func _update_hover() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * _raycast_distance

	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)

	if result:
		var collider = result["collider"]
		# Walk up to find note_id metadata
		var node = collider
		while node:
			if node.has_meta("note_id"):
				var note_id: String = node.get_meta("note_id")
				if note_id != _hovered_note_id:
					_hovered_note_id = note_id
					note_hovered.emit(note_id)
				return
			node = node.get_parent()

	if not _hovered_note_id.is_empty():
		_hovered_note_id = ""
		note_unhovered.emit()
```

- [ ] **Step 2: Register autoload**

Add to `project.godot` autoloads:

```ini
InputManager="*res://autoloads/input_manager.gd"
```

- [ ] **Step 3: Commit**

```bash
git add autoloads/input_manager.gd project.godot
git commit -m "feat: add input manager with raycast hover detection and key bindings"
```

---

### Task 16: UI Manager (Hover Panel, Search, Tag Filter)

**Files:**
- Create: `autoloads/ui_manager.gd`
- Create: `ui/hover_panel.tscn` / `ui/hover_panel.gd`
- Create: `ui/search_overlay.tscn` / `ui/search_overlay.gd`
- Create: `ui/tag_wheel.tscn` / `ui/tag_wheel.gd`
- Create: `ui/focus_panel.tscn` / `ui/focus_panel.gd`
- Create: `ui/hud.tscn` / `ui/hud.gd`
- Modify: `project.godot` (register autoload)

- [ ] **Step 1: Create hover_panel.gd**

```gdscript
# ui/hover_panel.gd
extends PanelContainer

@onready var title_label: Label = $VBox/Title
@onready var tags_label: Label = $VBox/Tags
@onready var preview_label: RichTextLabel = $VBox/Preview
@onready var connections_label: Label = $VBox/Connections

func show_note(note_id: String) -> void:
	var note = VaultDataBus.graph.get_note(note_id)
	if not note:
		hide()
		return

	title_label.text = note.title
	tags_label.text = ", ".join(note.tags) if note.tags.size() > 0 else "no tags"
	var preview_text := note.content.substr(0, 200)
	if note.content.length() > 200:
		preview_text += "..."
	preview_label.text = preview_text
	var conns := VaultDataBus.graph.get_connection_count(note_id)
	connections_label.text = "%d connections" % conns

	# Position near mouse
	var mouse_pos := get_viewport().get_mouse_position()
	position = mouse_pos + Vector2(20, 20)
	show()

func hide_panel() -> void:
	hide()
```

- [ ] **Step 2: Create search_overlay.gd**

```gdscript
# ui/search_overlay.gd
extends CanvasLayer

@onready var search_input: LineEdit = $Panel/VBox/SearchInput
@onready var results_list: ItemList = $Panel/VBox/ResultsList

var _all_notes: Array = []
var _filtered_ids: Array = []

signal note_selected(note_id: String)
signal search_closed()

func _ready() -> void:
	visible = false
	search_input.text_changed.connect(_on_search_changed)
	results_list.item_selected.connect(_on_result_selected)

func open_search() -> void:
	_all_notes = VaultDataBus.graph.get_all_notes()
	visible = true
	search_input.text = ""
	search_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_search() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	search_closed.emit()

func _on_search_changed(query: String) -> void:
	results_list.clear()
	_filtered_ids.clear()
	if query.length() < 2:
		return

	var lower_query := query.to_lower()
	for note in _all_notes:
		if lower_query in note.title.to_lower() or lower_query in note.content.to_lower():
			results_list.add_item(note.title)
			_filtered_ids.append(note.id)
		if _filtered_ids.size() >= 20:
			break

func _on_result_selected(index: int) -> void:
	if index < _filtered_ids.size():
		note_selected.emit(_filtered_ids[index])
		close_search()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_search()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 3: Create tag_wheel.gd**

```gdscript
# ui/tag_wheel.gd
extends CanvasLayer

@onready var tag_list: ItemList = $Panel/VBox/TagList
@onready var clear_button: Button = $Panel/VBox/ClearButton

var _active_tags: Array[String] = []

signal tags_changed(active_tags: Array[String])
signal wheel_closed()

func _ready() -> void:
	visible = false
	clear_button.pressed.connect(_clear_tags)

func open_wheel() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_populate_tags()

func close_wheel() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	wheel_closed.emit()

func _populate_tags() -> void:
	tag_list.clear()
	var tags := VaultDataBus.graph.get_all_tags()
	for tag in tags:
		var count := VaultDataBus.graph.get_notes_by_tag(tag).size()
		var idx := tag_list.add_item("%s (%d)" % [tag, count])
		if tag in _active_tags:
			tag_list.select(idx, false)

func _on_tag_selected(index: int) -> void:
	var tag_text: String = tag_list.get_item_text(index)
	var tag := tag_text.split(" (")[0]
	if tag in _active_tags:
		_active_tags.erase(tag)
	else:
		_active_tags.append(tag)
	tags_changed.emit(_active_tags)

func _clear_tags() -> void:
	_active_tags.clear()
	tag_list.deselect_all()
	tags_changed.emit(_active_tags)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_wheel()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 4: Create ui_manager.gd**

```gdscript
# autoloads/ui_manager.gd
extends CanvasLayer

var hover_panel: Control
var search_overlay: Node
var tag_wheel: Node
var _crosshair: Control

func _ready() -> void:
	layer = 5

	# Crosshair
	_crosshair = ColorRect.new()
	_crosshair.size = Vector2(4, 4)
	_crosshair.color = Color(1, 1, 1, 0.5)
	_crosshair.anchors_preset = Control.PRESET_CENTER
	_crosshair.position = -Vector2(2, 2)
	add_child(_crosshair)

	# Hover panel (load scene or create programmatically)
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
	# Enter corridor for the clicked note
	if LayerManager.current_layer != LayerManager.Layer.CORRIDOR:
		LayerManager.transition_to(LayerManager.Layer.CORRIDOR, {"note_id": note_id})
	# If already in corridor, navigate to linked note
	else:
		var corridor = LayerManager.current_scene
		if corridor and corridor.has_method("build_corridor"):
			corridor.build_corridor(note_id)

func _on_search_requested() -> void:
	# Simple search — create inline if scene not loaded
	print("Search requested — TODO: full overlay")

func _on_tag_filter_requested() -> void:
	print("Tag filter requested — TODO: full overlay")
```

- [ ] **Step 5: Register autoload**

```ini
UIManager="*res://autoloads/ui_manager.gd"
InputManager="*res://autoloads/input_manager.gd"
```

- [ ] **Step 6: Test full interaction loop**

Run project → walk city → hover over tower (see preview panel) → click tower → chromatic aberration transition → enter corridor with note content on walls → press Space → ascend back to city.

- [ ] **Step 7: Commit**

```bash
git add autoloads/ui_manager.gd autoloads/input_manager.gd ui/ project.godot
git commit -m "feat: add UI manager with hover panels, search, tag filter, and note click-to-enter"
```

---

## Phase 6: Visual Polish (Tasks 17-19)

### Task 17: Energy Pulse Shader for Link Beams

**Files:**
- Create: `shaders/energy_pulse.gdshader`
- Modify: `layers/graph/graph_edge_renderer.gd` (apply shader)
- Modify: `layers/city/city_beam_renderer.gd` (apply shader)

- [ ] **Step 1: Create energy pulse shader**

```glsl
// shaders/energy_pulse.gdshader
shader_type spatial;
render_mode blend_add, unshaded;

uniform vec4 beam_color : source_color = vec4(0.3, 0.4, 0.93, 0.5);
uniform float pulse_speed : hint_range(0.1, 5.0) = 2.0;
uniform float pulse_width : hint_range(0.05, 0.5) = 0.15;
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	float pulse_pos = fract(UV.x - TIME * pulse_speed);
	float pulse = smoothstep(pulse_width, 0.0, abs(pulse_pos - 0.5));

	float edge_fade = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.7, UV.y);

	float alpha = (base_alpha + pulse * 0.6) * edge_fade;

	ALBEDO = beam_color.rgb;
	EMISSION = beam_color.rgb * glow_strength * (base_alpha + pulse);
	ALPHA = alpha * beam_color.a;
}
```

- [ ] **Step 2: Apply to graph edge renderer**

Update `graph_edge_renderer.gd` to use TubeMesh or MeshInstance3D strips with the energy pulse shader instead of ImmediateMesh lines. For simplicity, apply as material override.

- [ ] **Step 3: Apply to city beam renderer**

Same treatment for city beams.

- [ ] **Step 4: Commit**

```bash
git add shaders/energy_pulse.gdshader layers/graph/graph_edge_renderer.gd layers/city/city_beam_renderer.gd
git commit -m "feat: add energy pulse shader to link beams in graph and city layers"
```

---

### Task 18: GPU Particle Systems

**Files:**
- Create: `particles/ambient_motes.tscn`
- Create: `particles/link_sparks.tscn`
- Create: `particles/ember_rise.tscn`
- Create: `particles/note_cascade.tscn`

- [ ] **Step 1: Create ambient motes particle scene**

In Godot:
1. GPUParticles3D root
2. Process Material:
   - Emission shape: Box (50x30x50)
   - Direction: (0, 0.2, 0) with spread 180
   - Initial velocity: 0.3
   - Gravity: (0, 0, 0)
   - Scale: 0.02-0.05, random
   - Color: light blue #4488ff with alpha 0.3
   - Lifetime: 8s
   - Amount: 2000
3. Draw pass: SphereMesh (radius 0.02)
4. Material: Unshaded, emission enabled, blue
5. Save as `particles/ambient_motes.tscn`

- [ ] **Step 2: Create ember rise particle scene**

In Godot:
1. GPUParticles3D
2. Process Material:
   - Emission shape: Point
   - Direction: (0, 1, 0) with spread 30
   - Initial velocity: 1.0-2.0
   - Gravity: (0, -0.5, 0)
   - Scale: 0.01-0.03
   - Color ramp: orange → red → transparent
   - Lifetime: 3s
   - Amount: 200
3. Save as `particles/ember_rise.tscn`

- [ ] **Step 3: Create note cascade particle scene**

In Godot:
1. GPUParticles3D, one_shot = true
2. Process Material:
   - Emission shape: Sphere (radius 0.5)
   - Direction: outward (spread 180)
   - Initial velocity: 3.0-5.0
   - Damping: 5.0
   - Scale: 0.02, fade over lifetime
   - Color: cyan #22d3ee → transparent
   - Lifetime: 1.5s
   - Amount: 500
3. Save as `particles/note_cascade.tscn`

- [ ] **Step 4: Add particles to layers**

Update `graph_layer.gd`, `city_layer.gd`, and `corridor_layer.gd` to instantiate appropriate particle scenes as children.

- [ ] **Step 5: Commit**

```bash
git add particles/
git commit -m "feat: add GPU particle systems — ambient motes, embers, link sparks, note cascade"
```

---

### Task 19: Environment Polish & Per-Layer Tuning

**Files:**
- Update: `layers/graph/graph_environment.tres`
- Update: `layers/city/city_environment.tres`
- Update: `layers/corridor/corridor_environment.tres`

- [ ] **Step 1: Fine-tune graph environment**

In Godot editor, adjust `graph_environment.tres`:
- Background: Custom Color `#060a16` (near-black blue)
- Ambient: Sky contribution 0, Color `#1a2050`, Energy 0.15
- Glow: Intensity 0.8, Bloom 0.3, HDR Threshold 0.8, Blend Mode Additive
- Volumetric Fog: Density 0.003, Albedo `#0a1030`, Emission `#000510`
- SSAO: Radius 3.0, Intensity 2.0

- [ ] **Step 2: Fine-tune city environment**

- Background: Custom Color `#080c18`
- Ambient: Color `#1a1530`, Energy 0.2
- Glow: Intensity 1.2, Bloom 0.5, HDR Threshold 0.6
- Volumetric Fog: Density 0.035, Albedo `#1a1030`, Height 20.0
- SDFGI: Enabled, Energy 0.8, Cascades 4
- SSR: Enabled, Max Steps 64, Fade In 0.15
- SSAO: Radius 2.0, Intensity 2.5

- [ ] **Step 3: Fine-tune corridor environment**

- Background: Custom Color `#040208`
- Ambient: Color `#150a05`, Energy 0.1
- Glow: Intensity 1.5, Bloom 0.6, HDR Threshold 0.5
- Volumetric Fog: Density 0.08, Albedo `#1a0a05`, Height 1.2, Height Falloff 2.0
- SSR: Enabled, Max Steps 48
- SSAO: Radius 1.5, Intensity 3.0
- No SDFGI (corridor is too small, SSAO + direct lights sufficient)

- [ ] **Step 4: Test each layer's atmosphere**

Run through all three layers. Graph should feel vast and cold. City should feel dense and neon-lit. Corridor should feel tight, warm, and moody.

- [ ] **Step 5: Commit**

```bash
git add layers/graph/graph_environment.tres layers/city/city_environment.tres layers/corridor/corridor_environment.tres
git commit -m "feat: fine-tune per-layer environment settings for atmospheric visual identity"
```

---

## Phase 7: Integration & Final (Tasks 20-21)

### Task 20: Link Travel & Corridor Navigation

**Files:**
- Modify: `layers/corridor/corridor_layer.gd`
- Modify: `autoloads/ui_manager.gd`

- [ ] **Step 1: Add doorway interaction to corridor**

Update `corridor_layer.gd` to detect when the player walks into a doorway Area3D:

```gdscript
# Add to corridor_layer.gd after building doorways:

func _connect_doorway_signals() -> void:
	for child in get_children():
		if child.has_meta("note_id") and child.has_meta("is_outgoing"):
			if child.get_meta("is_outgoing"):
				# Find the Area3D in the doorway
				for subchild in child.get_children():
					if subchild is Area3D:
						subchild.body_entered.connect(func(_body):
							_on_doorway_entered(child.get_meta("note_id"))
						)

func _on_doorway_entered(target_note_id: String) -> void:
	build_corridor(target_note_id)
	# Reset player position to start of new corridor
	if LayerManager.current_camera:
		LayerManager.current_camera.global_position = Vector3(0, 1, 2)
```

- [ ] **Step 2: Test corridor-to-corridor navigation**

Enter a corridor → walk toward an outgoing link doorway → step through it → corridor rebuilds with the linked note's content.

- [ ] **Step 3: Commit**

```bash
git add layers/corridor/corridor_layer.gd
git commit -m "feat: add doorway-based link travel in corridor layer"
```

---

### Task 21: Search Beacon & Tag Filter Implementation

**Files:**
- Modify: `autoloads/ui_manager.gd`
- Modify: `layers/graph/graph_layer.gd`
- Modify: `layers/city/city_layer.gd`

- [ ] **Step 1: Implement search beacon in graph layer**

Add to `graph_layer.gd`:

```gdscript
func highlight_notes(note_ids: Array) -> void:
	for note_id in _node_map:
		var node: Node3D = _node_map[note_id]
		if note_id in note_ids:
			# Full brightness
			node.visible = true
			if node.has_node("MeshInstance3D"):
				var mat = node.get_node("MeshInstance3D").get_surface_override_material(0)
				if mat:
					mat.set_shader_parameter("emission_strength", 8.0)
		else:
			# Dim to ghost
			node.visible = true
			if node.has_node("MeshInstance3D"):
				var mat = node.get_node("MeshInstance3D").get_surface_override_material(0)
				if mat:
					mat.set_shader_parameter("emission_strength", 0.1)

func clear_highlights() -> void:
	for note_id in _node_map:
		var node: Node3D = _node_map[note_id]
		node.visible = true
		var conns := VaultDataBus.graph.get_connection_count(note_id)
		var temp := clampf(conns / 25.0, 0.0, 1.0)
		if node.has_node("MeshInstance3D"):
			var mat = node.get_node("MeshInstance3D").get_surface_override_material(0)
			if mat:
				mat.set_shader_parameter("emission_strength", 1.5 + temp * 4.0)
```

- [ ] **Step 2: Wire search overlay to beacon system**

Update `ui_manager.gd` `_on_search_requested`:

```gdscript
func _on_search_requested() -> void:
	# For now, simple input dialog
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
		# Beacon the results in the active layer
		if LayerManager.current_scene and LayerManager.current_scene.has_method("highlight_notes"):
			LayerManager.current_scene.highlight_notes(results)
		search_dialog.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
```

- [ ] **Step 3: Wire tag filter**

Update `ui_manager.gd` `_on_tag_filter_requested` similarly — filter notes by selected tags and call `highlight_notes` on the active layer.

- [ ] **Step 4: Add `highlight_notes` and `clear_highlights` to city_layer.gd**

Same pattern as graph: dim non-matching towers to ghost, brighten matches.

- [ ] **Step 5: Test search and tag filter**

Press `/` → type "devops" → matching notes light up as beacons, everything else dims. Press `T` → select tag → same filtering effect.

- [ ] **Step 6: Commit**

```bash
git add autoloads/ui_manager.gd layers/graph/graph_layer.gd layers/city/city_layer.gd
git commit -m "feat: add search beacon and tag filter systems across graph and city layers"
```

---

## Verification

After completing all tasks:

1. **Full loop test:** Start in city → walk around → hover towers (see previews) → click tower (enter corridor) → read wall text → walk through doorway (link travel) → Space (ascend to city) → Space (ascend to graph) → fly through graph → click node (descend to corridor)
2. **Search test:** Press `/` in any layer → search → matching notes beacon → select → warp to note
3. **Tag test:** Press `T` → select tags → non-matching notes fade → clear → all restore
4. **Hot reload test:** Edit a markdown file in Obsidian while Nexus is running → observe the change reflected within 2 seconds
5. **Performance test:** Monitor FPS via Godot's built-in profiler. Target: 60+ FPS at 1440p with all effects.
