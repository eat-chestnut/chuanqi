extends Node2D

const MODULE_WIDTH := 1024.0
const MODULE_HEIGHT := 512.0
const MODULE_CENTER_Y := MODULE_HEIGHT * 0.5
const ROAD_CORRIDOR_HEIGHT := 200.0
const MODULE_GATE_TOP := 156.0
const MODULE_GATE_BOTTOM := 356.0
const MONSTER_SPAWN_ATTEMPTS := 28

const PLAYER_TEXTURE_PATH := "res://assets/player/player.png"
const MONSTER_DIR_PATH := "res://assets/monsters"
const TREE_TEXTURE_PATH := "res://assets/environment/tree.png"
const ROCK_TEXTURE_PATH := "res://assets/environment/rock.png"

const ENTRY_TREE_COUNT := 6
const FOREST_MONSTER_COUNT := 35
const FOREST_TREE_COUNT := 510
const FOREST_ROCK_COUNT := 8
const ROAD_MONSTER_COUNT := 24
const ROAD_ROCK_COUNT := 32
const NEST_MONSTER_COUNT := 68
const NEST_ROCK_COUNT := 6

var rng = RandomNumberGenerator.new()

@onready var tile_root: Node2D = $TileRoot
@onready var player: CharacterBody2D = $Player
@onready var player_sprite: Sprite2D = $Player/Sprite2D
@onready var monsters_root: Node2D = $Monsters
@onready var obstacles_root: Node2D = $Obstacles

var player_texture: Texture2D
var tree_texture: Texture2D
var rock_texture: Texture2D
var monster_textures: Array[Texture2D] = []


func _ready() -> void:
	rng.randomize()
	load_resources()
	player.z_index = 3
	player_sprite.z_index = 3
	generate_map()


func load_resources() -> void:
	player_texture = load(PLAYER_TEXTURE_PATH) as Texture2D
	tree_texture = load(TREE_TEXTURE_PATH) as Texture2D
	rock_texture = load(ROCK_TEXTURE_PATH) as Texture2D
	monster_textures = load_monster_textures()
	player_sprite.texture = player_texture


func load_monster_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var file_names: Array[String] = []
	var dir := DirAccess.open(MONSTER_DIR_PATH)

	if dir == null:
		push_warning("Cannot open monster directory: %s" % MONSTER_DIR_PATH)
		return textures

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	file_names.sort()
	for name in file_names:
		var texture := load("%s/%s" % [MONSTER_DIR_PATH, name]) as Texture2D
		if texture != null:
			textures.append(texture)

	if textures.is_empty():
		push_warning("No monster textures were found in: %s" % MONSTER_DIR_PATH)

	return textures


func generate_map() -> void:
	clear_children(tile_root)
	clear_children(monsters_root)
	clear_children(obstacles_root)

	var offset_x := 0.0
	create_entry_module(offset_x)
	offset_x += MODULE_WIDTH
	create_forest_module(offset_x)
	offset_x += MODULE_WIDTH
	create_road_module(offset_x)
	offset_x += MODULE_WIDTH
	create_nest_module(offset_x)
	offset_x += MODULE_WIDTH
	create_boss_module(offset_x)


