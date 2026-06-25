class_name NpcBrain
extends RefCounted

# =====================================================================
#  Cerveau IA réutilisable pour PNJ  (port GDScript du projet mini-ia-pnj)
#  PERCEPTION -> MEMOIRE -> DECISION (arbre de comportement) -> ETAT + REPLIQUE
#  Aucune dépendance, ne dessine rien : le jeu fournit une perception
#  et reçoit {state, line}. Réutilisable pour n'importe quel personnage.
# =====================================================================

# ---------- 1. Mini-bibliothèque d'arbre de comportement ----------
class Noeud:
	func evaluer(_ctx) -> bool:
		return false

class Condition extends Noeud:
	var test: Callable
	func _init(t: Callable) -> void:
		test = t
	func evaluer(ctx) -> bool:
		return test.call(ctx)

class Action extends Noeud:
	var effet: Callable
	func _init(e: Callable) -> void:
		effet = e
	func evaluer(ctx) -> bool:
		effet.call(ctx)
		return true

class Sequence extends Noeud:        # ET : s'arrête au premier échec
	var enfants: Array
	func _init(e: Array) -> void:
		enfants = e
	func evaluer(ctx) -> bool:
		for n in enfants:
			if not n.evaluer(ctx):
				return false
		return true

class Selecteur extends Noeud:       # OU (priorité) : garde le premier succès
	var enfants: Array
	func _init(e: Array) -> void:
		enfants = e
	func evaluer(ctx) -> bool:
		for n in enfants:
			if n.evaluer(ctx):
				return true
		return false


# ---------- 2. Grammaire par défaut : la vendeuse excentrique ----------
# Des modèles par état, troués de {symboles}, et des listes de mots par symbole.
# Chaque {trou} est remplacé au hasard -> des dizaines de répliques uniques.
const DEFAULT_GRAMMAR: Dictionary = {
	"greet_new": [
		"Bienvenue chez {shop} ! {garde}",
		"Ah, une cliente ! {invite}",
		"Entre, entre... mais {garde}",
	],
	"greet_return": [
		"Re-toi ! {invite}",
		"Encore là ? {taquin}",
		"Ma cliente préférée revient ! {invite}",
	],
	"chat": [
		"{obs} {aparte}",
		"{obs}",
		"Psst... {secret}",
	],
	"react_pick": [
		"{reac_pick} {clin}",
		"Hé, {reac_pick2}",
	],
	"react_buy": [
		"Excellent choix ! {clin}",
		"Vendu ! {benediction}",
	],
	"shop": ["Twisted Trinkets", "mon petit bazar", "l'antre des merveilles", "la caverne aux curiosités"],
	"garde": [
		"ne touche pas au chaudron qui chuchote.",
		"les effets secondaires sont... festifs.",
		"tout est presque garanti !",
		"certains objets mordent, je préviens.",
	],
	"invite": [
		"Fais comme chez toi, mais ne réveille pas les cristaux.",
		"Regarde, touche, émerveille-toi !",
		"J'ai reçu un arrivage... douteux. Tu vas adorer.",
	],
	"taquin": [
		"Tu n'as pas assez dépensé la dernière fois.",
		"Le miroir t'a reconnue, lui.",
		"Je t'avais dit que tu reviendrais.",
	],
	"obs": [
		"Tu sens cette odeur ? C'est de la chance en poudre.",
		"Ce cristal m'a parlé ce matin. Il bégaie.",
		"Une potion s'est encore évadée cette nuit.",
		"Le gobelin recompte les bouteilles. Très mal.",
	],
	"aparte": ["(Ne le répète pas.)", "Enfin, je crois.", "...ou pas.", "C'est entre nous."],
	"secret": [
		"la fiole violette porte chance. Ou malheur. J'oublie.",
		"le tapis vole, mais seulement le mardi.",
		"ne paie jamais en boutons. Plus jamais.",
	],
	"reac_pick": ["Bon goût !", "Ohh, celui-là est spécial.", "Tu as l'œil, toi."],
	"reac_pick2": ["repose ça... ou garde-le, vis ta vie.", "celui-là chuchote la nuit, paraît-il."],
	"clin": ["*clin d'œil*", "héhé.", "*sourire mystérieux*"],
	"benediction": ["Que la poussière d'étoile t'accompagne !", "Pas de remboursement, hein !"],
}


