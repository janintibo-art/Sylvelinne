extends Node2D

# =====================================================================
#  Sylvelinne — Aëla
#  Monde + village + INTERIEUR PRATICABLE & INTERACTIF + VENT
# =====================================================================

const PLAYER_SPEED: float = 240.0
const MOVE_FPS: float = 13.0
const CAST_FPS: float = 14.0
const SPELL_SPEED: float = 520.0
const CAM_ZOOM: float = 3.0
const WORLD_HALF: int = 3000

# Interieur : pièce construite, placée loin, caméra fixe
const INTERIOR_CENTER: Vector2 = Vector2(10000.0, 0.0)
const ROOM_HALF: Vector2 = Vector2(300.0, 170.0)   # demi-taille du sol

const DIRS8: Array = ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const DIR_VEC: Dictionary = {
	"right": Vector2(1, 0), "down_right": Vector2(0.7071, 0.7071), "down": Vector2(0, 1),
	"down_left": Vector2(-0.7071, 0.7071), "left": Vector2(-1, 0), "up_left": Vector2(-0.7071, -0.7071),
	"up": Vector2(0, -1), "up_right": Vector2(0.7071, -0.7071)
}

const START_ITEMS: Array = [
	{"icon": "epee", "name": "Épée", "qty": 1}, {"icon": "arc", "name": "Arc", "qty": 1},
	{"icon": "bouclier", "name": "Bouclier", "qty": 1}, {"icon": "potion_soin", "name": "Potion de soin", "qty": 2},
	{"icon": "grimoire", "name": "Grimoire", "qty": 1}, {"icon": "pain", "name": "Pain", "qty": 3},
]

const PROPS: Array = [
	{"tex": "buildings/maison2", "pos": Vector2(-260, -360), "h": 380.0, "foot": Vector2(150, 40)},
	{"tex": "buildings/maison3", "pos": Vector2(330, -340), "h": 380.0, "foot": Vector2(150, 40)},
	{"tex": "buildings/maison1", "pos": Vector2(-560, -180), "h": 340.0, "foot": Vector2(180, 40)},
	{"tex": "buildings/auberge", "pos": Vector2(560, -160), "h": 340.0, "foot": Vector2(180, 40)},
	{"tex": "nature/arbre", "pos": Vector2(-820, 320), "h": 440.0, "foot": Vector2(70, 30)},
	{"tex": "nature/rocher1", "pos": Vector2(560, 330), "h": 150.0, "foot": Vector2(130, 30)},
	{"tex": "nature/rocher2", "pos": Vector2(170, 410), "h": 120.0, "foot": Vector2(90, 30)},
	{"tex": "nature/rocher3", "pos": Vector2(-300, 450), "h": 150.0, "foot": Vector2(110, 30)},
]

var player: CharacterBody2D
var sprite: Sprite2D
var ysort: Node2D
var cam_outside: Camera2D
var cam_inside: Camera2D
var ground_tex: Texture2D
var floor_tex: Texture2D
var wall_tex: Texture2D
var idle_tex: Dictionary = {}
var move_tex: Dictionary = {}
var cast_tex: Dictionary = {}
var orb_tex: Texture2D

var patch_dirt: Texture2D
var patch_gmid: Texture2D
var patch_gdark: Texture2D
var grass_var: Array = []
var dirt_spots: Array = []
var sway_sprites: Array = []

var facing: String = "down"
var moving: bool = false
var anim_t: float = 0.0

var casting: bool = false
var cast_t: float = 0.0
var cast_fired: bool = false
var projectiles: Array = []

var bag: Array = []
var inv_root: Control
var inv_grid: GridContainer
var enter_btn: Button
var exit_btn: Button
var act_btn: Button
var toast_label: Label
var toast_t: float = 0.0

var inside: bool = false
var near_house: int = -1
var return_pos: Vector2 = Vector2.ZERO
var interactives: Array = []
var near_interact: int = -1

var wind_phase: float = 0.0
var wind_str: float = 0.6

