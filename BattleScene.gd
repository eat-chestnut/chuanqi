extends Node2D

const MODULE_WIDTH := 720.0
const MODULE_HEIGHT := 640.0
const MODULE_GATE_WIDTH := 180.0
const MODULE_GATE_LEFT := MODULE_WIDTH * 0.5 - MODULE_GATE_WIDTH * 0.5
const MODULE_GATE_RIGHT := MODULE_WIDTH * 0.5 + MODULE_GATE_WIDTH * 0.5
const ROAD_CORRIDOR_WIDTH := 180.0
const MONSTER_SPAWN_ATTEMPTS := 18

const PLAYER_SPEED := 340.0
const PLAYER_MARGIN := Vector2(30.0, 30.0)
const MONSTER_MARGIN := Vector2(24.0, 24.0)
const MONSTER_HOME_EPSILON := 8.0

const PLAYER_TEXTURE_PATH := "res://assets/player/player.png"
const MONSTER_DIR_PATH := "res://assets/monsters"
const TREE_TEXTURE_PATH := "res://assets/environment/tree.png"
const ROCK_TEXTURE_PATH := "res://assets/environment/rock.png"

const ENTRY_TREE_COUNT := 6
const FOREST_MONSTER_COUNT := 10
const FOREST_TREE_COUNT := 42
const FOREST_ROCK_COUNT := 8
const ROAD_MONSTER_COUNT := 8
const ROAD_ROCK_COUNT := 12
const NEST_MONSTER_COUNT := 12
const NEST_ROCK_COUNT := 8

var rng := RandomNumberGenerator.new()
var total_map_height := 0.0
var world_bounds := Rect2(Vector2.ZERO, Vector2(MODULE_WIDTH * 2.0, MODULE_HEIGHT))

@onready var tile_root: Node2D = $TileRoot
@onready var player: CharacterBody2D = $Player
@onready var player_sprite: Sprite2D = $Player/Sprite2D
@onready var camera: Camera2D = $Player/Camera2D
@onready var monsters_root: Node2D = $Monsters
@onready var obstacles_root: Node2D = $Obstacles

var player_texture: Texture2D
var tree_texture: Texture2D
var rock_texture: Texture2D
var monster_textures: Array[Texture2D] = []


func _ready() -> void:
	rng.randomize()
	ensure_input_actions()
	load_resources()
	configure_scene()
	generate_map()


func _physics_process(delta: float) -> void:
	update_player_movement()
	update_monsters(delta)


func ensure_input_actions() -> void:
	register_action("move_left", [KEY_A, KEY_LEFT])
	register_action("move_right", [KEY_D, KEY_RIGHT])
	register_action("move_up", [KEY_W, KEY_UP])
	register_action("move_down", [KEY_S, KEY_DOWN])


func register_action(action_name: String, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var existing_events := InputMap.action_get_events(action_name)
	for keycode in keycodes:
		var already_registered := false
		for event in existing_events:
			var key_event := event as InputEventKey
			if key_event != null and key_event.physical_keycode == keycode:
				already_registered = true
				break

		if already_registered:
			continue

		var input_event := InputEventKey.new()
		input_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, input_event)


func load_resources() -> void:
	player_texture = load(PLAYER_TEXTURE_PATH) as Texture2D
	tree_texture = load(TREE_TEXTURE_PATH) as Texture2D
	rock_texture = load(ROCK_TEXTURE_PATH) as Texture2D
	monster_textures = load_monster_textures()

	if player_texture != null:
		player_sprite.texture = player_texture


func configure_scene() -> void:
	player.z_index = 20
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	player.collision_layer = 1
	player.collision_mask = 1
	player_sprite.z_index = 20
	player_sprite.scale = Vector2.ONE * 1.6
	player_sprite.centered = true
	ensure_player_collision()


func ensure_player_collision() -> void:
	var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		player.add_child(collision)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(28.0, 34.0)
	collision.position = Vector2(0.0, 4.0)
	collision.shape = shape


