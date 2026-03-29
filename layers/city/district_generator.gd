extends RefCounted
class_name DistrictGenerator

func generate(folder_sizes: Dictionary, total_size: Vector2) -> Array:
	if folder_sizes.is_empty():
		return []

	var items: Array = []
	for folder in folder_sizes:
		items.append({"folder": folder, "size": folder_sizes[folder]})
	items.sort_custom(func(a, b): return a["size"] > b["size"])

	var total := 0.0
	for item in items:
		total += item["size"]

	var total_area := total_size.x * total_size.y
	for item in items:
		item["area"] = (item["size"] / total) * total_area

	var results: Array = []
	_squarify(items, Rect2(Vector2.ZERO, total_size), results)
	return results

func _squarify(items: Array, bounds: Rect2, results: Array) -> void:
	if items.is_empty():
		return

	if items.size() == 1:
		results.append({"folder": items[0]["folder"], "rect": bounds})
		return

	var vertical := bounds.size.x >= bounds.size.y

	var total_area := 0.0
	for item in items:
		total_area += item["area"]

	var accumulated := 0.0
	var split_idx := 0
	var best_ratio := INF

	for i in range(items.size() - 1):
		accumulated += items[i]["area"]
		var fraction := accumulated / total_area
		var ratio: float
		if vertical:
			var w1 := bounds.size.x * fraction
			ratio = maxf(w1 / bounds.size.y, bounds.size.y / w1) if bounds.size.y > 0 else INF
		else:
			var h1 := bounds.size.y * fraction
			ratio = maxf(h1 / bounds.size.x, bounds.size.x / h1) if bounds.size.x > 0 else INF

		if ratio < best_ratio:
			best_ratio = ratio
			split_idx = i

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