var touch_active: bool = false
var touch_origin: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_load_textures()
	_load_ground()
	orb_tex = _make_orb()
	for it in START_ITEMS:
		bag.append({"icon": it.icon, "name": it.name, "qty": it.qty})
	_build_ground_deco()
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	_create_player()
	_spawn_props()
	_build_interior()
	_create_hud()
	_create_inventory()
	_create_petals()
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
	if ResourceLoader.exists("res://assets/tilesets/tile_grass_light.png"):
		ground_tex = load("res://assets/tilesets/tile_grass_light.png")
	if ResourceLoader.exists("res://assets/tilesets/patch_dirt.png"):
		patch_dirt = load("res://assets/tilesets/patch_dirt.png")
	if ResourceLoader.exists("res://assets/tilesets/patch_grass_mid.png"):
		patch_gmid = load("res://assets/tilesets/patch_grass_mid.png")
	if ResourceLoader.exists("res://assets/tilesets/patch_grass_dark.png"):
		patch_gdark = load("res://assets/tilesets/patch_grass_dark.png")
	if ResourceLoader.exists("res://assets/interiors/wood_floor.png"):
		floor_tex = load("res://assets/interiors/wood_floor.png")
	if ResourceLoader.exists("res://assets/interiors/wall.png"):
		wall_tex = load("res://assets/interiors/wall.png")


func _build_ground_deco() -> void:
	var plaza := [
		Vector3(-200, -120, 320), Vector3(120, -130, 320), Vector3(-220, 140, 320), Vector3(160, 150, 320),
		Vector3(-30, 0, 400), Vector3(-330, 10, 300), Vector3(330, 20, 300), Vector3(0, -230, 310), Vector3(0, 230, 310)
	]
	for v in plaza:
		dirt_spots.append({"pos": Vector2(v.x, v.y), "size": Vector2(v.z, v.z)})
	var yy := -300
	while yy > -1050:
		dirt_spots.append({"pos": Vector2(0, yy), "size": Vector2(200, 200)})
		yy -= 95
	var xx := 300
	while xx < 1050:
		dirt_spots.append({"pos": Vector2(xx, 0), "size": Vector2(200, 200)})
		xx += 95
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(36):
		var wx := rng.randf_range(-2400, 2400)
		var wy := rng.randf_range(-2400, 2400)
		if absf(wx) < 420 and absf(wy) < 320:
			continue
		var s := rng.randf_range(220, 420)
		var tex: Texture2D = patch_gmid if rng.randf() < 0.5 else patch_gdark
		grass_var.append({"pos": Vector2(wx, wy), "size": Vector2(s, s), "tex": tex})


func _spawn_props() -> void:
	for pr in PROPS:
		var path := "res://assets/%s.png" % pr.tex
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var spr := Sprite2D.new()
		spr.texture = tex
		var s: float = pr.h / float(tex.get_height())
		spr.scale = Vector2(s, s)
		spr.offset = Vector2(0, -tex.get_height() / 2.0)
		spr.position = pr.pos
		ysort.add_child(spr)
		_add_collision(pr.pos + Vector2(0, -pr.foot.y / 2.0), pr.foot)
		if String(pr.tex).contains("arbre"):
			sway_sprites.append({"spr": spr, "ph": randf() * TAU})