func configure_camera() -> void:
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_smoothed = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world_bounds.size.x)
	camera.limit_bottom = int(world_bounds.size.y)
	camera.make_current()


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

	var module_rows := [
		PackedStringArray(["entry", "forest"]),
		PackedStringArray(["road", "forest"]),
		PackedStringArray(["nest", "road"]),
		PackedStringArray(["forest", "nest"]),
		PackedStringArray(["road", "boss"])
	]
	var offset_y := 0.0

	for module_row in module_rows:
		var left_x := 0.0
		var right_x := MODULE_WIDTH
		create_module_by_type(module_row[0], offset_y, left_x)
		create_module_by_type(module_row[1], offset_y, right_x)
		offset_y += MODULE_HEIGHT

	total_map_height = offset_y
	world_bounds = Rect2(Vector2.ZERO, Vector2(MODULE_WIDTH * 2.0, total_map_height))
	player.position = clamp_to_world(player.position, PLAYER_MARGIN)
	configure_camera()


func create_module_by_type(module_type: String, offset_y: float, offset_x: float) -> void:
	match module_type:
		"entry":
			create_entry_module(offset_y, offset_x)
		"forest":
			create_forest_module(offset_y, offset_x)
		"road":
			create_road_module(offset_y, offset_x)
		"nest":
			create_nest_module(offset_y, offset_x)
		"boss":
			create_boss_module(offset_y, offset_x)
		_:
			push_warning("Unknown module type: %s" % module_type)


func create_entry_module(offset_y: float, offset_x: float) -> void:
	var spawn_point := ratio_pos(0.5, 0.18)
	var tree_points: Array[Vector2] = [
		ratio_pos(0.18, 0.14),
		ratio_pos(0.32, 0.24),
		ratio_pos(0.74, 0.16),
		ratio_pos(0.82, 0.28),
		ratio_pos(0.24, 0.66),
		ratio_pos(0.76, 0.72)
	]
	var rock_points: Array[Vector2] = [
		ratio_pos(0.2, 0.42),
		ratio_pos(0.78, 0.46),
		ratio_pos(0.52, 0.76)
	]
	var module_bounds := Rect2(Vector2(56.0, 54.0), Vector2(MODULE_WIDTH - 112.0, MODULE_HEIGHT - 108.0))

	add_module_floor(offset_y, offset_x, Color(0.46, 0.71, 0.44), Color(0.19, 0.38, 0.19))
	add_circle_fill(to_world_pos(offset_y, offset_x, ratio_pos(0.5, 0.24)), 84.0, Color(0.82, 0.91, 0.66, 0.48), -16)
	decorate_module_boundaries(offset_y, offset_x, "entry", false, true)

	for index in range(ENTRY_TREE_COUNT):
		place_tree_local(offset_y, offset_x, jitter_local_point(tree_points[index % tree_points.size()], Vector2(22.0, 24.0), module_bounds))

	for rock_point in rock_points:
		place_rock_local(offset_y, offset_x, jitter_local_point(rock_point, Vector2(18.0, 18.0), module_bounds))

	if offset_x == 0.0:
		player.position = to_world_pos(offset_y, offset_x, spawn_point)


