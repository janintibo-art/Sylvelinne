extends Node2D

# =====================================================================
#  Sylvelinne — niveau de TEST
#  Démontre : une carte scrollable + un personnage qui se déplace,
#  au clavier (flèches) sur PC ou au doigt (glisser) sur mobile.
#  Tout est en "placeholder" : remplace par tes assets quand tu veux.
# =====================================================================

const PLAYER_SPEED: float = 220.0   # vitesse de déplacement (px/s)
const GRID: int = 64                # taille de la grille de fond
const WORLD_HALF: int = 3000        # demi-taille du monde dessiné

var player: CharacterBody2D
var touch_active: bool = false
var touch_origin: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO


func _ready() -> void:
	_create_player()
	_create_hud()
	queue_redraw()


func _create_player() -> void:
	player = CharacterBody2D.new()
	add_child(player)

	# forme de collision (utile plus tard pour les obstacles)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	col.shape = shape
	col.position = Vector2(0, -12)
	player.add_child(col)

	# visuel placeholder du perso (un rectangle "debout", pieds en bas)
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(-20, -48), Vector2(20, -48), Vector2(20, 8), Vector2(-20, 8)
	])
	vis.color = Color(0.96, 0.86, 0.46)
	player.add_child(vis)

	# caméra qui suit le perso => la carte défile (scroll)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	cam.make_current()


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "Sylvelinne — test\nPC : fleches    Mobile : glisse le doigt"
	label.position = Vector2(24, 24)
	layer.add_child(label)


func _physics_process(_delta: float) -> void:
	# --- entrée clavier (flèches) ---
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# --- entrée tactile (joystick "là où je pose le doigt") ---
	if touch_active:
		var t := touch_current - touch_origin
		if t.length() > 12.0:
			dir = t.normalized()

	if dir.length() > 1.0:
		dir = dir.normalized()

	player.velocity = dir * PLAYER_SPEED
	player.move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_active = event.pressed
		if event.pressed:
			touch_origin = event.position
			touch_current = event.position
	elif event is InputEventScreenDrag:
		touch_current = event.position


func _draw() -> void:
	# fond "herbe"
	draw_rect(Rect2(-WORLD_HALF, -WORLD_HALF, WORLD_HALF * 2, WORLD_HALF * 2), Color(0.20, 0.28, 0.20))

	# grille (pour bien voir le défilement)
	var line_col := Color(1, 1, 1, 0.06)
	var x := -WORLD_HALF
	while x <= WORLD_HALF:
		draw_line(Vector2(x, -WORLD_HALF), Vector2(x, WORLD_HALF), line_col)
		x += GRID
	var y := -WORLD_HALF
	while y <= WORLD_HALF:
		draw_line(Vector2(-WORLD_HALF, y), Vector2(WORLD_HALF, y), line_col)
		y += GRID

	# quelques "batiments" placeholder (rectangles colorés)
	var spots := [Vector2(300, -220), Vector2(-520, 280), Vector2(640, 480), Vector2(-320, -600)]
	var cols := [
		Color(0.55, 0.40, 0.30), Color(0.40, 0.50, 0.60),
		Color(0.52, 0.46, 0.56), Color(0.46, 0.56, 0.42)
	]
	for i in spots.size():
		draw_rect(Rect2(spots[i], Vector2(160, 140)), cols[i])