# ---------------- INTERIEUR CONSTRUIT ----------------
func _build_interior() -> void:
	var ic := INTERIOR_CENTER
	# tapis (sous tout, z=-1)
	_add_furni("tapis", Vector2(0, 30), 135.0, false, Vector2.ZERO, -1)
	# meubles (avec collision)
	_add_furni("lit", Vector2(-190, -90), 132.0, true, Vector2(112, 38))
	_add_furni("commode", Vector2(-50, -135), 108.0, true, Vector2(92, 28))
	_add_furni("biblio", Vector2(55, -138), 150.0, true, Vector2(72, 26))
	_add_furni("armoire", Vector2(210, -100), 150.0, true, Vector2(72, 28))
	_add_furni("bureau", Vector2(215, 20), 122.0, true, Vector2(92, 32))
	_add_furni("table", Vector2(0, 55), 104.0, true, Vector2(92, 36))
	_add_furni("tabouret", Vector2(0, 102), 76.0, true, Vector2(42, 22))
	_add_furni("fauteuil", Vector2(205, 105), 118.0, true, Vector2(78, 34))
	# coffre interactif
	_add_interactive("chest", "furniture/coffre", Vector2(-205, 100), 114.0, true, Vector2(78, 32),
		[{"icon": "cristal", "name": "Cristal", "qty": 2}, {"icon": "bourse", "name": "Bourse d'or", "qty": 1}])
	# objets à ramasser (icônes propres)
	_add_interactive("item", "items/potion_soin", Vector2(140, 35), 30.0, false, Vector2.ZERO,
		[{"icon": "potion_soin", "name": "Potion de soin", "qty": 1}])
	_add_interactive("item", "items/cristal", Vector2(-35, 22), 26.0, false, Vector2.ZERO,
		[{"icon": "cristal", "name": "Cristal", "qty": 1}])
	_add_interactive("item", "items/pomme", Vector2(70, 78), 26.0, false, Vector2.ZERO,
		[{"icon": "pomme", "name": "Pomme", "qty": 1}])
	_add_interactive("item", "items/cle", Vector2(-130, -28), 26.0, false, Vector2.ZERO,
		[{"icon": "cle", "name": "Clé", "qty": 1}])
	# murs (limite du sol)
	_add_collision(ic + Vector2(0, -ROOM_HALF.y), Vector2(ROOM_HALF.x * 2.0 + 12, 12))
	_add_collision(ic + Vector2(0, ROOM_HALF.y), Vector2(ROOM_HALF.x * 2.0 + 12, 12))
	_add_collision(ic + Vector2(-ROOM_HALF.x, 0), Vector2(12, ROOM_HALF.y * 2.0))
	_add_collision(ic + Vector2(ROOM_HALF.x, 0), Vector2(12, ROOM_HALF.y * 2.0))
	# caméra intérieure fixe
	cam_inside = Camera2D.new()
	cam_inside.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	cam_inside.position = ic
	add_child(cam_inside)
	_create_dust()


func _add_furni(name: String, rel: Vector2, h: float, collide: bool, foot: Vector2, z: int = 0) -> void:
	var path := "res://assets/furniture/%s.png" % name
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var spr := Sprite2D.new()
	spr.texture = tex
	var s: float = h / float(tex.get_height())
	spr.scale = Vector2(s, s)
	spr.offset = Vector2(0, -tex.get_height() / 2.0)
	spr.position = INTERIOR_CENTER + rel
	spr.z_index = z
	ysort.add_child(spr)
	if collide:
		_add_collision(INTERIOR_CENTER + rel + Vector2(0, -foot.y / 2.0), foot)


func _add_interactive(type: String, tex_path: String, rel: Vector2, h: float, collide: bool, foot: Vector2, loot: Array) -> void:
	var path := "res://assets/%s.png" % tex_path
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var spr := Sprite2D.new()
	spr.texture = tex
	var s: float = h / float(tex.get_height())
	spr.scale = Vector2(s, s)
	spr.offset = Vector2(0, -tex.get_height() / 2.0)
	spr.position = INTERIOR_CENTER + rel
	ysort.add_child(spr)
	if collide:
		_add_collision(INTERIOR_CENTER + rel + Vector2(0, -foot.y / 2.0), foot)
	interactives.append({"type": type, "pos": INTERIOR_CENTER + rel, "spr": spr, "loot": loot, "taken": false})


func _add_collision(pos: Vector2, size: Vector2) -> void:
	var sb := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	cs.position = pos
	sb.add_child(cs)
	add_child(sb)


func _make_orb() -> Texture2D:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s / 2.0, s / 2.0)
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(c) / (s / 2.0)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			var col := Color(1.0, 0.85, 0.4, a)
			if d < 0.45:
				col = Color(1.0, 1.0, 0.92, a)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func dir8_from(v: Vector2) -> String:
	var ang := atan2(v.y, v.x)
	var idx := int(round(ang / (PI / 4.0)))
	idx = ((idx % 8) + 8) % 8
	return DIRS8[idx]


