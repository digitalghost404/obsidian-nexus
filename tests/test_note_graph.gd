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
	assert_int(graph.get_connection_count("Note A")).is_equal(3)
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
