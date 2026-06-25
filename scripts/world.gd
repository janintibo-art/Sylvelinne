extends Node2D

# =====================================================================
#  Sylvelinne — niveau de test (Aëla, 8 directions)
#  Idle a l'arret, course (tes sprites) en mouvement, dans les 8 sens.
# =====================================================================

const PLAYER_SPEED: float = 240.0
const MOVE_FPS: float = 13.0
const GRID: int = 64
const WORLD_HALF: int = 3000
const CAM_ZOOM: float = 3.0   # zoom camera : 2 = un peu, 3 = beaucoup, 4 = enorme

# ordre aligne sur l'angle (atan2) : 0=droite, +45=bas-droite, ...
const DIRS8: Array = ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]

var player: CharacterBody2D
var sprite: Sprite2D
var ground_tex: Texture2D
var idle_tex: Dictionary = {}     # direction -> Texture2D
var move_tex: Dictionary = {}     # direction -> Array de Texture2D
var facing: String = "down"
var moving: bool = false
var anim_t: float = 0.0
var touch_active: bool = false
var touch_origin: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_load_textures()
	_load_ground()
	_create_player()
	_create_hud()
	queue_redraw()


func _load_textures() -> void:
	for d in DIRS8:
		var ip := "res://assets/characters/char_aela_idle_%s.png" % d
		if ResourceLoader.exists(ip):
			idle_tex[d] = load(ip)
		# animation de deplacement : "run" (course)
		var frames: Array = []
		for i in range(1, 9):
			var p := "res://assets/characters/char_aela_run_%s_%02d.png" % [d, i]
			if ResourceLoader.exists(p):
				frames.append(load(p))
		if frames.size() > 0:
			move_tex[d] = frames


func _load_ground() -> void:
	var p := "res://assets/tilesets/tile_grass_light.png"
	if ResourceLoader.exists(p):
		ground_tex = load(p)


func dir8_from(v: Vector2) -> String:
	var ang := atan2(v.y, v.x)
	var idx := int(round(ang / (PI / 4.0)))
	idx = ((idx % 8) + 8) % 8
	return DIRS8[idx]


func _create_player() -> void:
	player = CharacterBody2D.new()
	add_child(player)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 24)
	col.shape = shape
	col.position = Vector2(0, -12)
	player.add_child(col)

	if idle_tex.has("down"):
		sprite = Sprite2D.new()
		sprite.texture = idle_tex["down"]
		sprite.scale = Vector2(0.6, 0.6)
		var h := float(sprite.texture.get_height()) * sprite.scale.y
		sprite.position = Vector2(0, -h / 2.0)
		player.add_child(sprite)
	else:
		var ph := Polygon2D.new()
		ph.polygon = PackedVector2Array([Vector2(-20, -48), Vector2(20, -48), Vector2(20, 8), Vector2(-20, 8)])
		ph.color = Color(0.96, 0.86, 0.46)
		player.add_child(ph)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	player.add_child(cam)
	cam.make_current()


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "Sylvelinne — Aela (8 directions)\nPC : fleches    Mobile : glisse le doigt"
	label.position = Vector2(24, 24)
	layer.add_child(label)


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if touch_active:
		var t := touch_current - touch_origin
		if t.length() > 12.0:
			dir = t.normalized()
	if dir.length() > 1.0:
		dir = dir.normalized()
	player.velocity = dir * PLAYER_SPEED
	player.move_and_slide()

	moving = dir.length() > 0.05
	if moving:
		facing = dir8_from(dir)


func _process(delta: float) -> void:
	if sprite == null:
		return
	if moving and move_tex.has(facing):
		anim_t += delta
		var frames: Array = move_tex[facing]
		var idx := int(anim_t * MOVE_FPS) % frames.size()
		sprite.texture = frames[idx]
	else:
		anim_t = 0.0
		if idle_tex.has(facing):
			sprite.texture = idle_tex[facing]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_active = event.pressed
		if event.pressed:
			touch_origin = event.position
			touch_current = event.position
	elif event is InputEventScreenDrag:
		touch_current = event.position


func _draw() -> void:
	if ground_tex != null:
		draw_texture_rect(ground_tex, Rect2(-WORLD_HALF, -WORLD_HALF, WORLD_HALF * 2, WORLD_HALF * 2), true)
	else:
		draw_rect(Rect2(-WORLD_HALF, -WORLD_HALF, WORLD_HALF * 2, WORLD_HALF * 2), Color(0.20, 0.28, 0.20))
	var spots := [Vector2(300, -220), Vector2(-520, 280), Vector2(640, 480), Vector2(-320, -600)]
	var cols := [Color(0.55, 0.40, 0.30), Color(0.40, 0.50, 0.60), Color(0.52, 0.46, 0.56), Color(0.46, 0.56, 0.42)]
	for i in spots.size():
		draw_rect(Rect2(spots[i], Vector2(160, 140)), cols[i])
