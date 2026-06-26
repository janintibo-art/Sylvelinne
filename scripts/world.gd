extends Node2D

const NpcBrainScript = preload("res://scripts/npc_brain.gd")

# =====================================================================
#  Sylvelinne — Aëla
#  Monde + village + 4 INTERIEURS distincts (effet TARDIS) + VENT
# =====================================================================

const PLAYER_SPEED: float = 240.0
const MOVE_FPS: float = 13.0
const CAST_FPS: float = 14.0
const SPELL_SPEED: float = 520.0
const CAM_ZOOM: float = 3.0
const WORLD_HALF: int = 3000

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
	{"tex": "buildings/boutique", "pos": Vector2(-560, -180), "h": 370.0, "foot": Vector2(230, 40)},
	{"tex": "buildings/auberge", "pos": Vector2(560, -160), "h": 340.0, "foot": Vector2(180, 40)},
	{"tex": "nature/arbre", "pos": Vector2(-820, 320), "h": 440.0, "foot": Vector2(70, 30)},
	{"tex": "nature/rocher1", "pos": Vector2(560, 330), "h": 150.0, "foot": Vector2(130, 30)},
	{"tex": "nature/rocher2", "pos": Vector2(170, 410), "h": 120.0, "foot": Vector2(90, 30)},
	{"tex": "nature/rocher3", "pos": Vector2(-300, 450), "h": 150.0, "foot": Vector2(110, 30)},
]

# 4 pièces (1 par maison, même ordre que PROPS[0..3])
const ROOM_CENTERS: Array = [Vector2(10000, 0), Vector2(12600, 0), Vector2(15200, 0), Vector2(17800, 0), Vector2(20400, 0)]
const ROOM_HALVES: Array = [Vector2(300, 170), Vector2(560, 360), Vector2(440, 280), Vector2(620, 400), Vector2(520, 340)]
const ROOM_FLOORTINT: Array = [Color(1, 1, 1), Color(0.9, 0.86, 0.82), Color(1.06, 0.98, 0.9), Color(1.1, 0.99, 0.85), Color(0.72, 0.7, 0.78)]
const ROOM_WALLTINT: Array = [Color(1, 1, 1), Color(0.86, 0.86, 0.94), Color(1.02, 0.98, 0.96), Color(1.04, 0.96, 0.86), Color(0.6, 0.6, 0.72)]

var player: CharacterBody2D
var sprite: Sprite2D
var ysort: Node2D
var cam: Camera2D
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
var petals: CPUParticles2D
var dust: CPUParticles2D

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
var current_room: int = 0
var near_house: int = -1
var return_pos: Vector2 = Vector2.ZERO
var interactives: Array = []
var near_interact: int = -1
var npcs: Array = []
var creatures: Array = []
var npc_say: Label
var npc_say_t: float = 0.0
var trapdoor: Dictionary = {}
var near_trap: bool = false

const ALDWIN_GRAMMAR := {
	"greet_new": ["Qui ose troubler {lieu} ? {menace}", "Une intruse... {menace}", "Tu n'aurais pas dû descendre ici. {menace}"],
	"greet_return": ["Encore toi. {las}", "Tu reviens te soumettre ? {menace}", "L'insecte persévère. {menace}"],
	"chat": ["{pensee} {froid}", "{pensee}", "{froid}"],
	"react_pick": ["Repose cela. {menace}", "Ces reliques ne sont pas à toi. {menace}"],
	"react_buy": ["Tu pilles mon trône... {menace}", "Audacieuse. Cela te coûtera. {menace}"],
	"lieu": ["mon repaire", "ma salle", "le silence de l'Immuable", "mon trône"],
	"menace": ["Le gel n'épargne personne.", "Les saisons m'obéissent, pas toi.", "Repars, ou deviens statue.", "Aldévane ne te sauvera pas."],
	"las": ["Ta persévérance m'agace.", "Tu n'apprends donc rien ?"],
	"pensee": ["Le monde était parfait : figé, silencieux.", "J'ai arrêté le temps pour le préserver.", "Le printemps n'est que désordre.", "Les Esprits chuchotent ? Qu'ils chuchotent."],
	"froid": ["...", "Tout doit s'immobiliser.", "Le mouvement est une faiblesse.", "Ici, rien ne change. Jamais."],
}

const PEINTRE_GRAMMAR := {
	"greet_new": ["Oh... une visiteuse. {accueil}", "Tu as des couleurs dans le regard, toi. {accueil}", "Approche, ne fais pas fuir la lumière. {accueil}"],
	"greet_return": ["Te revoilà. {doux}", "J'ai gardé une couleur pour toi. {doux}"],
	"chat": ["{muse} {soupir}", "{muse}", "{soupir}"],
	"react_pick": ["Prends, prends. {doux}", "Les belles choses doivent voyager. {doux}"],
	"react_buy": ["Que cela t'apporte un peu de printemps.", "Emporte une couleur avec toi. {doux}"],
	"accueil": ["Je peins ce que le gel a volé.", "Ici, je garde les saisons en vie, sur la toile.", "Le blanc n'est pas le vide : c'est tout ce qui attend."],
	"doux": ["*sourire de neige*", "Que les Esprits te gardent.", "Va, et regarde mieux le monde."],
	"muse": ["Tu te souviens de la couleur du printemps ? Moi, oui.", "Aldwin a figé le monde, mais pas ma mémoire.", "Chaque flocon est un tableau que personne ne regarde.", "Je mélange du givre et des souvenirs."],
	"soupir": ["...", "Il neige même dans mes rêves.", "Bientôt, peut-être, le dégel.", "Une couleur de plus, et le monde respirera."],
}

var wind_phase: float = 0.0
var wind_str: float = 0.6

var touch_active: bool = false
var touch_origin: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO

var shadow_tex: Texture2D
var shadow_layer: Node2D

const POSTFX_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float contrast = 1.14;
uniform float saturation = 1.22;
uniform float brightness = 1.02;
uniform float vignette = 0.34;
void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	col *= brightness;
	col = (col - vec3(0.5)) * contrast + vec3(0.5);
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	vec2 d = SCREEN_UV - vec2(0.5);
	float vig = smoothstep(0.85, 0.16, dot(d, d) * 3.0);
	col *= mix(1.0, vig, vignette);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
