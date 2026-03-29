extends RefCounted
class_name HallwayGenerator

const PANEL_CHARS := 500
const SEGMENT_LENGTH := 8.0
const HALLWAY_WIDTH := 4.0
const HALLWAY_HEIGHT := 3.5

func compute_layout(note_data: Dictionary) -> Dictionary:
	var content: String = note_data.get("content", "")
	var outgoing: Array = note_data.get("outgoing_links", [])
	var backlinks: Array = note_data.get("backlinks", [])
	var tags: Array = note_data.get("tags", [])

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

	if wall_panels.is_empty():
		wall_panels.append({
			"text": note_data.get("title", "Empty note"),
			"side": "left",
			"position_z": 0.0,
			"index": 0,
		})

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

	var doorways: Array = []
	for i in range(outgoing.size()):
		var side_offset := (i - outgoing.size() / 2.0) * 3.0
		doorways.append({
			"target": outgoing[i],
			"position_z": total_length,
			"position_x": side_offset,
			"is_outgoing": true,
		})

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
