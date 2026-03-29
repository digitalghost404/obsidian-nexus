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