func create_entry_module(offset_x: float) -> void:
	var spawn_points: Array[Vector2] = [Vector2(MODULE_WIDTH * 0.5, MODULE_CENTER_Y)]
	var tree_points: Array[Vector2] = [
		Vector2(164.0, 120.0),
		Vector2(246.0, 394.0),
		Vector2(378.0, 142.0),
		Vector2(620.0, 392.0),
		Vector2(774.0, 134.0),
		Vector2(884.0, 366.0)
	]
	var rock_points: Array[Vector2] = [
		Vector2(286.0, 180.0),
		Vector2(712.0, 326.0),
		Vector2(868.0, 214.0)
	]
	var module_bounds := Rect2(Vector2(84.0, 78.0), Vector2(MODULE_WIDTH - 168.0, MODULE_HEIGHT - 156.0))

	add_module_floor(offset_x, Color(0.47, 0.72, 0.45), Color(0.22, 0.41, 0.21))
	add_circle_fill(to_world_pos(offset_x, spawn_points[0]), 88.0, Color(0.74, 0.84, 0.58, 0.45), -16)
	decorate_module_boundaries(offset_x, "entry", false, true)

	for index in range(ENTRY_TREE_COUNT):
		place_tree_local(offset_x, jitter_local_point(tree_points[index % tree_points.size()], Vector2(24.0, 20.0), module_bounds))

	for rock_point in rock_points:
		place_rock_local(offset_x, jitter_local_point(rock_point, Vector2(18.0, 16.0), module_bounds))

	player.position = to_world_pos(offset_x, spawn_points[0])


func create_forest_module(offset_x: float) -> void:
	var variant := rng.randi_range(0, 1)
	var spawn_points: Array[Vector2] = []
	var tree_points: Array[Vector2] = []
	var rock_points: Array[Vector2] = []
	var fill_color := Color(0.18, 0.39, 0.20) if variant == 0 else Color(0.14, 0.34, 0.18)
	var border_color := Color(0.08, 0.23, 0.10) if variant == 0 else Color(0.07, 0.19, 0.10)
	var tree_bounds := Rect2(Vector2(74.0, 58.0), Vector2(MODULE_WIDTH - 148.0, MODULE_HEIGHT - 116.0))
	var monster_bounds := Rect2(Vector2(112.0, 118.0), Vector2(MODULE_WIDTH - 224.0, MODULE_HEIGHT - 236.0))

	if variant == 0:
		spawn_points = [
			Vector2(158.0, 174.0),
			Vector2(262.0, 308.0),
			Vector2(384.0, 212.0),
			Vector2(506.0, 336.0),
			Vector2(626.0, 184.0),
			Vector2(748.0, 292.0),
			Vector2(868.0, 204.0),
			Vector2(922.0, 332.0)
		]
		tree_points = [
			Vector2(112.0, 92.0),
			Vector2(244.0, 132.0),
			Vector2(394.0, 106.0),
			Vector2(550.0, 140.0),
			Vector2(724.0, 96.0),
			Vector2(888.0, 148.0),
			Vector2(170.0, 404.0),
			Vector2(324.0, 372.0),
			Vector2(492.0, 426.0),
			Vector2(664.0, 382.0),
			Vector2(844.0, 418.0)
		]
		rock_points = [
			Vector2(136.0, 236.0),
			Vector2(248.0, 404.0),
			Vector2(438.0, 168.0),
			Vector2(612.0, 360.0),
			Vector2(806.0, 210.0),
			Vector2(916.0, 318.0)
		]
	else:
		spawn_points = [
			Vector2(142.0, 302.0),
			Vector2(248.0, 180.0),
			Vector2(366.0, 328.0),
			Vector2(486.0, 218.0),
			Vector2(628.0, 348.0),
			Vector2(748.0, 188.0),
			Vector2(864.0, 286.0),
			Vector2(930.0, 156.0)
		]
		tree_points = [
			Vector2(126.0, 126.0),
			Vector2(294.0, 98.0),
			Vector2(452.0, 136.0),
			Vector2(626.0, 104.0),
			Vector2(816.0, 132.0),
			Vector2(938.0, 112.0),
			Vector2(158.0, 392.0),
			Vector2(288.0, 430.0),
			Vector2(470.0, 374.0),
			Vector2(672.0, 420.0),
			Vector2(862.0, 384.0)
		]
		rock_points = [
			Vector2(118.0, 192.0),
			Vector2(276.0, 352.0),
			Vector2(458.0, 194.0),
			Vector2(598.0, 384.0),
			Vector2(786.0, 202.0),
			Vector2(924.0, 274.0)
		]

	add_module_floor(offset_x, fill_color, border_color)
	decorate_module_boundaries(offset_x, "forest", true, true)

	for _i in range(FOREST_TREE_COUNT):
		place_tree_local(offset_x, sample_point_from_points(tree_points, Vector2(58.0, 42.0), tree_bounds))

	for _i in range(FOREST_ROCK_COUNT):
		place_rock_local(offset_x, sample_point_from_points(rock_points, Vector2(36.0, 28.0), tree_bounds))

	spawn_monsters_from_points(offset_x, spawn_points, FOREST_MONSTER_COUNT, monster_bounds, Vector2(72.0, 54.0), "normal", 34.0)