func create_forest_module(offset_y: float, offset_x: float) -> void:
	var variant := rng.randi_range(0, 1)
	var spawn_points: Array[Vector2] = []
	var tree_points: Array[Vector2] = []
	var rock_points: Array[Vector2] = []
	var fill_color := Color(0.17, 0.39, 0.2)
	var border_color := Color(0.07, 0.2, 0.09)
	var tree_bounds := Rect2(Vector2(44.0, 44.0), Vector2(MODULE_WIDTH - 88.0, MODULE_HEIGHT - 88.0))
	var monster_bounds := Rect2(Vector2(84.0, 88.0), Vector2(MODULE_WIDTH - 168.0, MODULE_HEIGHT - 176.0))

	if variant == 0:
		spawn_points = [
			ratio_pos(0.24, 0.2),
			ratio_pos(0.68, 0.24),
			ratio_pos(0.34, 0.36),
			ratio_pos(0.74, 0.42),
			ratio_pos(0.24, 0.58),
			ratio_pos(0.56, 0.62),
			ratio_pos(0.42, 0.78),
			ratio_pos(0.72, 0.82)
		]
		tree_points = [
			ratio_pos(0.12, 0.14),
			ratio_pos(0.82, 0.14),
			ratio_pos(0.18, 0.28),
			ratio_pos(0.74, 0.32),
			ratio_pos(0.16, 0.52),
			ratio_pos(0.84, 0.56),
			ratio_pos(0.22, 0.76),
			ratio_pos(0.78, 0.8),
			ratio_pos(0.48, 0.44)
		]
		rock_points = [
			ratio_pos(0.28, 0.22),
			ratio_pos(0.64, 0.3),
			ratio_pos(0.24, 0.64),
			ratio_pos(0.72, 0.68)
		]
	else:
		fill_color = Color(0.14, 0.34, 0.18)
		border_color = Color(0.05, 0.17, 0.08)
		spawn_points = [
			ratio_pos(0.3, 0.18),
			ratio_pos(0.62, 0.24),
			ratio_pos(0.24, 0.38),
			ratio_pos(0.68, 0.46),
			ratio_pos(0.38, 0.56),
			ratio_pos(0.76, 0.62),
			ratio_pos(0.3, 0.74),
			ratio_pos(0.64, 0.84)
		]
		tree_points = [
			ratio_pos(0.16, 0.14),
			ratio_pos(0.76, 0.16),
			ratio_pos(0.12, 0.32),
			ratio_pos(0.84, 0.34),
			ratio_pos(0.18, 0.54),
			ratio_pos(0.78, 0.58),
			ratio_pos(0.24, 0.78),
			ratio_pos(0.7, 0.8),
			ratio_pos(0.52, 0.24)
		]
		rock_points = [
			ratio_pos(0.34, 0.2),
			ratio_pos(0.6, 0.36),
			ratio_pos(0.24, 0.48),
			ratio_pos(0.68, 0.66)
		]

	add_module_floor(offset_y, offset_x, fill_color, border_color)
	decorate_module_boundaries(offset_y, offset_x, "forest", true, true)

	for _i in range(FOREST_TREE_COUNT):
		place_tree_local(offset_y, offset_x, sample_point_from_points(tree_points, Vector2(52.0, 44.0), tree_bounds))

	for _i in range(FOREST_ROCK_COUNT):
		place_rock_local(offset_y, offset_x, sample_point_from_points(rock_points, Vector2(22.0, 22.0), tree_bounds))

	spawn_monsters_from_points(offset_y, offset_x, spawn_points, FOREST_MONSTER_COUNT, monster_bounds, Vector2(50.0, 44.0), "normal", 46.0)


func create_road_module(offset_y: float, offset_x: float) -> void:
	var corridor_left := MODULE_WIDTH * 0.5 - ROAD_CORRIDOR_WIDTH * 0.5
	var corridor_right := MODULE_WIDTH * 0.5 + ROAD_CORRIDOR_WIDTH * 0.5
	var spawn_points: Array[Vector2] = [
		Vector2(MODULE_WIDTH * 0.5, MODULE_HEIGHT * 0.16),
		Vector2(MODULE_WIDTH * 0.46, MODULE_HEIGHT * 0.3),
		Vector2(MODULE_WIDTH * 0.54, MODULE_HEIGHT * 0.44),
		Vector2(MODULE_WIDTH * 0.48, MODULE_HEIGHT * 0.58),
		Vector2(MODULE_WIDTH * 0.52, MODULE_HEIGHT * 0.72),
		Vector2(MODULE_WIDTH * 0.5, MODULE_HEIGHT * 0.84)
	]
	var monster_bounds := Rect2(Vector2(corridor_left + 18.0, 74.0), Vector2(ROAD_CORRIDOR_WIDTH - 36.0, MODULE_HEIGHT - 148.0))

	add_module_floor(offset_y, offset_x, Color(0.39, 0.33, 0.24), Color(0.19, 0.15, 0.09))
	add_vertical_corridor_strip(offset_y, offset_x, corridor_left, corridor_right, Color(0.64, 0.56, 0.38, 0.72))
	decorate_module_boundaries(offset_y, offset_x, "road", true, true)
	create_road_side_walls(offset_y, offset_x, corridor_left, corridor_right)
	spawn_monsters_from_points(offset_y, offset_x, spawn_points, ROAD_MONSTER_COUNT, monster_bounds, Vector2(20.0, 36.0), "normal", 52.0)


