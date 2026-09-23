@tool
extends GraphEdit

## Routes connection lines around GraphNodes instead of through them.
## Jump wires leave the source row to the right before turning.
## See: editor/course_viewer.gd

const _STUB := 28.0
const _AROUND := 32.0
const _HIT_PAD := 6.0


func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var source := _node_rect_at(from_position)
	if source.size.x < 1.0:
		return _bezier_line(from_position, to_position)
	return _around_line(from_position, to_position, source)


func _node_rect_at(point: Vector2) -> Rect2:
	for child in get_children():
		if not (child is GraphNode):
			continue
		var node := child as GraphNode
		var rect := Rect2(node.position_offset, node.size)
		if rect.grow(_HIT_PAD).has_point(point):
			return rect
	return Rect2()


func _blocking_rects(from_position: Vector2, to_position: Vector2, source: Rect2) -> Array[Rect2]:
	var span := Rect2(from_position, to_position - from_position).abs().grow(_HIT_PAD)
	var blockers: Array[Rect2] = []
	if source.size.x >= 1.0:
		blockers.append(source.grow(_HIT_PAD))
	for child in get_children():
		if not (child is GraphNode):
			continue
		var node := child as GraphNode
		var rect := Rect2(node.position_offset, node.size).grow(_HIT_PAD)
		if source.size.x >= 1.0 and rect.intersects(source):
			continue
		if rect.has_point(to_position):
			blockers.append(rect)
			continue
		if span.intersects(rect):
			blockers.append(rect)
	return blockers


func _around_line(from_position: Vector2, to_position: Vector2, source: Rect2) -> PackedVector2Array:
	var blockers := _blocking_rects(from_position, to_position, source)
	var union := source.grow(_HIT_PAD)
	for rect in blockers:
		union = union.merge(rect)
	var target := _node_rect_at(to_position)
	if target.size.x >= 1.0:
		union = union.merge(target.grow(_HIT_PAD))
	var exit_x := maxf(from_position.x + _STUB, source.position.x + source.size.x + _AROUND)
	var enter_x := to_position.x - _STUB
	if target.size.x >= 1.0:
		enter_x = minf(enter_x, target.position.x - _AROUND)
	var has_others := false
	for rect in blockers:
		if rect.has_point(from_position) or rect.has_point(to_position):
			continue
		if source.size.x >= 1.0 and abs(rect.get_center().x - source.get_center().x) < 1.0:
			continue
		has_others = true
		break
	var lane_y := from_position.y
	var needs_detour := has_others or exit_x >= enter_x or to_position.x < from_position.x
	if needs_detour:
		var avg_y := (from_position.y + to_position.y) * 0.5
		lane_y = union.position.y - _AROUND
		if avg_y > union.get_center().y:
			lane_y = union.position.y + union.size.y + _AROUND
	var points := PackedVector2Array()
	points.append(from_position)
	points.append(Vector2(exit_x, from_position.y))
	if not is_equal_approx(lane_y, from_position.y) or not is_equal_approx(lane_y, to_position.y):
		points.append(Vector2(exit_x, lane_y))
		points.append(Vector2(enter_x, lane_y))
	points.append(Vector2(enter_x, to_position.y))
	points.append(to_position)
	return points


func _bezier_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var x_diff := to_position.x - from_position.x
	var cp_offset := x_diff * connection_lines_curvature
	if x_diff < 0.0:
		cp_offset *= -1.0
	var curve := Curve2D.new()
	curve.add_point(from_position)
	curve.set_point_out(0, Vector2(cp_offset, 0.0))
	curve.add_point(to_position)
	curve.set_point_in(1, Vector2(-cp_offset, 0.0))
	if connection_lines_curvature > 0.0:
		return curve.tessellate(5, 2.0)
	return curve.tessellate(1)