func create_road_module(offset_x: float) -> void:
	var variant := rng.randi_range(0, 1)
	var spawn_points: Array[Vector2] = []
	var corridor_top := MODULE_CENTER_Y - ROAD_CORRIDOR_HEIGHT * 0.5
	var corridor_bottom := MODULE_CENTER_Y + ROAD_CORRIDOR_HEIGHT * 0.5
	var monster_bounds := Rect2(Vector2(100.0, corridor_top + 18.0), Vector2(MODULE_WIDTH - 200.0, ROAD_CORRIDOR_HEIGHT - 36.0))

	if variant == 0:
		spawn_points = [
			Vector2(144.0, 220.0),
			Vector2(262.0, 286.0),
			Vector2(384.0, 232.0),
			Vector2(516.0, 284.0),
			Vector2(646.0, 236.0),
			Vector2(782.0, 284.0),
			Vector2(910.0, 252.0)
		]
	else:
		spawn_points = [
			Vector2(140.0, 256.0),
			Vector2(266.0, 216.0),
			Vector2(392.0, 276.0),
			Vector2(520.0, 228.0),
			Vector2(648.0, 286.0),
			Vector2(786.0, 226.0),
			Vector2(912.0, 256.0)
		]

	add_module_floor(offset_x, Color(0.44, 0.38, 0.28), Color(0.24, 0.18, 0.10))
	add_corridor_strip(offset_x, corridor_top, corridor_bottom, Color(0.62, 0.55, 0.38, 0.72))
	decorate_module_boundaries(offset_x, "road", true, true)
	create_road_side_walls(offset_x, corridor_top, corridor_bottom, variant)
	spawn_monsters_from_points(offset_x, spawn_points, ROAD_MONSTER_COUNT, monster_bounds, Vector2(54.0, 22.0), "normal", 38.0)


func create_nest_module(offset_x: float) -> void:
	var variant := rng.randi_range(0, 1)
	var spawn_points: Array[Vector2] = []
	var center_local := Vector2(MODULE_WIDTH * 0.5, MODULE_CENTER_Y)
	var center := to_world_pos(offset_x, center_local)
	var nest_radius := 136.0 if variant == 0 else 158.0
	var monster_bounds := Rect2(Vector2(188.0, 112.0), Vector2(MODULE_WIDTH - 376.0, MODULE_HEIGHT - 224.0))

	if variant == 0:
		spawn_points = [
			Vector2(428.0, 218.0),
			Vector2(510.0, 184.0),
			Vector2(588.0, 220.0),
			Vector2(448.0, 284.0),
			Vector2(520.0, 254.0),
			Vector2(592.0, 294.0),
			Vector2(522.0, 334.0)
		]
	else:
		spawn_points = [
			Vector2(454.0, 206.0),
			Vector2(522.0, 182.0),
			Vector2(594.0, 208.0),
			Vector2(434.0, 266.0),
			Vector2(522.0, 252.0),
			Vector2(606.0, 270.0),
			Vector2(470.0, 324.0),
			Vector2(556.0, 324.0)
		]

	add_module_floor(offset_x, Color(0.26, 0.22, 0.17), Color(0.12, 0.09, 0.06))
	add_circle_fill(center, nest_radius, Color(0.41, 0.23, 0.16, 0.78), -15)
	add_circle_outline(center, nest_radius + 18.0, Color(0.67, 0.42, 0.22, 0.95), 6.0, -14)
	decorate_module_boundaries(offset_x, "nest", true, true)

	for index in range(NEST_ROCK_COUNT):
		var angle := TAU * float(index) / float(NEST_ROCK_COUNT) + rng.randf_range(-0.24, 0.24)
		var distance := nest_radius + rng.randf_range(52.0, 92.0)
		place_rock_local(offset_x, center_local + Vector2.RIGHT.rotated(angle) * distance)

	spawn_monsters_from_points(offset_x, spawn_points, NEST_MONSTER_COUNT, monster_bounds, Vector2(48.0, 36.0), "normal", 24.0)
	spawn_monster(jitter_local_point(center_local, Vector2(26.0, 18.0), monster_bounds), "elite", offset_x)