func create_nest_module(offset_y: float, offset_x: float) -> void:
	var center_local := ratio_pos(0.5, 0.52)
	var center := to_world_pos(offset_y, offset_x, center_local)
	var spawn_points: Array[Vector2] = [
		ratio_pos(0.42, 0.34),
		ratio_pos(0.58, 0.34),
		ratio_pos(0.32, 0.46),
		ratio_pos(0.68, 0.46),
		ratio_pos(0.32, 0.62),
		ratio_pos(0.68, 0.62),
		ratio_pos(0.44, 0.76),
		ratio_pos(0.56, 0.76)
	]
	var monster_bounds := Rect2(Vector2(146.0, 116.0), Vector2(MODULE_WIDTH - 292.0, MODULE_HEIGHT - 232.0))

	add_module_floor(offset_y, offset_x, Color(0.25, 0.21, 0.17), Color(0.11, 0.08, 0.05))
	add_circle_fill(center, 104.0, Color(0.43, 0.24, 0.16, 0.8), -15)
	add_circle_outline(center, 126.0, Color(0.69, 0.42, 0.24, 0.96), 6.0, -14)
	decorate_module_boundaries(offset_y, offset_x, "nest", true, true)

	for index in range(NEST_ROCK_COUNT):
		var angle := TAU * float(index) / float(NEST_ROCK_COUNT) + rng.randf_range(-0.18, 0.18)
		var distance := 156.0 + rng.randf_range(-12.0, 24.0)
		var rock_pos := center_local + Vector2.RIGHT.rotated(angle) * distance
		place_rock_local(offset_y, offset_x, clamp_local_point(rock_pos, Rect2(Vector2(74.0, 74.0), Vector2(MODULE_WIDTH - 148.0, MODULE_HEIGHT - 148.0))))

	spawn_monsters_from_points(offset_y, offset_x, spawn_points, NEST_MONSTER_COUNT, monster_bounds, Vector2(28.0, 28.0), "normal", 32.0)
	spawn_monster(jitter_local_point(center_local, Vector2(18.0, 18.0), monster_bounds), "elite", offset_y, offset_x)


func create_boss_module(offset_y: float, offset_x: float) -> void:
	var spawn_point := ratio_pos(0.5, 0.52)
	var center := to_world_pos(offset_y, offset_x, spawn_point)

	add_module_floor(offset_y, offset_x, Color(0.18, 0.13, 0.14), Color(0.3, 0.1, 0.11))
	add_circle_fill(center, 142.0, Color(0.38, 0.11, 0.12, 0.82), -15)
	add_circle_outline(center, 162.0, Color(0.87, 0.53, 0.24, 0.96), 7.0, -14)
	decorate_module_boundaries(offset_y, offset_x, "boss", true, false)

	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var local_pos := spawn_point + Vector2.RIGHT.rotated(angle) * rng.randf_range(166.0, 194.0)
		place_rock_local(offset_y, offset_x, clamp_local_point(local_pos, Rect2(Vector2(80.0, 80.0), Vector2(MODULE_WIDTH - 160.0, MODULE_HEIGHT - 160.0))))

	spawn_monster(spawn_point, "boss", offset_y, offset_x)


func update_player_movement() -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.velocity = input_direction * PLAYER_SPEED
	player.move_and_slide()
	player.position = clamp_to_world(player.position, PLAYER_MARGIN)

	if absf(input_direction.x) > 0.05:
		player_sprite.flip_h = input_direction.x < 0.0


func update_monsters(delta: float) -> void:
	for child in monsters_root.get_children():
		var monster := child as Sprite2D
		if monster == null:
			continue

		var home_position: Vector2 = monster.get_meta("home_position", monster.position)
		var speed: float = monster.get_meta("speed", 110.0)
		var return_speed: float = monster.get_meta("return_speed", speed * 0.6)
		var detection_radius: float = monster.get_meta("detection_radius", 240.0)
		var attack_range: float = monster.get_meta("attack_range", 22.0)
		var leash_distance: float = monster.get_meta("leash_distance", 420.0)
		var to_player := player.position - monster.position
		var to_home := home_position - monster.position
		var distance_to_player := to_player.length()
		var player_near_home := home_position.distance_to(player.position) <= leash_distance

		if distance_to_player <= detection_radius and player_near_home:
			if distance_to_player > attack_range:
				monster.position += to_player.normalized() * speed * delta
		elif to_home.length() > MONSTER_HOME_EPSILON:
			monster.position += to_home.normalized() * return_speed * delta

		monster.position = clamp_to_world(monster.position, MONSTER_MARGIN)

		if absf(to_player.x) > 6.0:
			monster.flip_h = to_player.x < 0.0