func _create_player() -> void:
	player = CharacterBody2D.new()
	ysort.add_child(player)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 22)
	col.shape = shape
	col.position = Vector2(0, -11)
	player.add_child(col)

	if idle_tex.has("down"):
		sprite = Sprite2D.new()
		sprite.texture = idle_tex["down"]
		sprite.scale = Vector2(0.6, 0.6)
		sprite.flip_h = true
		var h := float(sprite.texture.get_height()) * sprite.scale.y
		sprite.position = Vector2(0, -h / 2.0)
		player.add_child(sprite)
	else:
		var ph := Polygon2D.new()
		ph.polygon = PackedVector2Array([Vector2(-20, -48), Vector2(20, -48), Vector2(20, 8), Vector2(-20, 8)])
		ph.color = Color(0.96, 0.86, 0.46)
		player.add_child(ph)

	cam_outside = Camera2D.new()
	cam_outside.position_smoothing_enabled = true
	cam_outside.position_smoothing_speed = 8.0
	cam_outside.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	player.add_child(cam_outside)
	cam_outside.make_current()


func _create_petals() -> void:
	if not ResourceLoader.exists("res://assets/vfx/petal.png"):
		return
	var pet := CPUParticles2D.new()
	pet.texture = load("res://assets/vfx/petal.png")
	pet.amount = 22
	pet.lifetime = 8.0
	pet.preprocess = 4.0
	pet.local_coords = false
	pet.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pet.emission_rect_extents = Vector2(360, 18)
	pet.position = Vector2(0, -200)
	pet.direction = Vector2(0.5, 1)
	pet.spread = 35.0
	pet.gravity = Vector2(7, 16)
	pet.initial_velocity_min = 12.0
	pet.initial_velocity_max = 34.0
	pet.angular_velocity_min = -70.0
	pet.angular_velocity_max = 70.0
	pet.scale_amount_min = 0.3
	pet.scale_amount_max = 0.7
	pet.color = Color(1, 1, 1, 0.85)
	cam_outside.add_child(pet)


func _create_dust() -> void:
	if not ResourceLoader.exists("res://assets/vfx/dust.png"):
		return
	var d := CPUParticles2D.new()
	d.texture = load("res://assets/vfx/dust.png")
	d.amount = 16
	d.lifetime = 6.0
	d.preprocess = 3.0
	d.local_coords = false
	d.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	d.emission_rect_extents = Vector2(290, 165)
	d.position = INTERIOR_CENTER
	d.direction = Vector2(0, -1)
	d.spread = 60.0
	d.gravity = Vector2(2, -4)
	d.initial_velocity_min = 3.0
	d.initial_velocity_max = 9.0
	d.scale_amount_min = 0.4
	d.scale_amount_max = 1.0
	d.color = Color(1, 1, 0.92, 0.45)
	cam_inside.add_child(d)


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var label := Label.new()
	label.text = "Sylvelinne — Aela"
	label.position = Vector2(24, 24)
	layer.add_child(label)

	var cast_btn := Button.new()
	cast_btn.text = "✨ Sort"
	cast_btn.add_theme_font_size_override("font_size", 48)
	cast_btn.size = Vector2(260, 150)
	cast_btn.position = Vector2(1600, 870)
	cast_btn.modulate = Color(1, 1, 1, 0.92)
	cast_btn.pressed.connect(_on_cast)
	layer.add_child(cast_btn)

	var sac_btn := Button.new()
	sac_btn.text = "Sac"
	sac_btn.add_theme_font_size_override("font_size", 44)
	sac_btn.size = Vector2(220, 96)
	sac_btn.position = Vector2(1660, 30)
	sac_btn.modulate = Color(1, 1, 1, 0.92)
	sac_btn.pressed.connect(_toggle_inventory)
	layer.add_child(sac_btn)

	enter_btn = Button.new()
	enter_btn.text = "Entrer"
	enter_btn.add_theme_font_size_override("font_size", 44)
	enter_btn.size = Vector2(280, 120)
	enter_btn.position = Vector2(820, 900)
	enter_btn.visible = false
	enter_btn.pressed.connect(_on_enter)
	layer.add_child(enter_btn)

	exit_btn = Button.new()
	exit_btn.text = "🚪 Sortir"
	exit_btn.add_theme_font_size_override("font_size", 40)
	exit_btn.size = Vector2(260, 110)
	exit_btn.position = Vector2(60, 900)
	exit_btn.visible = false
	exit_btn.pressed.connect(_on_exit)
	layer.add_child(exit_btn)

	act_btn = Button.new()
	act_btn.text = "Ramasser"
	act_btn.add_theme_font_size_override("font_size", 44)
	act_btn.size = Vector2(300, 120)
	act_btn.position = Vector2(810, 900)
	act_btn.visible = false
	act_btn.pressed.connect(_on_act)
	layer.add_child(act_btn)

	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 46)
	toast_label.modulate = Color(1, 1, 0.6)
	toast_label.position = Vector2(660, 150)
	toast_label.visible = false
	layer.add_child(toast_label)