func create_boss_module(offset_x: float) -> void:
	var spawn_points: Array[Vector2] = [Vector2(MODULE_WIDTH * 0.5, MODULE_CENTER_Y)]
	var center := to_world_pos(offset_x, spawn_points[0])

	add_module_floor(offset_x, Color(0.20, 0.15, 0.15), Color(0.33, 0.12, 0.12))
	add_circle_fill(center, 176.0, Color(0.36, 0.11, 0.11, 0.82), -15)
	add_circle_outline(center, 198.0, Color(0.85, 0.54, 0.24, 0.95), 7.0, -14)
	decorate_module_boundaries(offset_x, "boss", true, false)

	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var local_pos := spawn_points[0] + Vector2.RIGHT.rotated(angle) * rng.randf_range(212.0, 246.0)
		place_rock_local(offset_x, clamp_local_point(local_pos, Rect2(Vector2(86.0, 72.0), Vector2(MODULE_WIDTH - 172.0, MODULE_HEIGHT - 144.0))))

	spawn_monster(spawn_points[0], "boss", offset_x)


func spawn_monster(pos: Vector2, type: String = "normal", offset_x: float = 0.0) -> Sprite2D:
	var monster := Sprite2D.new()
	var texture: Texture2D = player_texture

	if not monster_textures.is_empty():
		texture = monster_textures[rng.randi_range(0, monster_textures.size() - 1)]

	monster.texture = texture
	monster.position = to_world_pos(offset_x, pos)
	monster.centered = true
	monster.z_index = 2
	monster.name = "%sMonster_%d" % [type.capitalize(), monsters_root.get_child_count()]
	monster.set_meta("monster_type", type)
	monster.set_meta("local_position", pos)
	monster.set_meta("module_offset_x", offset_x)

	match type:
		"elite":
			monster.scale = Vector2.ONE * 1.5
			monster.modulate = Color(1.0, 0.92, 0.70)
		"boss":
			monster.scale = Vector2.ONE * 2.0
			monster.modulate = Color(1.0, 0.82, 0.82)
		_:
			monster.scale = Vector2.ONE
			monster.modulate = Color.WHITE

	monsters_root.add_child(monster)
	return monster


func place_tree(pos: Vector2) -> Sprite2D:
	var tree := Sprite2D.new()
	tree.texture = tree_texture
	tree.position = pos
	tree.scale = Vector2.ONE * rng.randf_range(0.35, 0.65)
	tree.rotation = deg_to_rad(rng.randf_range(-5.0, 5.0))
	tree.z_index = 1
	obstacles_root.add_child(tree)
	return tree


func place_rock(pos: Vector2) -> Sprite2D:
	var rock := Sprite2D.new()
	rock.texture = rock_texture
	rock.position = pos
	rock.scale = Vector2.ONE * rng.randf_range(0.55, 0.95)
	rock.rotation = deg_to_rad(rng.randf_range(-18.0, 18.0))
	rock.z_index = 1
	obstacles_root.add_child(rock)
	return rock


func clear_children(root: Node) -> void:
	for child in root.get_children():
		child.queue_free()


