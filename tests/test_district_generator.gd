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
	assert_float(total_area).is_equal_approx(10000.0, 100.0)

func test_districts_do_not_overlap() -> void:
	var folders := {"a": 10, "b": 20, "c": 15, "d": 5}
	var districts := generator.generate(folders, Vector2(100, 100))
	for i in range(districts.size()):
		for j in range(i + 1, districts.size()):
			var r1: Rect2 = districts[i]["rect"]
			var r2: Rect2 = districts[j]["rect"]
			assert_bool(r1.intersects(r2)).is_false()