func _create_inventory() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	inv_root = Control.new()
	inv_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_root.visible = false
	layer.add_child(inv_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1500, 860)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "Inventaire"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1420, 640)
	vb.add_child(scroll)

	inv_grid = GridContainer.new()
	inv_grid.columns = 6
	inv_grid.add_theme_constant_override("h_separation", 16)
	inv_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(inv_grid)

	var close_btn := Button.new()
	close_btn.text = "Fermer"
	close_btn.add_theme_font_size_override("font_size", 42)
	close_btn.pressed.connect(_toggle_inventory)
	vb.add_child(close_btn)


func _refresh_inventory() -> void:
	for c in inv_grid.get_children():
		c.queue_free()
	for item in bag:
		inv_grid.add_child(_make_slot(item))


func _make_slot(item: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 200)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(130, 130)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var p := "res://assets/items/%s.png" % item.icon
	if ResourceLoader.exists(p):
		icon.texture = load(p)
	box.add_child(icon)

	var nm := Label.new()
	nm.text = item.name
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 26)
	box.add_child(nm)

	var q := Label.new()
	q.text = "x%d" % item.qty
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_font_size_override("font_size", 24)
	q.modulate = Color(1, 1, 0.6)
	box.add_child(q)
	return box


func _toggle_inventory() -> void:
	var willshow := not inv_root.visible
	if willshow:
		_refresh_inventory()
	inv_root.visible = willshow


func _add_to_bag(icon: String, name: String, qty: int) -> void:
	for item in bag:
		if item.name == name:
			item.qty += qty
			return
	bag.append({"icon": icon, "name": name, "qty": qty})


func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate.a = 1.0
	toast_t = 1.8
	toast_label.visible = true


func _on_enter() -> void:
	if near_house < 0 or inside:
		return
	inside = true
	return_pos = PROPS[near_house].pos + Vector2(0, 60)
	player.position = INTERIOR_CENTER + Vector2(0, 128)
	player.velocity = Vector2.ZERO
	facing = "up"
	cam_inside.make_current()
	enter_btn.visible = false
	exit_btn.visible = true


func _on_exit() -> void:
	if not inside:
		return
	inside = false
	player.position = return_pos
	player.velocity = Vector2.ZERO
	facing = "down"
	cam_outside.make_current()
	exit_btn.visible = false
	act_btn.visible = false


func _on_act() -> void:
	if near_interact < 0:
		return
	var o: Dictionary = interactives[near_interact]
	if o.taken:
		return
	o.taken = true
	var msg := ""
	for l in o.loot:
		_add_to_bag(l.icon, l.name, l.qty)
		msg += "+%d %s   " % [l.qty, l.name]
	_show_toast(msg)
	if o.type == "item":
		o.spr.visible = false
	else:
		o.spr.modulate = Color(0.72, 0.72, 0.72)
	act_btn.visible = false
	near_interact = -1


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
	orb.z_index = 100
	orb.position = player.position + dir * 34.0 + Vector2(0, -54)
	add_child(orb)
	projectiles.append({"node": orb, "vel": dir * SPELL_SPEED, "life": 1.5})