func spawn_monsters_from_points(offset_x: float, spawn_points: Array[Vector2], count: int, bounds: Rect2, spread: Vector2, type: String = "normal", min_distance: float = 28.0) -> void:
	var used_positions: Array[Vector2] = []

	for _i in range(count):
		var local_pos := sample_spawn_position(spawn_points, used_positions, bounds, spread, min_distance)
		used_positions.append(local_pos)
		spawn_monster(local_pos, type, offset_x)


func sample_spawn_position(spawn_points: Array[Vector2], used_positions: Array[Vector2], bounds: Rect2, spread: Vector2, min_distance: float) -> Vector2:
	if spawn_points.is_empty():
		return rect_center(bounds)

	var best_candidate := clamp_local_point(spawn_points[0], bounds)
	var best_distance := -1.0

	for _attempt in range(MONSTER_SPAWN_ATTEMPTS):
		var candidate := sample_point_from_points(spawn_points, spread, bounds)
		var nearest_distance := get_nearest_distance(candidate, used_positions)

		if nearest_distance > best_distance:
			best_distance = nearest_distance
			best_candidate = candidate

		if nearest_distance >= min_distance:
			return candidate

	return best_candidate


func get_nearest_distance(local_pos: Vector2, used_positions: Array[Vector2]) -> float:
	if used_positions.is_empty():
		return 999999.0

	var nearest := 999999.0
	for used_pos in used_positions:
		nearest = min(nearest, local_pos.distance_to(used_pos))

	return nearest


func decorate_module_boundaries(offset_x: float, theme: String, left_has_opening: bool, right_has_opening: bool) -> void:
	place_horizontal_boundary(offset_x, 28.0, theme)
	place_horizontal_boundary(offset_x, MODULE_HEIGHT - 28.0, theme)
	place_vertical_boundary(offset_x, 22.0, theme, left_has_opening)
	place_vertical_boundary(offset_x, MODULE_WIDTH - 22.0, theme, right_has_opening)


func place_horizontal_boundary(offset_x: float, y_local: float, theme: String) -> void:
	var x_local := 42.0
	while x_local <= MODULE_WIDTH - 42.0:
		var local_pos := Vector2(x_local + rng.randf_range(-8.0, 8.0), y_local + rng.randf_range(-6.0, 6.0))
		place_boundary_obstacle(offset_x, local_pos, theme)
		x_local += 56.0 + rng.randf_range(-4.0, 5.0)


func place_vertical_boundary(offset_x: float, x_local: float, theme: String, has_opening: bool) -> void:
	var y_local := 34.0
	while y_local <= MODULE_HEIGHT - 34.0:
		if has_opening and y_local >= MODULE_GATE_TOP and y_local <= MODULE_GATE_BOTTOM:
			y_local = MODULE_GATE_BOTTOM + 34.0
			continue

		var local_pos := Vector2(x_local + rng.randf_range(-6.0, 6.0), y_local + rng.randf_range(-8.0, 8.0))
		place_boundary_obstacle(offset_x, local_pos, theme)
		y_local += 50.0 + rng.randf_range(-4.0, 4.0)


func place_boundary_obstacle(offset_x: float, local_pos: Vector2, theme: String) -> void:
	var roll := rng.randf()

	match theme:
		"forest":
			if roll < 0.72:
				place_tree_local(offset_x, local_pos)
			else:
				place_rock_local(offset_x, local_pos)
		"road":
			if roll < 0.88:
				place_rock_local(offset_x, local_pos)
			else:
				place_tree_local(offset_x, local_pos)
		"nest", "boss":
			if roll < 0.92:
				place_rock_local(offset_x, local_pos)
			else:
				place_tree_local(offset_x, local_pos)
		_:
			if roll < 0.68:
				place_tree_local(offset_x, local_pos)
			else:
				place_rock_local(offset_x, local_pos)