"""


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_load_textures()
	_load_ground()
	orb_tex = _make_orb()
	shadow_tex = _make_shadow()
	for it in START_ITEMS:
		bag.append({"icon": it.icon, "name": it.name, "qty": it.qty})
	_build_ground_deco()
	shadow_layer = Node2D.new()
	add_child(shadow_layer)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	_create_player()
	_spawn_props()
	_build_interiors()
	_create_npcs()
	_create_trapdoor()
	_create_creatures()
	_load_dungeon_textures()
	dungeon_root = Node2D.new()
	dungeon_root.y_sort_enabled = true
	add_child(dungeon_root)
	_create_hud()
	_create_inventory()
	_create_particles()
	_create_postfx()
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
		_add_ground_shadow(pr.pos, pr.foot.x * 1.05)
		if String(pr.tex).contains("arbre"):
			sway_sprites.append({"spr": spr, "ph": randf() * TAU})


# ====================== INTERIEURS ======================
func _build_interiors() -> void:
	for i in range(ROOM_CENTERS.size()):
		var c: Vector2 = ROOM_CENTERS[i]
		var hf: Vector2 = ROOM_HALVES[i]
		_add_collision(c + Vector2(0, -hf.y), Vector2(hf.x * 2 + 12, 12))
		_add_collision(c + Vector2(0, hf.y), Vector2(hf.x * 2 + 12, 12))
		_add_collision(c + Vector2(-hf.x, 0), Vector2(12, hf.y * 2))
		_add_collision(c + Vector2(hf.x, 0), Vector2(12, hf.y * 2))
	_build_chambre(ROOM_CENTERS[0])
	_build_biblio(ROOM_CENTERS[1])
	_build_shop(ROOM_CENTERS[2])
	_build_auberge(ROOM_CENTERS[3])
	_build_throne(ROOM_CENTERS[4])


func _build_chambre(c: Vector2) -> void:
	_furni(c, "tapis", Vector2(0, 30), 135, false, Vector2.ZERO, -1)
	_furni(c, "lit", Vector2(-190, -90), 132, true, Vector2(112, 38))
	_furni(c, "commode", Vector2(-50, -135), 108, true, Vector2(92, 28))
	_furni(c, "biblio", Vector2(55, -138), 150, true, Vector2(72, 26))
	_furni(c, "armoire", Vector2(210, -100), 150, true, Vector2(72, 28))
	_furni(c, "bureau", Vector2(215, 20), 122, true, Vector2(92, 32))
	_furni(c, "table", Vector2(0, 55), 104, true, Vector2(92, 36))
	_furni(c, "tabouret", Vector2(0, 102), 76, true, Vector2(42, 22))
	_furni(c, "fauteuil", Vector2(205, 105), 118, true, Vector2(78, 34))
	_inter(c, "chest", "furniture/coffre", Vector2(-205, 100), 114, true, Vector2(78, 32),
		[{"icon": "cristal", "name": "Cristal", "qty": 2}, {"icon": "bourse", "name": "Bourse d'or", "qty": 1}])
	_inter(c, "item", "items/potion_soin", Vector2(140, 35), 30, false, Vector2.ZERO, [{"icon": "potion_soin", "name": "Potion de soin", "qty": 1}])
	_inter(c, "item", "items/cristal", Vector2(-35, 22), 26, false, Vector2.ZERO, [{"icon": "cristal", "name": "Cristal", "qty": 1}])
	_inter(c, "item", "items/pomme", Vector2(70, 78), 26, false, Vector2.ZERO, [{"icon": "pomme", "name": "Pomme", "qty": 1}])
	_inter(c, "item", "items/cle", Vector2(-130, -28), 26, false, Vector2.ZERO, [{"icon": "cle", "name": "Clé", "qty": 1}])


func _build_biblio(c: Vector2) -> void:
	_furni(c, "tapis", Vector2(0, 40), 210, false, Vector2.ZERO, -1)
	for x in [-440, -264, -88, 88, 264, 440]:
		_furni(c, "biblio", Vector2(x, -335), 165, true, Vector2(80, 26))
	_furni(c, "biblio", Vector2(-500, 90), 165, true, Vector2(80, 26))
	_furni(c, "biblio", Vector2(500, 90), 165, true, Vector2(80, 26))
	_furni(c, "bureau", Vector2(0, -170), 130, true, Vector2(100, 32))
	for tx in [-220, 220]:
		_furni(c, "table", Vector2(tx, 60), 104, true, Vector2(92, 36))
		_furni(c, "fauteuil", Vector2(tx - 95, 72), 116, true, Vector2(74, 32))
		_furni(c, "fauteuil", Vector2(tx + 95, 72), 116, true, Vector2(74, 32))
	_furni(c, "commode", Vector2(-500, -150), 108, true, Vector2(92, 28))
	_inter(c, "chest", "furniture/coffre", Vector2(470, 250), 116, true, Vector2(78, 32),
		[{"icon": "grimoire", "name": "Grimoire ancien", "qty": 1}, {"icon": "cristal", "name": "Cristal", "qty": 3}])
	_inter(c, "item", "items/grimoire", Vector2(0, -108), 32, false, Vector2.ZERO, [{"icon": "grimoire", "name": "Grimoire", "qty": 1}])
	_inter(c, "item", "items/cristal", Vector2(-220, 95), 26, false, Vector2.ZERO, [{"icon": "cristal", "name": "Cristal", "qty": 1}])
	_inter(c, "item", "items/cle", Vector2(220, 95), 26, false, Vector2.ZERO, [{"icon": "cle", "name": "Clé", "qty": 1}])
	_inter(c, "item", "items/potion_mana", Vector2(-500, -100), 28, false, Vector2.ZERO, [{"icon": "potion_mana", "name": "Potion de mana", "qty": 1}])


func _build_shop(c: Vector2) -> void:
	_furni(c, "shop_etag_apoth", Vector2(-330, -250), 150, true, Vector2(80, 26))
	_furni(c, "shop_etag_potions", Vector2(-170, -252), 150, true, Vector2(80, 26))
	_furni(c, "shop_etag_biens", Vector2(10, -252), 150, true, Vector2(80, 26))
	_furni(c, "shop_etag_pain", Vector2(180, -250), 150, true, Vector2(80, 26))
	_furni(c, "shop_etal_produce", Vector2(330, -245), 130, true, Vector2(90, 30))
	_furni(c, "shop_mannequin", Vector2(-400, -90), 140, true, Vector2(50, 26))
	_furni(c, "shop_portant", Vector2(-400, 90), 140, true, Vector2(80, 28))
	_furni(c, "shop_jouets", Vector2(400, -90), 140, true, Vector2(80, 28))
	_furni(c, "shop_bonsai", Vector2(400, 100), 120, true, Vector2(50, 24))
	_furni(c, "shop_ardoise", Vector2(-380, 205), 120, true, Vector2(50, 22))
	_furni(c, "shop_vitrine", Vector2(-200, 40), 100, true, Vector2(110, 32))
	_furni(c, "shop_comptoir", Vector2(0, 120), 120, true, Vector2(150, 40))
	_inter(c, "chest", "furniture/shop_coffre_mag", Vector2(350, -180), 120, true, Vector2(80, 32),
		[{"icon": "bourse", "name": "Bourse d'or", "qty": 3}, {"icon": "cristal", "name": "Cristal", "qty": 2}])
	_inter(c, "item", "items/potion_soin", Vector2(-200, 90), 30, false, Vector2.ZERO, [{"icon": "potion_soin", "name": "Potion de soin", "qty": 1}])
	_inter(c, "item", "items/cristal", Vector2(-40, 150), 28, false, Vector2.ZERO, [{"icon": "cristal", "name": "Cristal", "qty": 1}])
	_inter(c, "item", "items/pain", Vector2(180, -198), 28, false, Vector2.ZERO, [{"icon": "pain", "name": "Pain", "qty": 1}])
	_inter(c, "item", "items/pomme", Vector2(330, -192), 28, false, Vector2.ZERO, [{"icon": "pomme", "name": "Pomme", "qty": 1}])
	_inter(c, "item", "items/grimoire", Vector2(10, -198), 30, false, Vector2.ZERO, [{"icon": "grimoire", "name": "Grimoire", "qty": 1}])


func _build_auberge(c: Vector2) -> void:
	_furni(c, "tapis", Vector2(0, 30), 240, false, Vector2.ZERO, -1)
	for tp in [Vector2(-400, -110), Vector2(0, -110), Vector2(400, -110), Vector2(-400, 150), Vector2(0, 150), Vector2(400, 150)]:
		_furni(c, "table", tp, 104, true, Vector2(92, 36))
		_furni(c, "tabouret", tp + Vector2(-80, 6), 74, true, Vector2(40, 22))
		_furni(c, "tabouret", tp + Vector2(80, 6), 74, true, Vector2(40, 22))
	_furni(c, "commode", Vector2(-250, -370), 110, true, Vector2(92, 28))
	_furni(c, "biblio", Vector2(-460, -365), 160, true, Vector2(78, 26))
	_furni(c, "armoire", Vector2(250, -370), 150, true, Vector2(72, 28))
	_furni(c, "biblio", Vector2(460, -365), 160, true, Vector2(78, 26))
	_furni(c, "fauteuil", Vector2(-560, 260), 118, true, Vector2(74, 32))
	_furni(c, "fauteuil", Vector2(560, 260), 118, true, Vector2(74, 32))
	_inter(c, "chest", "furniture/coffre", Vector2(520, -280), 118, true, Vector2(78, 32),
		[{"icon": "bourse", "name": "Bourse d'or", "qty": 2}, {"icon": "pain", "name": "Pain", "qty": 3}])
	_inter(c, "item", "items/pain", Vector2(0, -130), 28, false, Vector2.ZERO, [{"icon": "pain", "name": "Pain", "qty": 1}])
	_inter(c, "item", "items/pomme", Vector2(-400, -130), 26, false, Vector2.ZERO, [{"icon": "pomme", "name": "Pomme", "qty": 1}])
	_inter(c, "item", "items/potion_soin", Vector2(400, -130), 28, false, Vector2.ZERO, [{"icon": "potion_soin", "name": "Potion de soin", "qty": 1}])
	_inter(c, "item", "items/bourse", Vector2(-560, 300), 28, false, Vector2.ZERO, [{"icon": "bourse", "name": "Bourse d'or", "qty": 1}])


func _create_npcs() -> void:
	_create_npc(2, Vector2(0, 55), "vendeuse", NpcBrainScript.new(), 120.0)
	_create_npc(4, Vector2(0, -150), "aldwin", NpcBrainScript.new(ALDWIN_GRAMMAR, 0.7), 150.0)
	_create_npc(3, Vector2(-200, 60), "peintre", NpcBrainScript.new(PEINTRE_GRAMMAR, 0.85), 135.0)


func _create_npc(room: int, rel: Vector2, name: String, brain, height: float) -> void:
	var pos := ROOM_CENTERS[room] + rel
	var node := Node2D.new()
	node.position = pos
	ysort.add_child(node)
	var frames := {"idle": [], "greet": [], "react": []}
	var sprite_node: Sprite2D = null
	var base_path := "res://assets/characters/%s.png" % name
	if ResourceLoader.exists(base_path):
		frames["idle"].append(load(base_path))
		for key in ["greet", "react"]:
			var i := 0
			while ResourceLoader.exists("res://assets/characters/%s_%s_%02d.png" % [name, key, i]):
				frames[key].append(load("res://assets/characters/%s_%s_%02d.png" % [name, key, i]))
				i += 1
		sprite_node = Sprite2D.new()
		var tex0: Texture2D = frames["idle"][0]
		sprite_node.texture = tex0
		var sc: float = height / float(tex0.get_height())
		sprite_node.scale = Vector2(sc, sc)
		sprite_node.offset = Vector2(0, -tex0.get_height() / 2.0)
		node.add_child(sprite_node)
	else:
		node.add_child(_placeholder_vendor())
	_add_child_shadow(node, 60.0)
	_add_collision(pos + Vector2(0, -12), Vector2(46, 24))
	npcs.append({"node": node, "sprite": sprite_node, "frames": frames, "brain": brain, "pos": pos, "room": room, "event": "", "cur": "idle", "fi": 0, "ft": 0.0, "playing": false, "fps": 16.0})


func _placeholder_vendor() -> Node2D:
	var n := Node2D.new()
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-26, -90), Vector2(26, -90), Vector2(34, 0), Vector2(-34, 0)])
	body.color = Color(0.45, 0.2, 0.55)
	n.add_child(body)
	var head := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 20 + Vector2(0, -112))
	head.polygon = pts
	head.color = Color(0.92, 0.78, 0.62)
	n.add_child(head)
	var hat := Polygon2D.new()
	hat.polygon = PackedVector2Array([Vector2(-28, -126), Vector2(28, -126), Vector2(0, -178)])
	hat.color = Color(0.4, 0.18, 0.5)
	n.add_child(hat)
	var tag := Label.new()
	tag.text = "Vendeuse (placeholder)"
	tag.position = Vector2(-95, -208)
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", Color(1, 1, 0.8))
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	tag.add_theme_constant_override("outline_size", 5)
	n.add_child(tag)
	return n


func _create_trapdoor() -> void:
	var cl := "res://assets/props/trap_closed.png"
	if not ResourceLoader.exists(cl):
		return
	var closed_tex: Texture2D = load(cl)
	var op := "res://assets/props/trap_open.png"
	var open_tex: Texture2D = load(op) if ResourceLoader.exists(op) else closed_tex
	var pos := Vector2(250, 280)
	var spr := Sprite2D.new()
	spr.texture = closed_tex
	var s: float = 150.0 / float(closed_tex.get_height())
	spr.scale = Vector2(s, s)
	spr.offset = Vector2(0, -closed_tex.get_height() / 2.0)
	spr.position = pos
	ysort.add_child(spr)
	trapdoor = {"sprite": spr, "pos": pos, "closed_tex": closed_tex, "open_tex": open_tex}


# ====================== CREATURES ERRANTES ======================
func _create_creatures() -> void:
	_create_creature(Vector2(-450, 600), "renard_braise", 105.0, 60.0)
	_create_creature(Vector2(820, 420), "chiot_cristal", 95.0, 50.0)
	_create_creature(Vector2(120, 820), "grenouille_brume", 90.0, 30.0)
	_create_creature(Vector2(-700, 120), "cerf_murmures", 140.0, 45.0)


func _create_creature(home: Vector2, slug: String, height: float, speed: float) -> void:
	var idle_path := "res://assets/monsters/%s/idle.png" % slug
	if not ResourceLoader.exists(idle_path):
		return
	var node := Node2D.new()
	node.position = home
	ysort.add_child(node)
	var walk: Array = []
	var i := 1
	while ResourceLoader.exists("res://assets/monsters/%s/walk_%02d.png" % [slug, i]):
		walk.append(load("res://assets/monsters/%s/walk_%02d.png" % [slug, i]))
		i += 1
	var idle_tex: Texture2D = load(idle_path)
	var spr := Sprite2D.new()
	spr.texture = idle_tex
	var sc: float = height / float(idle_tex.get_height())
	spr.scale = Vector2(sc, sc)
	spr.offset = Vector2(0, -idle_tex.get_height() / 2.0)
	node.add_child(spr)
	_add_child_shadow(node, height * 0.55)
	creatures.append({
		"node": node, "spr": spr, "idle": idle_tex, "walk": walk,
		"home": home, "target": home, "speed": speed,
		"state": "idle", "t": randf_range(1.0, 3.5), "ft": 0.0, "base_sc": sc
	})


func _update_creatures(delta: float) -> void:
	for c in creatures:
		var node: Node2D = c["node"]
		if inside or in_dungeon:
			node.visible = false
			continue
		node.visible = true
		var spr: Sprite2D = c["spr"]
		c["ft"] += delta
		if c["state"] == "idle":
			spr.texture = c["idle"]
			c["t"] -= delta
			if c["t"] <= 0.0:
				var ang := randf() * TAU
				var rad := randf_range(80.0, 260.0)
				c["target"] = c["home"] + Vector2(cos(ang), sin(ang)) * rad
				c["state"] = "walk"
				c["ft"] = 0.0
		else:
			var to: Vector2 = c["target"] - node.position
			var d: float = to.length()
			if d < 8.0:
				c["state"] = "idle"
				c["t"] = randf_range(1.5, 4.0)
				spr.texture = c["idle"]
			else:
				var dir: Vector2 = to / d
				node.position += dir * c["speed"] * delta
				var bsc: float = c["base_sc"]
				spr.scale.x = bsc if dir.x >= 0.0 else -bsc
				var wf: Array = c["walk"]
				if wf.size() > 0:
					spr.texture = wf[int(c["ft"] * 6.0) % wf.size()]


func _build_throne(c: Vector2) -> void:
	for ry in [150, 0, -150]:
		_furni(c, "tapis", Vector2(0, ry), 160, false, Vector2.ZERO, -1)
	_furni(c, "throne", Vector2(0, -255), 190, true, Vector2(86, 30))
	_furni(c, "candelabre", Vector2(-185, -258), 150, true, Vector2(70, 26))
	_furni(c, "candelabre", Vector2(185, -258), 150, true, Vector2(70, 26))
	_furni(c, "biblio", Vector2(-460, -250), 160, true, Vector2(78, 26))
	_furni(c, "biblio", Vector2(460, -250), 160, true, Vector2(78, 26))
	_furni(c, "commode", Vector2(-475, -30), 110, true, Vector2(92, 28))
	_furni(c, "commode", Vector2(475, -30), 110, true, Vector2(92, 28))
	_furni(c, "fauteuil", Vector2(-230, 90), 118, true, Vector2(78, 34))
	_furni(c, "fauteuil", Vector2(230, 90), 118, true, Vector2(78, 34))
	_furni(c, "fauteuil", Vector2(-445, 150), 118, true, Vector2(78, 34))
	var topen := "res://assets/props/trap_open.png"
	if ResourceLoader.exists(topen):
		var tex: Texture2D = load(topen)
		var spr := Sprite2D.new()
		spr.texture = tex
		var s: float = 150.0 / float(tex.get_height())
		spr.scale = Vector2(s, s)
		spr.offset = Vector2(0, -tex.get_height() / 2.0)
		spr.position = c + Vector2(0, 300)
		ysort.add_child(spr)
	_inter(c, "chest", "furniture/coffre", Vector2(445, 150), 114, true, Vector2(78, 32),
		[{"icon": "bourse", "name": "Bourse d'or", "qty": 5}, {"icon": "cristal", "name": "Cristal", "qty": 3}, {"icon": "grimoire", "name": "Grimoire ancien", "qty": 1}])
	_inter(c, "item", "items/cristal", Vector2(150, -90), 30, false, Vector2.ZERO, [{"icon": "cristal", "name": "Cristal", "qty": 1}])
	_inter(c, "item", "items/grimoire", Vector2(230, -100), 30, false, Vector2.ZERO, [{"icon": "grimoire", "name": "Grimoire", "qty": 1}])
	_inter(c, "item", "items/bourse", Vector2(-230, -100), 30, false, Vector2.ZERO, [{"icon": "bourse", "name": "Bourse d'or", "qty": 1}])
	_inter(c, "item", "items/cle", Vector2(0, 40), 28, false, Vector2.ZERO, [{"icon": "cle", "name": "Clé", "qty": 1}])


func _furni(center: Vector2, name: String, rel: Vector2, h: float, collide: bool, foot: Vector2, z: int = 0) -> void:
	var path := "res://assets/furniture/%s.png" % name
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var spr := Sprite2D.new()
	spr.texture = tex
	var s: float = h / float(tex.get_height())
	spr.scale = Vector2(s, s)
	spr.offset = Vector2(0, -tex.get_height() / 2.0)
	spr.position = center + rel
	spr.z_index = z
	ysort.add_child(spr)
	if collide:
		_add_collision(center + rel + Vector2(0, -foot.y / 2.0), foot)
		_add_ground_shadow(center + rel, foot.x * 1.05)


func _inter(center: Vector2, type: String, tex_path: String, rel: Vector2, h: float, collide: bool, foot: Vector2, loot: Array) -> void:
	var path := "res://assets/%s.png" % tex_path
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var spr := Sprite2D.new()
	spr.texture = tex
	var s: float = h / float(tex.get_height())
	spr.scale = Vector2(s, s)
	spr.offset = Vector2(0, -tex.get_height() / 2.0)
	spr.position = center + rel
	ysort.add_child(spr)
	if collide:
		_add_collision(center + rel + Vector2(0, -foot.y / 2.0), foot)
		_add_ground_shadow(center + rel, foot.x * 1.05)
	else:
		_add_ground_shadow(center + rel, 32.0)
	interactives.append({"type": type, "pos": center + rel, "spr": spr, "loot": loot, "taken": false})


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


func _make_shadow() -> Texture2D:
	var s := 96
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s / 2.0, s / 2.0)
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(c) / (s / 2.0)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * 0.95
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)


func _add_ground_shadow(pos: Vector2, width: float) -> void:
	if shadow_tex == null or shadow_layer == null:
		return
	var sh := Sprite2D.new()
	sh.texture = shadow_tex
	var sc := (width * 1.55) / float(shadow_tex.get_width())
	sh.scale = Vector2(sc, sc * 0.42)
	sh.position = pos + Vector2(0, -2)
	sh.modulate = Color(0, 0, 0, 0.30)
	shadow_layer.add_child(sh)


func _add_child_shadow(node: Node2D, width: float) -> void:
	if shadow_tex == null:
		return
	var sh := Sprite2D.new()
	sh.texture = shadow_tex
	var sc := (width * 1.55) / float(shadow_tex.get_width())
	sh.scale = Vector2(sc, sc * 0.42)
	sh.position = Vector2(0, -2)
	sh.z_index = -1
	sh.modulate = Color(0, 0, 0, 0.30)
	node.add_child(sh)


func _create_postfx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shd := Shader.new()
	shd.code = POSTFX_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shd
	rect.material = mat
	layer.add_child(rect)


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

	_add_child_shadow(player, 60.0)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	player.add_child(cam)
	cam.make_current()


func _set_cam_room(i: int) -> void:
	var c: Vector2 = ROOM_CENTERS[i]
	var hf: Vector2 = ROOM_HALVES[i]
	cam.limit_left = int(c.x - hf.x)
	cam.limit_right = int(c.x + hf.x)
	cam.limit_top = int(c.y - hf.y - 180.0)
	cam.limit_bottom = int(c.y + hf.y)


func _set_cam_free() -> void:
	cam.limit_left = -10000000
	cam.limit_right = 10000000
	cam.limit_top = -10000000
	cam.limit_bottom = 10000000


func _create_particles() -> void:
	if ResourceLoader.exists("res://assets/vfx/petal.png"):
		petals = CPUParticles2D.new()
		petals.texture = load("res://assets/vfx/petal.png")
		petals.amount = 22
		petals.lifetime = 8.0
		petals.preprocess = 4.0
		petals.local_coords = false
		petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		petals.emission_rect_extents = Vector2(360, 18)
		petals.position = Vector2(0, -200)
		petals.direction = Vector2(0.5, 1)
		petals.spread = 35.0
		petals.gravity = Vector2(7, 16)
		petals.initial_velocity_min = 12.0
		petals.initial_velocity_max = 34.0
		petals.angular_velocity_min = -70.0
		petals.angular_velocity_max = 70.0
		petals.scale_amount_min = 0.3
		petals.scale_amount_max = 0.7
		petals.color = Color(1, 1, 1, 0.85)
		cam.add_child(petals)
	if ResourceLoader.exists("res://assets/vfx/dust.png"):
		dust = CPUParticles2D.new()
		dust.texture = load("res://assets/vfx/dust.png")
		dust.amount = 16
		dust.lifetime = 6.0
		dust.preprocess = 3.0
		dust.local_coords = false
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.emission_rect_extents = Vector2(300, 175)
		dust.position = Vector2(0, 0)
		dust.direction = Vector2(0, -1)
		dust.spread = 60.0
		dust.gravity = Vector2(2, -4)
		dust.initial_velocity_min = 3.0
		dust.initial_velocity_max = 9.0
		dust.scale_amount_min = 0.4
		dust.scale_amount_max = 1.0
		dust.color = Color(1, 1, 0.92, 0.45)
		dust.emitting = false
		cam.add_child(dust)


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	var label := Label.new()
	label.text = "Sylvelinne — Aela"
	label.position = Vector2(24, 24)
	layer.add_child(label)

	var cast_btn := Button.new()
	cast_btn.text = "✨ Sort"
	cast_btn.add_theme_font_size_override("font_size", 48)
	cast_btn.size = Vector2(260, 150)
	cast_btn.position = Vector2(1540, 760)
	cast_btn.modulate = Color(1, 1, 1, 0.92)
	cast_btn.pressed.connect(_on_cast)
	layer.add_child(cast_btn)

	var sac_btn := Button.new()
	sac_btn.text = "Sac"
	sac_btn.add_theme_font_size_override("font_size", 44)
	sac_btn.size = Vector2(220, 96)
	sac_btn.position = Vector2(1580, 44)
	sac_btn.modulate = Color(1, 1, 1, 0.92)
	sac_btn.pressed.connect(_toggle_inventory)
	layer.add_child(sac_btn)

	enter_btn = Button.new()
	enter_btn.text = "Entrer"
	enter_btn.add_theme_font_size_override("font_size", 44)
	enter_btn.size = Vector2(280, 120)
	enter_btn.position = Vector2(810, 760)
	enter_btn.visible = false
	enter_btn.pressed.connect(_on_enter)
	layer.add_child(enter_btn)

	exit_btn = Button.new()
	exit_btn.text = "🚪 Sortir"
	exit_btn.add_theme_font_size_override("font_size", 44)
	exit_btn.size = Vector2(300, 130)
	exit_btn.position = Vector2(150, 760)
	exit_btn.visible = false
	exit_btn.pressed.connect(_on_exit)
	layer.add_child(exit_btn)

	act_btn = Button.new()
	act_btn.text = "Ramasser"
	act_btn.add_theme_font_size_override("font_size", 44)
	act_btn.size = Vector2(300, 120)
	act_btn.position = Vector2(810, 760)
	act_btn.visible = false
	act_btn.pressed.connect(_on_act)
	layer.add_child(act_btn)

	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 46)
	toast_label.modulate = Color(1, 1, 0.6)
	toast_label.position = Vector2(640, 200)
	toast_label.visible = false
	layer.add_child(toast_label)

	npc_say = Label.new()
	npc_say.position = Vector2(500, 30)
	npc_say.size = Vector2(920, 0)
	npc_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	npc_say.add_theme_font_size_override("font_size", 42)
	npc_say.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
	npc_say.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.12))
	npc_say.add_theme_constant_override("outline_size", 10)
	npc_say.visible = false
	layer.add_child(npc_say)


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
	if in_dungeon:
		if near_dstair == 0:
			_dungeon_change_floor(1)
		return
	if not inside and not in_dungeon and near_tree and near_house < 0 and not near_trap:
		_enter_dungeon()
		return
	if inside or (near_house < 0 and not near_trap):
		return
	inside = true
	var spawn_off: float
	if near_house < 0 and near_trap:
		current_room = 4
		return_pos = trapdoor.pos + Vector2(0, 50)
		if not trapdoor.is_empty():
			trapdoor.sprite.texture = trapdoor.open_tex
		spawn_off = ROOM_HALVES[4].y - 150
		exit_btn.text = "⬆️ Remonter"
	else:
		current_room = near_house
		return_pos = PROPS[near_house].pos + Vector2(0, 60)
		spawn_off = ROOM_HALVES[current_room].y - 46
		exit_btn.text = "🚪 Sortir"
	var c: Vector2 = ROOM_CENTERS[current_room]
	player.position = c + Vector2(0, spawn_off)
	player.velocity = Vector2.ZERO
	facing = "up"
	_set_cam_room(current_room)
	cam.reset_smoothing()
	if petals != null:
		petals.emitting = false
	if dust != null:
		dust.emitting = true
	enter_btn.visible = false
	exit_btn.visible = true


func _on_exit() -> void:
	if in_dungeon:
		if near_dstair == 1:
			_dungeon_change_floor(-1)
		elif near_dstair == 2:
			_exit_dungeon()
		return
	if not inside:
		return
	inside = false
	if current_room == 4 and not trapdoor.is_empty():
		trapdoor.sprite.texture = trapdoor.closed_tex
	player.position = return_pos
	player.velocity = Vector2.ZERO
	facing = "down"
	_set_cam_free()
	cam.reset_smoothing()
	if petals != null:
		petals.emitting = true
	if dust != null:
		dust.emitting = false
	exit_btn.visible = false
	act_btn.visible = false


func _on_act() -> void:
	if in_dungeon:
		_dungeon_act()
		return
	if near_interact < 0:
		return
	var o: Dictionary = interactives[near_interact]
	if o.taken:
		return
	o.taken = true
	if inside:
		for n in npcs:
			if n.room == current_room:
				n.event = "buy" if o.type == "chest" else "pick"
				break
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
	wind_phase += delta
	wind_str = 0.55 + 0.28 * sin(wind_phase * 0.6) + 0.14 * sin(wind_phase * 1.7 + 1.0)
	for sw in sway_sprites:
		sw.spr.rotation = sin(wind_phase * 1.6 + sw.ph) * wind_str * 0.025

	if toast_t > 0.0:
		toast_t -= delta
		if toast_t < 0.6:
			toast_label.modulate.a = clampf(toast_t / 0.6, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_label.visible = false

	var inv_open := inv_root != null and inv_root.visible
	if in_dungeon:
		_dungeon_proximity(delta, inv_open)
	elif inside:
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
		near_trap = false
		if not trapdoor.is_empty() and player.position.distance_to(trapdoor.pos) < 130.0:
			near_trap = true
		near_tree = false
		if player.position.distance_to(PROPS[4].pos) < 185.0:
			near_tree = true
		if near_house >= 0:
			enter_btn.text = "Entrer"
		elif near_trap:
			enter_btn.text = "⬇️ Descendre"
		elif near_tree:
			enter_btn.text = "🌳 Entrer dans l'Arbre"
		enter_btn.visible = (near_house >= 0 or near_trap or near_tree) and not inv_open

	var active_npc = null
	if inside:
		for n in npcs:
			if n.room == current_room:
				active_npc = n
				break
	for n in npcs:
		if n.sprite != null and n != active_npc:
			n.sprite.texture = n.frames["idle"][0]
	if active_npc != null:
		var vd := player.position.distance_to(active_npc.pos)
		var pp := {"near": vd < 190.0, "dist": vd, "interacted": active_npc.event != "", "event": (active_npc.event if active_npc.event != "" else "pick"), "dt": delta}
		var res: Dictionary = active_npc.brain.think(pp)
		active_npc.event = ""
		if res.line != null:
			npc_say.text = res.line
			npc_say.visible = true
			npc_say.modulate.a = 1.0
			npc_say_t = 4.5
			if active_npc.sprite != null and (res.state == "greet" or res.state == "react") and active_npc.frames[res.state].size() > 0:
				active_npc.cur = res.state
				active_npc.fi = 0
				active_npc.ft = 0.0
				active_npc.playing = true
		if active_npc.sprite != null:
			if active_npc.playing:
				active_npc.ft += delta
				var fi := int(active_npc.ft * active_npc.fps)
				if fi >= active_npc.frames[active_npc.cur].size():
					active_npc.playing = false
					active_npc.cur = "idle"
					fi = 0
				active_npc.fi = fi
				var seq: Array = active_npc.frames[active_npc.cur]
				if seq.size() > 0:
					active_npc.sprite.texture = seq[min(active_npc.fi, seq.size() - 1)]
			else:
				active_npc.sprite.texture = active_npc.frames["idle"][0]
	else:
		npc_say.visible = false
	if npc_say_t > 0.0:
		npc_say_t -= delta
		if npc_say_t < 0.8:
			npc_say.modulate.a = clampf(npc_say_t / 0.8, 0.0, 1.0)
		if npc_say_t <= 0.0:
			npc_say.visible = false

	_update_projectiles(delta)
	_update_creatures(delta)
	if in_dungeon:
		_update_dungeon_monsters(delta)
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
	if in_dungeon:
		_draw_dungeon()
		return
	# --- INTERIEURS (loin) ---
	for i in range(ROOM_CENTERS.size()):
		var c: Vector2 = ROOM_CENTERS[i]
		var hf: Vector2 = ROOM_HALVES[i]
		draw_rect(Rect2(c + Vector2(-hf.x - 120, -hf.y - 300), Vector2(hf.x * 2 + 240, hf.y * 2 + 420)), Color(0.09, 0.08, 0.13))
		if wall_tex != null:
			draw_texture_rect(wall_tex, Rect2(c + Vector2(-hf.x - 16, -hf.y - 180), Vector2(hf.x * 2 + 32, hf.y * 2 + 196)), true, ROOM_WALLTINT[i])
		else:
			draw_rect(Rect2(c + Vector2(-hf.x - 16, -hf.y - 180), Vector2(hf.x * 2 + 32, hf.y * 2 + 196)), Color(0.5, 0.45, 0.39))
		if floor_tex != null:
			draw_texture_rect(floor_tex, Rect2(c - hf, hf * 2.0), true, ROOM_FLOORTINT[i])
		else:
			draw_rect(Rect2(c - hf, hf * 2.0), Color(0.48, 0.33, 0.20))
		draw_rect(Rect2(c + Vector2(-hf.x, -hf.y), Vector2(hf.x * 2, 10)), Color(0, 0, 0, 0.18))
		draw_rect(Rect2(c + Vector2(-46, hf.y - 6), Vector2(92, 22)), Color(0.16, 0.11, 0.07))

	# --- EXTERIEUR ---
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


# ====================== DONJON ARBRE-MONDE ======================
const TILE: int = 128
const DUNGEON_ORIGIN: Vector2 = Vector2(-60000, -60000)
const DUNGEON_ZOOM: float = 2.0
const DUNGEON_FLOORS: Array = [
	[
		"#####################",
		"#v#K......#.........#",
		"#.#####.#.#.#######.#",
		"#.#...#.#.#.#....k#.#",
		"#.#.#.#.###.#.#####.#",
		"#.#.#.#..m..S.#...#.#",
		"#.#.#.#########.#L#.#",
		"#...#...........#...#",
		"###################.#",
		"#...#.......#.......#",
		"#.#.#.#####.#.#######",
		"#.#T#.#...#...#C....#",
		"#.###.#.#.#########.#",
		"#.........E.........#",
		"#####################"
	],
	[
		"#######################",
		"#.#.....#.........#C..#",
		"#.#.###.#####.###.###.#",
		"#...#.#.....#...#.....#",
		"###.#.#####.###.#####.#",
		"#kSG....#C#.#...#...#.#",
		"###.###.#.#.#.###.#.#.#",
		"#...#.....#...#...#...#",
		"#.###.###.#####.#######",
		"#...#.......#v#.#m..#P#",
		"###.#######.#.#.#.#.#.#",
		"#...#...#...#.#...#...#",
		"#.###.#.#.#..T#.#####.#",
		"#.....#.#.....#.......#",
		"#.#.###.#######.#.#.###",
		"#.....#....^....#.....#",
		"#######################"
	],
	[
		"#########################",
		"#.#.#........L....#...#C#",
		"#...#.#.###.#####.#.#.#.#",
		"#.#.#.#.....#...#...#...#",
		"#.#.#.#####.###.#######.#",
		"#.#...#...#.#...#..m#...#",
		"#.#.###.#.#.#...###.#.###",
		"#.#.....#.#.#.#...#.#.#.#",
		"#.#.#####.#.#.###.#.#.#.#",
		"#.#.#...#.#.#.T.#...#...#",
		"#.###.#.###.#.#.###.###.#",
		"#...#.#...#.#.#...#.#...#",
		"###.#.###.#.#.###.###.###",
		"#v#.#..T#...#...#m....#K#",
		"#.#.###.#####.#.#####.#.#",
		"#.......#...^...........#",
		"#########################"
	],
	[
		"###########################",
		"#v........#...#...........#",
		"#########.#.#.#.#######.#.#",
		"#......P#.#.#.#.m.#...#.#.#",
		"#.###.###.#.#####.#.#.#.###",
		"#.#k#.....#.#.....#.#.#...#",
		"#.#S#######.#.#####.#.###.#",
		"#...#.....#.........#.#.#.#",
		"###.#.###.###.#.#####.#.#.#",
		"#.#...#C#...#...#.......#.#",
		"#.#.###.###...#.#####.###.#",
		"#...#.....#...#.....#.#...#",
		"###.#.###.#########.#.#.###",
		"#...#.#.#.m.#.....#...#...#",
		"#.###.#.#.###.###.###.###.#",
		"#.#...#.#.#...#C#...#.....#",
		"#.#..##T#...#.#.###.#####.#",
		"#.......#....^.G..#....T..#",
		"###########################"
	],
	[
		"###########################",
		"#.#.......#T.....L..m.#...#",
		"#.###.###.#.#####.###.#.#.#",
		"#.....#C#.#.....#.#...#.#.#",
		"#.#.###.#.###.###.#.###.#.#",
		"#v..#.....#...#...#.#...#.#",
		"#####.#########.###.#####.#",
		"#..k#...#.......#.#...#...#",
		"#S#####.###.#####.#.#.#m###",
		"#.....#.....#.....#.#.....#",
		"#.###.#######.###.#.#.###.#",
		"#...........#.#.....#.....#",
		"###.#####.#.#T#.###.#####.#",
		"#...#.T...#...#.#...#.....#",
		"#.###.#######.#.#.###.#####",
		"#.#...#...#...#...#...#...#",
		"#.#.###.#.#.#.#.###.###.#.#",
		"#.#.#...#...#.....#...#C#.#",
		"#.#.#.###########.###.###.#",
		"#.#..........^.K#.......m.#",
		"###########################"
	],
	[
		"#############################",
		"#v....#......T#C........#...#",
		"#####.#####...###.#.###.#.###",
		"#...#.......#.....#.#P#.#...#",
		"##..###########.###.#.#.###.#",
		"#.......#.....#....m#...#...#",
		"#.#####.#.###.####.##.###..##",
		"#.#...#.#...#...#...#.#.....#",
		"#.###m#.###.###.#.#.#.#.###.#",
		"#.#...#...#.#.#.#...#.#C#T.G#",
		"#.#.#####.#.#.#.#.#.#.###.#.#",
		"#.#.........#.....#T#.....#.#",
		"#.#.#.###############.#.###.#",
		"#...#.....#m........#...#...#",
		"#.#.##.##.#.#.#####.#..##.###",
		"#.#.#.....#...#...#.#...#...#",
		"#.#.#######.###.#.#.#.#.###.#",
		"#.#.........#...#...#.#.#...#",
		"#.#######.###.#######.#.#.###",
		"#.............^.......#....C#",
		"#############################"
	],
	[
		"###############################",
		"#.#.....#.......#............T#",
		"#.#.###.###.#####.#####.#####.#",
		"#...#.#...#.....#.#...#.#...#.#",
		"#####.###.#.###.#.#.#.#.#.#.#.#",
		"#.....#...#.........#.#...#.#T#",
		"#.###.#.#####.#######.#####.#.#",
		"#...#C#.#k#...#...#.#...#...#.#",
		"#.#.###.#.#.###.#.#.#.###.###.#",
		"#.#.....#.#...#.#.#.#.#...#.#.#",
		"#.#######S###.#...#.#.#.###.#.#",
		"#.#...#K....#.#.#.#...#.#...#.#",
		"#.#.#.###.###.#.#.#####.#.###L#",
		"#.#.#...#...#.#.#...#...#....m#",
		"#.#.###.#.#.#.#.#.#.#.###.#####",
		"#.#.#...#.#.#.#...#.#.#.#..m#.#",
		"#.#.#T#####.#.##..#.#.#m###.#.#",
		"#.#.#.....#.m.#...#...#.T.#...#",
		"#.#.#####.#.###.#######.#.###.#",
		"#...#...#.#...#.....#v#.#.#...#",
		"#####.#.#.#########.#.#.#.#.###",
		"#.....#........^....#...#....C#",
		"###############################"
	],
	[
		"###############################",
		"#v#.......#.........#.........#",
		"#.#.#.###.#T#T###.#.#.###.#####",
		"#.#P#.#.#.#.....#.....#.#.....#",
		"#.###.#.#.#.#####.###.#.#####.#",
		"#.....#.#.#.....#.#kS...#.....#",
		"#######.#.#.###.#.#####.#.#####",
		"#.......#...#.#.#.....#.#...T.#",
		"#.#.#########.#.####..#.#####.#",
		"#...#.....#.....#...........#.#",
		"###.#.###...###########.#.#.#.#",
		"#...#.#...#.#.........#.#...#.#",
		"#.#.#.#.###.###.###.#.#.###.#.#",
		"#...#.#.....#...#C#...#.....#.#",
		"#.#.#.#######.###.#.#########.#",
		"#.#...#.......#.#...#...#.....#",
		"#m#####m#.#####.#.###.#.#.###.#",
		"#.....#.#.#.........#.#.#...#.#",
		"##.##.###.#########.#.#.###...#",
		"#T..#...#..........m..#...#.#.#",
		"#.#.###.#######.#########.#.#.#",
		"#.#C#.........#...#..C#...#.#.#",
		"#.###.###.#.#.###..G###.###.#.#",
		"#.........m....^..#.........#.#",
		"###############################"
	],
	[
		"#################################",
		"#.#.#.....L...........#...#.....#",
		"#.#.#.###.###########.#.###.###.#",
		"#.#.#.#...#...#v....#.#.#.....#.#",
		"#.#.#.#.#.#.#.#####.#.#.#.##T##.#",
		"#..m#..m#...#.....#.#...#.#T.m#.#",
		"#.#.###.#.#######.#.#.###.#.#.#.#",
		"#.#...#T#......C#.#...#...#.#.#.#",
		"#.#.###.###.#.###.#####.###.#.#.#",
		"#.#...#...#.#.#...#.m...#...#...#",
		"#.#.#.###.#...#.###.#####.#####.#",
		"#.#.#...#.#.#.#.....#...#...#.#.#",
		"#.###.###.###.#######.#.###.#.#.#",
		"#...#...#.#...#.......#...#.#T..#",
		"###.#.#...#.#.#.#####.#####.#.###",
		"#K#T#...#...#.#....C#.#.....#.#.#",
		"#.#.#...#####.#######.#.#####.#.#",
		"#...#.#.............#.#...#.....#",
		"#.###.##.########.#...###.#.#####",
		"#.#.........#...#.....#m..#.....#",
		"#.#.#######.#.###.#####.###.###.#",
		"#.#.#.......#.....#...........#.#",
		"#.#.###.###########...#.#######.#",
		"#.#...#.........#...#.#.........#",
		"#.###...#.#####.#.#.#.#######.#.#",
		"#.....#...#.....^.#...........#.#",
		"#################################"
	],
	[
		"###################################",
		"#B#.....#...#.m.....#.......#.....#",
		"#C###.#.#.###.#####.#.###.#.#.###.#",
		"#...m.#.#...#...#.....#k#.#...#...#",
		"#######.###.###.#.#####S#.#########",
		"#.#.....#...#...#...#...#.........#",
		"#.#.#####.###.###.#T#.#.#########.#",
		"#.#.#.............#...#..C#.....#.#",
		"#.#.#####.#####.###.m######.m##.#.#",
		"#.#...#..G#T..#.#.....#...#.....#.#",
		"#.###.#.#.#.#.#.#.##..#.#.###.#.#.#",
		"#...#...#...#.#.#.#...#.#.....#...#",
		"###.#########.###.#.###.###########",
		"#.....#.#...#.....#...#.....#.....#",
		"#.###.#.#.#.#########.#.###.#.#.#.#",
		"#...#..m#.#.........#.#....T#.#...#",
		"#.#.#####.###.#.#####.###.#.#.#.###",
		"#.#.......#...#...#...#.T.....#...#",
		"#T#########.#####.#.###.#########.#",
		"#.#...#...#.....#...#...#...#.....#",
		"#.#.#.#.#.#.#.#######.###.#.#.###.#",
		"#...#...#.#P#.......#.#...#...#...#",
		"#########.###.#.###.#.#.#######.###",
		"#...#...#...#.#.#.#.#.#.....#C#.#.#",
		"#.###.#.###.###.#.#.#######.#.#.#.#",
		"#...#.#.#...#...#.#.........#.#.#.#",
		"#.#.#.#.#.###.###.###########.#.#.#",
		"#.#...#.......#..^................#",
		"###################################"
	]
]

var in_dungeon: bool = false
var dungeon_floor: int = 0
var dungeon_root: Node2D
var dgrid: Array = []
var dcols: int = 0
var drows: int = 0
var dfeatures: Array = []
var dmonsters: Array = []
var d_has_key: bool = false
var d_lever: bool = false
var dungeon_return_pos: Vector2 = Vector2.ZERO
var near_tree: bool = false
var near_dstair: int = -1
var near_dfeat: int = -1
var near_dsearch: bool = false
var dtrap_cd: float = 0.0
var dfloor_tex: Texture2D
var dwall_tex: Texture2D
var stairs_down_tex: Texture2D
var stairs_up_tex: Texture2D
var door_tex: Texture2D
var gate_tex: Texture2D
var lever_tex: Texture2D


func _try_load(p: String) -> Texture2D:
	return load(p) if ResourceLoader.exists(p) else null


func _load_dungeon_textures() -> void:
	dfloor_tex = _try_load("res://assets/tilesets/dungeon_floor.png")
	dwall_tex = _try_load("res://assets/tilesets/dungeon_wall.png")
	stairs_down_tex = _try_load("res://assets/props/stairs_down.png")
	stairs_up_tex = _try_load("res://assets/props/stairs_up.png")
	door_tex = _try_load("res://assets/props/door_wood.png")
	gate_tex = _try_load("res://assets/props/gate_iron.png")
	lever_tex = _try_load("res://assets/props/lever.png")


func _cell_center(r: int, c: int) -> Vector2:
	return DUNGEON_ORIGIN + Vector2(c * TILE + TILE / 2.0, r * TILE + TILE / 2.0)


func _player_cell() -> Vector2i:
	var rel := player.position - DUNGEON_ORIGIN
	return Vector2i(int(floor(rel.x / TILE)), int(floor(rel.y / TILE)))


func _find_feature_cell(glyph: String) -> Vector2i:
	for r in range(drows):
		for c in range(dgrid[r].size()):
			if dgrid[r][c] == glyph:
				return Vector2i(c, r)
	return Vector2i(-1, -1)


func _dwall_collider(r: int, c: int) -> StaticBody2D:
	var sb := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(TILE, TILE)
	cs.shape = rs
	sb.add_child(cs)
	sb.position = _cell_center(r, c)
	dungeon_root.add_child(sb)
	return sb


func _dwall_band(r: int, c0: int, c1: int) -> StaticBody2D:
	var n := c1 - c0 + 1
	var sb := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(n * TILE, TILE)
	cs.shape = rs
	sb.add_child(cs)
	var cx := DUNGEON_ORIGIN.x + (c0 + c1 + 1) * TILE / 2.0
	var cy := DUNGEON_ORIGIN.y + r * TILE + TILE / 2.0
	sb.position = Vector2(cx, cy)
	dungeon_root.add_child(sb)
	return sb


func _load_item_tex(icon: String) -> Texture2D:
	for base in ["res://assets/items/%s.png", "res://assets/furniture/%s.png"]:
		var p: String = base % icon
		if ResourceLoader.exists(p):
			return load(p)
	return null


func _dfeat_sprite(tex: Texture2D, center: Vector2, height: float, upright: bool, tint: Color) -> Node2D:
	if tex == null:
		return null
	var node := Node2D.new()
	node.position = center
	var spr := Sprite2D.new()
	spr.texture = tex
	var sc: float = height / float(tex.get_height())
	spr.scale = Vector2(sc, sc)
	spr.modulate = tint
	if upright:
		spr.offset = Vector2(0, -tex.get_height() / 2.0)
		node.add_child(spr)
		_add_child_shadow(node, height * 0.5)
	else:
		node.add_child(spr)
	ysort.add_child(node)
	return node


func _dfeat_sprite_item(icon: String, center: Vector2, height: float, upright: bool = true, tint: Color = Color(1, 1, 1)) -> Node2D:
	return _dfeat_sprite(_load_item_tex(icon), center, height, upright, tint)


func _floor_mob_slug(n: int) -> String:
	var rota := ["araignee_racine", "esprit_sylve", "ourson_souche", "grenouille_brume",
		"hibou_statue", "sanglier_ronce", "esprit_sylve", "hibou_statue",
		"araignee_racine", "esprit_sylve"]
	if n >= 0 and n < rota.size():
		return rota[n]
	return "esprit_sylve"


func _chest_loot(n: int) -> Array:
	if n == 0:
		return [{"icon": "grimoire", "name": "Page d'Aldevane", "qty": 1}, {"icon": "potion_soin", "name": "Potion de soin", "qty": 1}]
	if n >= 8:
		return [{"icon": "grimoire", "name": "Larme d'Aldevane", "qty": 1}, {"icon": "cristal", "name": "Eclat de seve", "qty": 2}, {"icon": "potion_soin", "name": "Potion de soin", "qty": 2}]
	if n % 2 == 0:
		return [{"icon": "cristal", "name": "Eclat de seve", "qty": 1}, {"icon": "potion_soin", "name": "Potion de soin", "qty": 1}]
	return [{"icon": "bourse", "name": "Bourse de glands", "qty": 1}, {"icon": "potion_mana", "name": "Potion de mana", "qty": 1}]


func _spawn_dungeon_monster(r: int, c: int, slug: String, boss: bool) -> void:
	var home := _cell_center(r, c)
	var idle_path := "res://assets/monsters/%s/idle.png" % slug
	if not ResourceLoader.exists(idle_path):
		return
	var node := Node2D.new()
	node.position = home
	ysort.add_child(node)
	var walk: Array = []
	var i := 1
	while ResourceLoader.exists("res://assets/monsters/%s/walk_%02d.png" % [slug, i]):
		walk.append(load("res://assets/monsters/%s/walk_%02d.png" % [slug, i]))
		i += 1
	var itex: Texture2D = load(idle_path)
	var spr := Sprite2D.new()
	spr.texture = itex
	var hh: float = 185.0 if boss else 112.0
	var sc: float = hh / float(itex.get_height())
	spr.scale = Vector2(sc, sc)
	spr.offset = Vector2(0, -itex.get_height() / 2.0)
	node.add_child(spr)
	_add_child_shadow(node, hh * 0.5)
	if boss:
		var lbl := Label.new()
		lbl.text = "Gardien de Cendre"
		lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.55))
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.position = Vector2(-70, -hh - 30)
		node.add_child(lbl)
	dmonsters.append({"node": node, "spr": spr, "idle": itex, "walk": walk, "home": home, "target": home, "speed": 0.0 if boss else 42.0, "state": "idle", "t": randf_range(0.6, 2.5), "ft": 0.0, "base_sc": sc, "boss": boss})


func _clear_dungeon_floor() -> void:
	for f in dfeatures:
		if f.get("node") != null:
			f["node"].queue_free()
		if f.get("collider") != null:
			f["collider"].queue_free()
	for m in dmonsters:
		if m.get("node") != null:
			m["node"].queue_free()
	if dungeon_root != null:
		for ch in dungeon_root.get_children():
			ch.queue_free()
	dfeatures = []
	dmonsters = []


func _build_dungeon_floor(n: int, arrival_glyph: String) -> void:
	_clear_dungeon_floor()
	dungeon_floor = n
	d_lever = false
	var grid: Array = DUNGEON_FLOORS[n]
	dgrid = []
	for r in range(grid.size()):
		var row: String = grid[r]
		var arr: Array = []
		for c in range(row.length()):
			arr.append(row[c])
		dgrid.append(arr)
	drows = dgrid.size()
	dcols = 0
	for r in range(drows):
		dcols = max(dcols, dgrid[r].size())
	# Murs '#' : fusionnes en bandes horizontales (1 collider par segment)
	# au lieu d'un par case -> beaucoup moins de StaticBody2D sur les grands etages.
	for r in range(drows):
		var c0: int = -1
		var cc: int = 0
		while cc < dgrid[r].size():
			if dgrid[r][cc] == "#":
				if c0 < 0:
					c0 = cc
			else:
				if c0 >= 0:
					_dwall_band(r, c0, cc - 1)
					c0 = -1
			cc += 1
		if c0 >= 0:
			_dwall_band(r, c0, dgrid[r].size() - 1)
	for r in range(drows):
		for c in range(dgrid[r].size()):
			var ch: String = dgrid[r][c]
			var center := _cell_center(r, c)
			match ch:
				"S":
					var col := _dwall_collider(r, c)
					dfeatures.append({"kind": "secret", "r": r, "c": c, "pos": center, "node": null, "collider": col, "done": false})
				"E":
					var ne := _dfeat_sprite(stairs_up_tex, center, 112.0, false, Color(1.15, 1.0, 0.65))
					dfeatures.append({"kind": "exit", "r": r, "c": c, "pos": center, "node": ne})
				"v":
					var nd := _dfeat_sprite(stairs_down_tex, center, 120.0, false, Color(1, 1, 1))
					dfeatures.append({"kind": "down", "r": r, "c": c, "pos": center, "node": nd})
				"^":
					var nu := _dfeat_sprite(stairs_up_tex, center, 120.0, false, Color(1, 1, 1))
					dfeatures.append({"kind": "up", "r": r, "c": c, "pos": center, "node": nu})
				"L":
					var cl := _dwall_collider(r, c)
					var ndl := _dfeat_sprite(door_tex, center, 150.0, true, Color(1, 1, 1))
					dfeatures.append({"kind": "door", "r": r, "c": c, "pos": center, "node": ndl, "collider": cl, "done": false})
				"G":
					var cg := _dwall_collider(r, c)
					var ng := _dfeat_sprite(gate_tex, center, 150.0, true, Color(1, 1, 1))
					dfeatures.append({"kind": "gate", "r": r, "c": c, "pos": center, "node": ng, "collider": cg, "done": false})
				"K":
					var nk := _dfeat_sprite_item("cle", center, 56.0)
					dfeatures.append({"kind": "key", "r": r, "c": c, "pos": center, "node": nk, "done": false})
				"C":
					var nc := _dfeat_sprite_item("coffre", center, 80.0)
					dfeatures.append({"kind": "chest", "r": r, "c": c, "pos": center, "node": nc, "done": false, "loot": _chest_loot(n)})
				"k":
					var nt2 := _dfeat_sprite_item("coffre", center, 80.0, true, Color(1.15, 1.0, 0.55))
					dfeatures.append({"kind": "chest", "r": r, "c": c, "pos": center, "node": nt2, "done": false, "loot": [{"icon": "potion_soin", "name": "Elixir de seve", "qty": 2}]})
				"T":
					var ntp := _dfeat_sprite_item("piege", center, 96.0, false)
					dfeatures.append({"kind": "trap", "r": r, "c": c, "pos": center, "node": ntp, "armed": true})
				"P":
					var nlv := _dfeat_sprite(lever_tex, center, 112.0, true, Color(1, 1, 1))
					dfeatures.append({"kind": "lever", "r": r, "c": c, "pos": center, "node": nlv, "done": false})
				"m":
					_spawn_dungeon_monster(r, c, _floor_mob_slug(n), false)
				"B":
					_spawn_dungeon_monster(r, c, "sentinelle_cendre", true)
	var spawn := _find_feature_cell(arrival_glyph)
	if spawn.x >= 0:
		player.position = _cell_center(spawn.y, spawn.x)
	player.velocity = Vector2.ZERO
	facing = "down"
	cam.limit_left = int(DUNGEON_ORIGIN.x)
	cam.limit_top = int(DUNGEON_ORIGIN.y - 80.0)
	cam.limit_right = int(DUNGEON_ORIGIN.x + dcols * TILE)
	cam.limit_bottom = int(DUNGEON_ORIGIN.y + drows * TILE)
	cam.reset_smoothing()
	queue_redraw()


func _enter_dungeon() -> void:
	in_dungeon = true
	dungeon_floor = 0
	d_has_key = false
	dungeon_return_pos = PROPS[4].pos + Vector2(0, 70)
	cam.zoom = Vector2(DUNGEON_ZOOM, DUNGEON_ZOOM)
	if petals != null:
		petals.emitting = false
	if dust != null:
		dust.emitting = true
	enter_btn.visible = false
	_build_dungeon_floor(0, "E")
	_show_toast("Tu penetres dans l'Arbre-Monde...")


func _exit_dungeon() -> void:
	in_dungeon = false
	_clear_dungeon_floor()
	cam.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	_set_cam_free()
	player.position = dungeon_return_pos
	player.velocity = Vector2.ZERO
	facing = "down"
	cam.reset_smoothing()
	if petals != null:
		petals.emitting = true
	if dust != null:
		dust.emitting = false
	enter_btn.visible = false
	exit_btn.visible = false
	act_btn.visible = false
	queue_redraw()


func _dungeon_change_floor(delta: int) -> void:
	var nf := dungeon_floor + delta
	if nf < 0:
		_exit_dungeon()
		return
	if nf >= DUNGEON_FLOORS.size():
		_show_toast("Le passage est scelle...")
		return
	var arrival := "^" if delta > 0 else "v"
	cam.zoom = Vector2(DUNGEON_ZOOM, DUNGEON_ZOOM)
	_build_dungeon_floor(nf, arrival)
	_show_toast("Rez-de-chaussee" if nf == 0 else "Etage -%d" % nf)


func _open_dfeature(f: Dictionary) -> void:
	f["done"] = true
	if f.get("collider") != null:
		f["collider"].queue_free()
		f["collider"] = null
	if f.get("node") != null:
		f["node"].visible = false
	if f.has("r") and f.has("c"):
		dgrid[f["r"]][f["c"]] = "."
	queue_redraw()


func _draw_dungeon() -> void:
	var w := dcols * TILE
	var h := drows * TILE
	draw_rect(Rect2(DUNGEON_ORIGIN, Vector2(w, h)), Color(0.05, 0.05, 0.07))
	# Sol : un seul appel tuile sur tout l'etage (la texture fait 1 case).
	if dfloor_tex != null:
		draw_texture_rect(dfloor_tex, Rect2(DUNGEON_ORIGIN, Vector2(w, h)), true)
	# Murs : on ne dessine que les cases visibles a l'ecran (culling).
	var vp := get_viewport_rect().size
	var hw := vp.x / DUNGEON_ZOOM / 2.0
	var hh := vp.y / DUNGEON_ZOOM / 2.0
	var pcx := (player.position.x - DUNGEON_ORIGIN.x) / float(TILE)
	var pcy := (player.position.y - DUNGEON_ORIGIN.y) / float(TILE)
	var c0 := max(int(floor(pcx - hw / TILE)) - 2, 0)
	var c1 := min(int(ceil(pcx + hw / TILE)) + 2, dcols - 1)
	var r0 := max(int(floor(pcy - hh / TILE)) - 2, 0)
	var r1 := min(int(ceil(pcy + hh / TILE)) + 2, drows - 1)
	for r in range(r0, r1 + 1):
		var arr: Array = dgrid[r]
		var cmax: int = min(c1 + 1, arr.size())
		for c in range(c0, cmax):
			var ch: String = arr[c]
			if ch != "#" and ch != "S":
				continue
			var rect := Rect2(DUNGEON_ORIGIN + Vector2(c * TILE, r * TILE), Vector2(TILE, TILE))
			if dwall_tex != null:
				draw_texture_rect(dwall_tex, rect, false)
			else:
				draw_rect(rect, Color(0.16, 0.13, 0.11))


func _update_dungeon_monsters(delta: float) -> void:
	for m in dmonsters:
		var node: Node2D = m["node"]
		var spr: Sprite2D = m["spr"]
		m["ft"] += delta
		if m["boss"]:
			spr.texture = m["idle"]
			node.position.y = m["home"].y + sin(m["ft"] * 1.5) * 3.0
			continue
		if m["state"] == "idle":
			spr.texture = m["idle"]
			m["t"] -= delta
			if m["t"] <= 0.0:
				var ang := randf() * TAU
				var rad := randf_range(40.0, 140.0)
				m["target"] = m["home"] + Vector2(cos(ang), sin(ang)) * rad
				m["state"] = "walk"
				m["ft"] = 0.0
		else:
			var to: Vector2 = m["target"] - node.position
			var d: float = to.length()
			if d < 8.0:
				m["state"] = "idle"
				m["t"] = randf_range(0.8, 2.5)
				spr.texture = m["idle"]
			else:
				var dir: Vector2 = to / d
				node.position += dir * m["speed"] * delta
				var bsc: float = m["base_sc"]
				spr.scale.x = bsc if dir.x >= 0.0 else -bsc
				var wf: Array = m["walk"]
				if wf.size() > 0:
					spr.texture = wf[int(m["ft"] * 6.0) % wf.size()]


func _dungeon_trap_check(delta: float) -> void:
	if dtrap_cd > 0.0:
		dtrap_cd -= delta
		return
	var pc := _player_cell()
	for f in dfeatures:
		if f.kind == "trap" and f.get("armed", false):
			if f["r"] == pc.y and f["c"] == pc.x:
				dtrap_cd = 1.2
				_show_toast("Piege ! Tu es repousse.")
				var kb := player.position - f["pos"]
				if kb.length() < 1.0:
					kb = Vector2(0, 1)
				player.position += kb.normalized() * 72.0
				player.velocity = Vector2.ZERO
				break


func _dungeon_proximity(delta: float, inv_open: bool) -> void:
	near_dstair = -1
	near_dfeat = -1
	near_dsearch = false
	var ppos := player.position
	var best_stair := 99999.0
	for sf in dfeatures:
		if sf.kind == "down" or sf.kind == "up" or sf.kind == "exit":
			var ds: float = ppos.distance_to(sf["pos"])
			if ds < 95.0 and ds < best_stair:
				best_stair = ds
				near_dstair = 0 if sf.kind == "down" else (1 if sf.kind == "up" else 2)
	var best_feat := 112.0
	for i in range(dfeatures.size()):
		var af: Dictionary = dfeatures[i]
		if af.kind in ["key", "door", "gate", "chest", "lever"] and not af.get("done", false):
			var dfd: float = ppos.distance_to(af["pos"])
			if dfd < best_feat:
				best_feat = dfd
				near_dfeat = i
	if near_dfeat < 0:
		var pc := _player_cell()
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var rr := pc.y + off.y
			var cc := pc.x + off.x
			if rr >= 0 and rr < drows and cc >= 0 and cc < dgrid[rr].size():
				if dgrid[rr][cc] == "S":
					near_dsearch = true
					break
	enter_btn.visible = false
	exit_btn.visible = false
	if not inv_open:
		if near_dstair == 0:
			enter_btn.text = "Descendre"
			enter_btn.visible = true
		elif near_dstair == 1:
			exit_btn.text = "Monter"
			exit_btn.visible = true
		elif near_dstair == 2:
			exit_btn.text = "Sortir"
			exit_btn.visible = true
	if not inv_open and near_dfeat >= 0:
		var bf: Dictionary = dfeatures[near_dfeat]
		match bf.kind:
			"key":
				act_btn.text = "Ramasser la cle"
			"door":
				act_btn.text = "Deverrouiller" if d_has_key else "Porte verrouillee"
			"gate":
				act_btn.text = "Herse close"
			"chest":
				act_btn.text = "Ouvrir le coffre"
			"lever":
				act_btn.text = "Actionner le levier"
		act_btn.visible = true
	elif not inv_open and near_dsearch:
		act_btn.text = "Fouiller"
		act_btn.visible = true
	else:
		act_btn.visible = false
	_dungeon_trap_check(delta)


func _dungeon_act() -> void:
	if near_dfeat >= 0:
		var f: Dictionary = dfeatures[near_dfeat]
		match f.kind:
			"key":
				d_has_key = true
				f["done"] = true
				if f.get("node") != null:
					f["node"].visible = false
				_add_to_bag("cle", "Cle de l'Arbre", 1)
				_show_toast("Cle recuperee !")
			"door":
				if d_has_key:
					_open_dfeature(f)
					_show_toast("Porte deverrouillee")
				else:
					_show_toast("Il te faut une cle.")
			"gate":
				_show_toast("La herse est close. Cherche un mecanisme...")
			"chest":
				f["done"] = true
				if f.get("node") != null:
					f["node"].modulate = Color(0.7, 0.7, 0.7)
				var msg := ""
				for l in f["loot"]:
					_add_to_bag(l.icon, l.name, l.qty)
					msg += "+%d %s  " % [l.qty, l.name]
				_show_toast(msg)
			"lever":
				if not d_lever:
					d_lever = true
					f["done"] = true
					if f.get("node") != null:
						f["node"].modulate = Color(0.75, 1.0, 0.75)
					_show_toast("Un grondement... la herse s'ouvre !")
					for g in dfeatures:
						if g.kind == "gate":
							_open_dfeature(g)
		near_dfeat = -1
		act_btn.visible = false
		return
	if near_dsearch:
		var pc := _player_cell()
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var rr := pc.y + off.y
			var cc := pc.x + off.x
			if rr >= 0 and rr < drows and cc >= 0 and cc < dgrid[rr].size() and dgrid[rr][cc] == "S":
				dgrid[rr][cc] = "."
				for fe in dfeatures:
					if fe.kind == "secret" and fe["r"] == rr and fe["c"] == cc:
						if fe.get("collider") != null:
							fe["collider"].queue_free()
							fe["collider"] = null
						fe["done"] = true
						break
				_show_toast("Passage secret decouvert !")
				queue_redraw()
				near_dsearch = false
				act_btn.visible = false
				return