# ---------- 3. État, mémoire, personnalité ----------
var bavardage: float = 0.85        # 0 = muette, 1 = commente tout
var grammar: Dictionary = {}
var state: String = "idle"

# mémoire
var mem_seen: bool = false
var mem_greeted: bool = false      # déjà saluée pendant CETTE visite
var mem_visits: int = 0
var away: float = 0.0
var chat_cd: float = 0.0

# perception courante (remplie à chaque think)
var perc_near: bool = false
var perc_dist: float = 999.0
var perc_interacted: bool = false
var perc_event: String = "pick"

var tree: Noeud


func _init(grammaire: Dictionary = {}, bavardage_val: float = 0.85) -> void:
	grammar = grammaire if not grammaire.is_empty() else DEFAULT_GRAMMAR
	bavardage = bavardage_val
	tree = _build_tree()


# L'INTELLIGENCE, lisible de haut en bas, par priorité :
#   1. on vient d'interagir avec moi -> je réagis
#   2. le joueur est là et pas encore salué -> je salue
#   3. le joueur traîne -> je papote (selon bavardage + délai)
#   4. sinon -> je vaque (idle)
func _build_tree() -> Noeud:
	var just_interacted := func(ctx): return ctx.perc_interacted
	var should_greet := func(ctx): return ctx.perc_near and not ctx.mem_greeted
	var should_chat := func(ctx):
		return ctx.perc_near and ctx.chat_cd <= 0.0 and randf() < ctx.bavardage
	var set_react := func(ctx):
		ctx.state = "react"
	var set_greet := func(ctx):
		ctx.state = "greet"
	var set_chat := func(ctx):
		ctx.state = "chat"
	var set_idle := func(ctx):
		ctx.state = "idle"
	return Selecteur.new([
		Sequence.new([Condition.new(just_interacted), Action.new(set_react)]),
		Sequence.new([Condition.new(should_greet), Action.new(set_greet)]),
		Sequence.new([Condition.new(should_chat), Action.new(set_chat)]),
		Action.new(set_idle),
	])


# Appelé à chaque frame. p = {near, dist, interacted, event, dt}
# Renvoie {state, line} (line peut être null).
func think(p: Dictionary) -> Dictionary:
	perc_near = p.get("near", false)
	perc_dist = p.get("dist", 999.0)
	perc_interacted = p.get("interacted", false)
	perc_event = p.get("event", "pick")
	var dt: float = p.get("dt", 0.016)

	# --- mémoire ---
	if chat_cd > 0.0:
		chat_cd -= dt
	if perc_near:
		mem_seen = true
		away = 0.0
	else:
		away += dt
		if away > 1.2:                 # le joueur est parti -> la visite se termine
			mem_greeted = false

	# --- décision ---
	tree.evaluer(self)

	# --- réplique ---
	var line = null
	if state == "react" and perc_interacted:
		line = _say("react_buy" if perc_event == "buy" else "react_pick")
	elif state == "greet" and not mem_greeted:
		mem_greeted = true
		mem_visits += 1
		line = _say("greet_new" if mem_visits <= 1 else "greet_return")
	elif state == "chat":
		chat_cd = randf_range(6.0, 11.0)
		line = _say("chat")
	return {"state": state, "line": line}


# ---------- 4. Dialogue procédural (grammaire à trous) ----------
func _say(cle: String) -> Variant:
	var modeles: Array = grammar.get(cle, [])
	if modeles.is_empty():
		return null
	return _expand(modeles[randi() % modeles.size()])


func _expand(s: String) -> String:
	var garde := 0
	while s.find("{") != -1 and garde < 30:
		garde += 1
		var a := s.find("{")
		var b := s.find("}", a)
		if b == -1:
			break
		var sym := s.substr(a + 1, b - a - 1)
		var opts: Array = grammar.get(sym, [sym])
		var mot: String = opts[randi() % opts.size()]
		s = s.substr(0, a) + mot + s.substr(b + 1)
	return s
