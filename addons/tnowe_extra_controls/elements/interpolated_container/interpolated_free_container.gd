@tool
class_name InterpolatedFreeContainer
extends InterpolatedContainer

## A container that does not impose positioning rules. The user can freely move children around this control's rect, with a smooth repositioning feature for out-of-bounds drops.
##
## Supports [Draggable] as children to allow resizing. In this case, overrides child [member grid_snap]. [br]
## Unlike a plain [Control] with [Draggable] children, allows transferring children between [InterpolatedContainer]s if relevant properties are set.[br]
## [b]Note:[/b] users can only move/transfer children that have [member Control.mouse_filter] set to Stop. [br]

## Size of the grid to align children with when moved or resized.
@export var grid_snap := Vector2.ZERO
## Color of the rectangle indicating a child's drop position.
@export var drop_color := Color(0.5, 0.5, 0.5, 0.75)
## Overrides preview color of child [Draggable] nodes.
@export var drop_color_override_children := false

@export_group("Seeded Placement")
## Show children in deterministic pseudo-random positions in the editor.
@export var randomize_children_in_editor := true:
	set(value):
		randomize_children_in_editor = value
		if is_inside_tree():
			queue_sort()

## Seed used for deterministic pseudo-random placement.
@export var random_seed := 1:
	set(value):
		random_seed = value
		if is_inside_tree():
			queue_sort()

var _did_initial_runtime_layout := false


func _ready():
	super()

	if !Engine.is_editor_hint():
		_queue_initial_runtime_sort.call_deferred()


func _queue_initial_runtime_sort():
	queue_sort()


func _draw():
	if _dragging_node == null || _dragging_node.get_parent() != self:
		return

	if !(_dragging_node is Draggable):
		var result_rect := get_rect_after_drop(_dragging_node)
		draw_rect(result_rect, drop_color)

	if _affected_by_multi_selection == null:
		return

	for x in _affected_by_multi_selection._selected_nodes:
		if !(x is Draggable):
			var result_rect := get_rect_after_drop(x)
			result_rect.position -= position
			draw_rect(result_rect, drop_color)


func _sort_children():
	var children := get_children(true)

	if Engine.is_editor_hint():
		if randomize_children_in_editor:
			_sort_children_pseudo_randomly(children)
		else:
			_sort_children_freely(children)

		_cache_size_and_queue_redraw()
		return

	if size.x <= 0.0 or size.y <= 0.0:
		_cache_size_and_queue_redraw()
		return

	if !_did_initial_runtime_layout:
		_did_initial_runtime_layout = true

		_sort_children_pseudo_randomly(children)
		_cache_size_and_queue_redraw()
		return

	_sort_children_freely(children)
	_cache_size_and_queue_redraw()


func _cache_size_and_queue_redraw():
	cached_minimum_size = size
	queue_redraw()


func _sort_children_freely(children: Array[Node]):
	for child in children:
		if child is Control and child != _dragging_node:
			fit_interpolated(child, get_rect_after_drop(child))


func _sort_children_pseudo_randomly(children : Array):
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	for child in children:
		if !(child is Control) or child == _dragging_node:
			continue

		var control := child as Control
		var rect := _get_seeded_rect_for_child(control, rng)
		fit_interpolated(control, rect)


func _get_seeded_rect_for_child(control : Control, rng : RandomNumberGenerator) -> Rect2:
	var child_size := control.size

	if child_size.x <= 0.0 or child_size.y <= 0.0:
		child_size = control.get_combined_minimum_size()

	var max_x := maxf(0.0, size.x - child_size.x)
	var max_y := maxf(0.0, size.y - child_size.y)

	var pos := Vector2(
		rng.randf_range(0.0, max_x),
		rng.randf_range(0.0, max_y)
	)

	if grid_snap != Vector2.ZERO:
		pos = pos.snapped(grid_snap)

	return Rect2(pos, child_size)


func get_rect_after_drop(of_node : Control) -> Rect2:
	if of_node is Draggable:
		return of_node.get_rect_after_drop()

	var result_position := of_node.position
	var result_size := of_node.size

	if result_size.x <= 0.0 or result_size.y <= 0.0:
		result_size = of_node.get_combined_minimum_size()

	if grid_snap != Vector2.ZERO:
		result_position = result_position.snapped(grid_snap)

	if size.x <= 0.0 or size.y <= 0.0:
		return Rect2(result_position, result_size)

	var xform_basis := of_node.get_transform().translated(-of_node.position)
	var xformed_rect := (xform_basis * Rect2(Vector2.ZERO, result_size))
	var xformed_position := xformed_rect.position + result_position
	var xformed_child_size := xformed_rect.size
	if xformed_position.x < 0.0:
		result_position -= xform_basis.affine_inverse() * Vector2(xformed_position.x, 0.0)

	if xformed_position.y < 0.0:
		result_position -= xform_basis.affine_inverse() * Vector2(0.0, xformed_position.y)

	if xformed_position.x > size.x - xformed_child_size.x:
		result_position -= xform_basis.affine_inverse() * Vector2(xformed_position.x - (size.x - xformed_child_size.x), 0.0)

	if xformed_position.y > size.y - xformed_child_size.y:
		result_position -= xform_basis.affine_inverse() * Vector2(0.0, xformed_position.y - (size.y - xformed_child_size.y))

	return Rect2(result_position, result_size)


func _input(event : InputEvent):
	if event is InputEventMouse:
		queue_redraw()

	super(event)