func spawn_monster(pos: Vector2, type: String = "normal", offset_y: float = 0.0, offset_x: float = 0.0) -> Sprite2D:
	var monster := Sprite2D.new()
	var texture: Texture2D = player_texture
	var world_position := to_world_pos(offset_y, offset_x, pos)
	var speed := 110.0
	var return_speed := 82.0
	var detection_radius := 240.0
	var attack_range := 24.0
	var leash_distance := 420.0

	if not monster_textures.is_empty():
		texture = monster_textures[rng.randi_range(0, monster_textures.size() - 1)]

	monster.texture = texture
	monster.position = world_position
	monster.centered = true
	monster.z_index = 12
	monster.name = "%sMonster_%d" % [type.capitalize(), monsters_root.get_child_count()]

	match type:
		"elite":
			monster.scale = Vector2.ONE * 0.82
			monster.modulate = Color(1.0, 0.92, 0.7)
			speed = 145.0
			return_speed = 104.0
			detection_radius = 310.0
			attack_range = 32.0
			leash_distance = 520.0
		"boss":
			monster.scale = Vector2.ONE * 1.2
			monster.modulate = Color(1.0, 0.82, 0.82)
			speed = 95.0
			return_speed = 72.0
			detection_radius = 420.0
			attack_range = 44.0
			leash_distance = 700.0
		_:
			monster.scale = Vector2.ONE * 0.64
			monster.modulate = Color.WHITE

	monster.set_meta("monster_type", type)
	monster.set_meta("home_position", world_position)
	monster.set_meta("speed", speed)
	monster.set_meta("return_speed", return_speed)
	monster.set_meta("detection_radius", detection_radius)
	monster.set_meta("attack_range", attack_range)
	monster.set_meta("leash_distance", leash_distance)

	monsters_root.add_child(monster)
	return monster


func place_tree(pos: Vector2) -> StaticBody2D:
	return create_obstacle_body(pos, tree_texture, Vector2(60.0, 60.0), Vector2(1.4, 2.0), Vector2(-8.0, 8.0), 4)


func place_rock(pos: Vector2) -> StaticBody2D:
	return create_obstacle_body(pos, rock_texture, Vector2(44.0, 44.0), Vector2(1.1, 1.6), Vector2(-18.0, 18.0), 5)