func create_road_side_walls(offset_x: float, corridor_top: float, corridor_bottom: float, variant: int) -> void:
	for index in range(ROAD_ROCK_COUNT):
		var lane_index := index % 16
		var x_local := 88.0 + float(lane_index) * 56.0 + rng.randf_range(-8.0, 8.0)
		var top_side := index < 16
		var y_offset := rng.randf_range(22.0, 44.0)
		var y_local := corridor_top - y_offset if top_side else corridor_bottom + y_offset

		if variant == 1 and lane_index % 3 == 0:
			y_local += -14.0 if top_side else 14.0

		place_rock_local(offset_x, Vector2(x_local, y_local))


func to_world_pos(offset_x: float, local_pos: Vector2) -> Vector2:
	return Vector2(offset_x + local_pos.x, local_pos.y)


func place_tree_local(offset_x: float, local_pos: Vector2) -> Sprite2D:
	return place_tree(to_world_pos(offset_x, local_pos))


func place_rock_local(offset_x: float, local_pos: Vector2) -> Sprite2D:
	return place_rock(to_world_pos(offset_x, local_pos))


func sample_point_from_points(points: Array[Vector2], spread: Vector2, bounds: Rect2) -> Vector2:
	if points.is_empty():
		return rect_center(bounds)

	var anchor := points[rng.randi_range(0, points.size() - 1)]
	return jitter_local_point(anchor, spread, bounds)


func jitter_local_point(anchor: Vector2, spread: Vector2, bounds: Rect2) -> Vector2:
	var local_pos := anchor + Vector2(
		rng.randf_range(-spread.x, spread.x),
		rng.randf_range(-spread.y, spread.y)
	)
	return clamp_local_point(local_pos, bounds)


func clamp_local_point(local_pos: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf(local_pos.x, bounds.position.x, bounds.position.x + bounds.size.x),
		clampf(local_pos.y, bounds.position.y, bounds.position.y + bounds.size.y)
	)


func rect_center(bounds: Rect2) -> Vector2:
	return Vector2(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y + bounds.size.y * 0.5
	)


func add_module_floor(offset_x: float, fill_color: Color, border_color: Color) -> void:
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([
		Vector2(offset_x, 0.0),
		Vector2(offset_x + MODULE_WIDTH, 0.0),
		Vector2(offset_x + MODULE_WIDTH, MODULE_HEIGHT),
		Vector2(offset_x, MODULE_HEIGHT)
	])
	floor.color = fill_color
	floor.z_index = -20
	tile_root.add_child(floor)

	var border := Line2D.new()
	border.points = PackedVector2Array([
		Vector2(offset_x, 0.0),
		Vector2(offset_x + MODULE_WIDTH, 0.0),
		Vector2(offset_x + MODULE_WIDTH, MODULE_HEIGHT),
		Vector2(offset_x, MODULE_HEIGHT)
	])
	border.closed = true
	border.width = 6.0
	border.default_color = border_color
	border.z_index = -19
	tile_root.add_child(border)


func add_corridor_strip(offset_x: float, top_y: float, bottom_y: float, color: Color) -> void:
	var corridor := Polygon2D.new()
	corridor.polygon = PackedVector2Array([
		Vector2(offset_x, top_y),
		Vector2(offset_x + MODULE_WIDTH, top_y),
		Vector2(offset_x + MODULE_WIDTH, bottom_y),
		Vector2(offset_x, bottom_y)
	])
	corridor.color = color
	corridor.z_index = -18
	tile_root.add_child(corridor)


func add_circle_fill(center: Vector2, radius: float, color: Color, z_index: int = -15) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = build_circle_points(center, radius)
	polygon.color = color
	polygon.z_index = z_index
	tile_root.add_child(polygon)


func add_circle_outline(center: Vector2, radius: float, color: Color, width: float, z_index: int = -14) -> void:
	var outline := Line2D.new()
	outline.points = build_circle_points(center, radius)
	outline.closed = true
	outline.width = width
	outline.default_color = color
	outline.z_index = z_index
	tile_root.add_child(outline)


func build_circle_points(center: Vector2, radius: float, segments: int = 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	return points
