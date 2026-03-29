extends GdUnitTestSuite

const HallwayGenerator = preload("res://layers/corridor/hallway_generator.gd")

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
	var long_content := "Word ".repeat(100)
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