func create_obstacle_body(world_pos: Vector2, texture: Texture2D, collision_size: Vector2, scale_range: Vector2, rotation_range: Vector2, z_index_value: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	var sprite := Sprite2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()

	body.position = world_pos
	body.z_index = z_index_value
	body.collision_layer = 1
	body.collision_mask = 1

	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2.ONE * rng.randf_range(scale_range.x, scale_range.y)
	sprite.rotation = deg_to_rad(rng.randf_range(rotation_range.x, rotation_range.y))

	shape.size = collision_size
	collision.shape = shape

	body.add_child(sprite)
	body.add_child(collision)
	obstacles_root.add_child(body)
	return body


func clear_children(root: Node) -> void:
	for child in root.get_children():
		child.queue_free()


func spawn_monsters_from_points(offset_y: float, offset_x: float, spawn_points: Array[Vector2], count: int, bounds: Rect2, spread: Vector2, type: String = "normal", min_distance: float = 28.0) -> void:
	var used_positions: Array[Vector2] = []

	for _i in range(count):
		var local_pos := sample_spawn_position(spawn_points, used_positions, bounds, spread, min_distance)
		used_positions.append(local_pos)
		spawn_monster(local_pos, type, offset_y, offset_x)


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


func decorate_module_boundaries(offset_y: float, offset_x: float, theme: String, top_has_opening: bool, bottom_has_opening: bool) -> void:
	place_vertical_boundary(offset_y, offset_x, 18.0, theme)
	place_vertical_boundary(offset_y, offset_x, MODULE_WIDTH - 18.0, theme)
	place_horizontal_boundary(offset_y, offset_x, 22.0, theme, top_has_opening)
	place_horizontal_boundary(offset_y, offset_x, MODULE_HEIGHT - 22.0, theme, bottom_has_opening)


func place_horizontal_boundary(offset_y: float, offset_x: float, y_local: float, theme: String, has_opening: bool) -> void:
	var x_local := 36.0
	while x_local <= MODULE_WIDTH - 36.0:
		if has_opening and x_local >= MODULE_GATE_LEFT and x_local <= MODULE_GATE_RIGHT:
			x_local = MODULE_GATE_RIGHT + 28.0
			continue

		var local_pos := Vector2(x_local + rng.randf_range(-6.0, 6.0), y_local + rng.randf_range(-4.0, 4.0))
		place_boundary_obstacle(offset_y, offset_x, local_pos, theme)
		x_local += 44.0 + rng.randf_range(-3.0, 3.0)


func place_vertical_boundary(offset_y: float, offset_x: float, x_local: float, theme: String) -> void:
	var y_local := 36.0
	while y_local <= MODULE_HEIGHT - 36.0:
		var local_pos := Vector2(x_local + rng.randf_range(-6.0, 6.0), y_local + rng.randf_range(-6.0, 6.0))
		place_boundary_obstacle(offset_y, offset_x, local_pos, theme)
		y_local += 44.0 + rng.randf_range(-3.0, 4.0)


func place_boundary_obstacle(offset_y: float, offset_x: float, local_pos: Vector2, theme: String) -> void:
	var roll := rng.randf()

	match theme:
		"forest":
			if roll < 0.72:
				place_tree_local(offset_y, offset_x, local_pos)
			else:
				place_rock_local(offset_y, offset_x, local_pos)
		"road":
			if roll < 0.86:
				place_rock_local(offset_y, offset_x, local_pos)
			else:
				place_tree_local(offset_y, offset_x, local_pos)
		"nest", "boss":
			if roll < 0.9:
				place_rock_local(offset_y, offset_x, local_pos)
			else:
				place_tree_local(offset_y, offset_x, local_pos)
		_:
			if roll < 0.62:
				place_tree_local(offset_y, offset_x, local_pos)
			else:
				place_rock_local(offset_y, offset_x, local_pos)


func create_road_side_walls(offset_y: float, offset_x: float, corridor_left: float, corridor_right: float) -> void:
	for index in range(ROAD_ROCK_COUNT):
		var row := index % 6
		var left_side := index < 6
		var y_local := 92.0 + float(row) * 84.0 + rng.randf_range(-6.0, 6.0)
		var x_local := corridor_left - rng.randf_range(28.0, 52.0)

		if not left_side:
			x_local = corridor_right + rng.randf_range(28.0, 52.0)

		place_rock_local(offset_y, offset_x, Vector2(x_local, y_local))


func ratio_pos(x_ratio: float, y_ratio: float) -> Vector2:
	return Vector2(MODULE_WIDTH * x_ratio, MODULE_HEIGHT * y_ratio)


func to_world_pos(offset_y: float, offset_x: float, local_pos: Vector2) -> Vector2:
	return Vector2(offset_x + local_pos.x, offset_y + local_pos.y)


func place_tree_local(offset_y: float, offset_x: float, local_pos: Vector2) -> StaticBody2D:
	return place_tree(to_world_pos(offset_y, offset_x, local_pos))


func place_rock_local(offset_y: float, offset_x: float, local_pos: Vector2) -> StaticBody2D:
	return place_rock(to_world_pos(offset_y, offset_x, local_pos))


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


func clamp_to_world(world_pos: Vector2, margin: Vector2) -> Vector2:
	return Vector2(
		clampf(world_pos.x, world_bounds.position.x + margin.x, world_bounds.position.x + world_bounds.size.x - margin.x),
		clampf(world_pos.y, world_bounds.position.y + margin.y, world_bounds.position.y + world_bounds.size.y - margin.y)
	)


func rect_center(bounds: Rect2) -> Vector2:
	return Vector2(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y + bounds.size.y * 0.5
	)


func add_module_floor(offset_y: float, offset_x: float, fill_color: Color, border_color: Color) -> void:
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([
		Vector2(offset_x, offset_y),
		Vector2(offset_x + MODULE_WIDTH, offset_y),
		Vector2(offset_x + MODULE_WIDTH, offset_y + MODULE_HEIGHT),
		Vector2(offset_x, offset_y + MODULE_HEIGHT)
	])
	floor.color = fill_color
	floor.z_index = -20
	tile_root.add_child(floor)

	var border := Line2D.new()
	border.points = PackedVector2Array([
		Vector2(offset_x, offset_y),
		Vector2(offset_x + MODULE_WIDTH, offset_y),
		Vector2(offset_x + MODULE_WIDTH, offset_y + MODULE_HEIGHT),
		Vector2(offset_x, offset_y + MODULE_HEIGHT)
	])
	border.closed = true
	border.width = 4.0
	border.default_color = border_color
	border.z_index = -19
	tile_root.add_child(border)


func add_vertical_corridor_strip(offset_y: float, offset_x: float, left_x: float, right_x: float, color: Color) -> void:
	var corridor := Polygon2D.new()
	corridor.polygon = PackedVector2Array([
		Vector2(offset_x + left_x, offset_y),
		Vector2(offset_x + right_x, offset_y),
		Vector2(offset_x + right_x, offset_y + MODULE_HEIGHT),
		Vector2(offset_x + left_x, offset_y + MODULE_HEIGHT)
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
