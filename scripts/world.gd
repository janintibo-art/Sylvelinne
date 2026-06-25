extends Node2D

# =====================================================================
#  Sylvelinne — niveau de test (Aëla)
#  Deplacement 8 directions + idle + SORT (bouton + boule de magie)
# =====================================================================

const PLAYER_SPEED: float = 240.0
const MOVE_FPS: float = 13.0
const CAST_FPS: float = 14.0
const SPELL_SPEED: float = 520.0
const CAM_ZOOM: float = 3.0          # zoom camera : 2 = un peu, 3 = beaucoup, 4 = enorme
const WORLD_HALF: int = 3000

const DIRS8: Array = ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const DIR_VEC: Dictionary = {
	"right": Vector2(1, 0), "down_right": Vector2(0.7071, 0.7071), "down": Vector2(0, 1),
	"down_left": Vector2(-0.7071, 0.7071), "left": Vector2(-1, 0), "up_left": Vector2(-0.7071, -0.7071),
	"up": Vector2(0, -1), "up_right": Vector2(0.7071, -0.7071)
}

var player: CharacterBody2D
var sprite: Sprite2D
var ground_tex: Texture2D
var idle_tex: Dictionary = {}        # direction -> Texture2D
var move_tex: Dictionary = {}        # direction -> Array de Texture2D
var cast_tex: Dictionary = {}        # direction -> Array de Texture2D
var orb_tex: Texture2D

var facing: String = "down"
var moving: bool = false
var anim_t: float = 0.0

var casting: bool = false
var cast_t: float = 0.0
var cast_fired: bool = false
var projectiles: Array = []          # { node, vel, life }

var touch_active: bool = false
var touch_origin: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_load_textures()
	_load_ground()
	orb_tex = _make_orb()
	_create_player()
	_create_hud()
	_create_cast_button()
	queue_redraw()


func _load_textures() -> void:
	for d in DIRS8:
		var ip := "res://assets/characters/char_aela_idle_%s.png" % d
		if ResourceLoader.exists(ip):
			idle_tex[d] = load(ip)
		move_tex[d] = _load_frames("run", d)
		cast_tex[d] = _load_frames("cast", d)


func _load_frames(action: String, d: String) -> Array:
	var frames: Array = []
	for i in range(1, 41):
		var p := "res://assets/characters/char_aela_%s_%s_%02d.png" % [action, d, i]
		if ResourceLoader.exists(p):
			frames.append(load(p))
		else:
			break
	return frames


func _load_ground() -> void:
	var p := "res://assets/tilesets/tile_grass_light.png"
	if ResourceLoader.exists(p):
		ground_tex = load(p)


func _make_orb() -> Texture2D:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s / 2.0, s / 2.0)
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(c) / (s / 2.0)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			var col := Color(1.0, 0.85, 0.4, a)      # halo doré
			if d < 0.45:
				col = Color(1.0, 1.0, 0.92, a)        # cœur clair
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


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
		sprite.flip_h = true   # corrige l'inversion gauche-droite des sprites de l'outil
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
	label.text = "Sylvelinne — Aela\nDeplacement : glisse le doigt    Sort : bouton en bas a droite"
	label.position = Vector2(24, 24)
	layer.add_child(label)


func _create_cast_button() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var btn := Button.new()
	btn.text = "✨ Sort"
	btn.add_theme_font_size_override("font_size", 48)
	btn.size = Vector2(260, 150)
	btn.position = Vector2(1600, 870)
	btn.modulate = Color(1, 1, 1, 0.92)
	btn.pressed.connect(_on_cast)
	layer.add_child(btn)


func _on_cast() -> void:
	if casting:
		return
	if cast_tex.has(facing) and cast_tex[facing].size() > 0:
		casting = true
		cast_t = 0.0
		cast_fired = false


func _spawn_projectile() -> void:
	if orb_tex == null:
		return
	var dir: Vector2 = DIR_VEC.get(facing, Vector2(0, 1))
	var orb := Sprite2D.new()
	orb.texture = orb_tex
	orb.scale = Vector2(0.55, 0.55)
	orb.position = player.position + dir * 34.0 + Vector2(0, -54)
	add_child(orb)
	projectiles.append({"node": orb, "vel": dir * SPELL_SPEED, "life": 1.5})


func _physics_process(_delta: float) -> void:
	if casting:
		player.velocity = Vector2.ZERO
		player.move_and_slide()
		return
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
	_update_projectiles(delta)
	if sprite == null:
		return

	if casting:
		var cframes: Array = cast_tex[facing]
		cast_t += delta
		var idx := int(cast_t * CAST_FPS)
		# lancer la boule au milieu de l'animation (moment du "lancer")
		if not cast_fired and cast_t > (cframes.size() / CAST_FPS) * 0.5:
			_spawn_projectile()
			cast_fired = true
		if idx >= cframes.size():
			casting = false
			sprite.texture = idle_tex.get(facing, sprite.texture)
		else:
			sprite.texture = cframes[idx]
	elif moving and move_tex.has(facing) and move_tex[facing].size() > 0:
		anim_t += delta
		var mframes: Array = move_tex[facing]
		sprite.texture = mframes[int(anim_t * MOVE_FPS) % mframes.size()]
	else:
		anim_t = 0.0
		if idle_tex.has(facing):
			sprite.texture = idle_tex[facing]


func _update_projectiles(delta: float) -> void:
	for p in projectiles:
		p.life -= delta
		var node: Sprite2D = p.node
		node.position += p.vel * delta
		if p.life < 0.5:
			node.modulate.a = clampf(p.life / 0.5, 0.0, 1.0)
	var alive: Array = []
	for p in projectiles:
		if p.life > 0.0:
			alive.append(p)
		else:
			p.node.queue_free()
	projectiles = alive


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