func _physics_process(_delta: float) -> void:
	if casting or (inv_root != null and inv_root.visible):
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
	# vent (force variable, douce)
	wind_phase += delta
	wind_str = 0.55 + 0.28 * sin(wind_phase * 0.6) + 0.14 * sin(wind_phase * 1.7 + 1.0)
	for sw in sway_sprites:
		sw.spr.rotation = sin(wind_phase * 1.6 + sw.ph) * wind_str * 0.025

	# toast (fondu)
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t < 0.6:
			toast_label.modulate.a = clampf(toast_t / 0.6, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_label.visible = false

	# proximité contextuelle
	var inv_open := inv_root != null and inv_root.visible
	if inside:
		near_interact = -1
		for i in range(interactives.size()):
			var o: Dictionary = interactives[i]
			if o.taken:
				continue
			if player.position.distance_to(o.pos) < 64.0:
				near_interact = i
				break
		if near_interact >= 0 and not inv_open:
			act_btn.text = "Ouvrir" if interactives[near_interact].type == "chest" else "Ramasser"
			act_btn.visible = true
		else:
			act_btn.visible = false
	else:
		near_house = -1
		for i in range(4):
			if player.position.distance_to(PROPS[i].pos) < 150.0:
				near_house = i
				break
		enter_btn.visible = (near_house >= 0) and not inv_open

	_update_projectiles(delta)
	if sprite == null:
		return

	if casting:
		var cframes: Array = cast_tex[facing]
		cast_t += delta
		var idx := int(cast_t * CAST_FPS)
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
	if inv_root != null and inv_root.visible:
		return
	if event is InputEventScreenTouch:
		touch_active = event.pressed
		if event.pressed:
			touch_origin = event.position
			touch_current = event.position
	elif event is InputEventScreenDrag:
		touch_current = event.position


func _draw() -> void:
	# --- INTERIEUR (loin) : fond + murs + sol ---
	var ic := INTERIOR_CENTER
	draw_rect(Rect2(ic + Vector2(-720, -480), Vector2(1440, 960)), Color(0.09, 0.08, 0.13))
	if wall_tex != null:
		draw_texture_rect(wall_tex, Rect2(ic + Vector2(-ROOM_HALF.x - 16, -ROOM_HALF.y - 46), Vector2(ROOM_HALF.x * 2 + 32, ROOM_HALF.y * 2 + 62)), true)
	else:
		draw_rect(Rect2(ic + Vector2(-ROOM_HALF.x - 16, -ROOM_HALF.y - 46), Vector2(ROOM_HALF.x * 2 + 32, ROOM_HALF.y * 2 + 62)), Color(0.5, 0.45, 0.39))
	if floor_tex != null:
		draw_texture_rect(floor_tex, Rect2(ic - ROOM_HALF, ROOM_HALF * 2), true)
	else:
		draw_rect(Rect2(ic - ROOM_HALF, ROOM_HALF * 2), Color(0.48, 0.33, 0.20))
	draw_rect(Rect2(ic + Vector2(-ROOM_HALF.x, -ROOM_HALF.y), Vector2(ROOM_HALF.x * 2, 10)), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(ic + Vector2(-46, ROOM_HALF.y - 6), Vector2(92, 22)), Color(0.16, 0.11, 0.07))

	# --- EXTERIEUR : herbe + variations + terre ---
	if ground_tex != null:
		draw_texture_rect(ground_tex, Rect2(-WORLD_HALF, -WORLD_HALF, WORLD_HALF * 2, WORLD_HALF * 2), true)
	else:
		draw_rect(Rect2(-WORLD_HALF, -WORLD_HALF, WORLD_HALF * 2, WORLD_HALF * 2), Color(0.20, 0.28, 0.20))
	for g in grass_var:
		if g.tex != null:
			draw_texture_rect(g.tex, Rect2(g.pos - g.size * 0.5, g.size), false)
	if patch_dirt != null:
		for d in dirt_spots:
			draw_texture_rect(patch_dirt, Rect2(d.pos - d.size * 0.5, d.size), false)
