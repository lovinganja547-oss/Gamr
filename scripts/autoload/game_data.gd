extends Node
## Données statiques du jeu (races, objets, commandes, compétitions, succès…).
## Toutes les chaînes affichées passent par tr() côté interface.

const SAVE_VERSION := 3
const NEED_KEYS: Array[String] = ["hunger", "thirst", "clean", "energy", "mood", "health", "outside", "affection"]
const NEED_NAMES := {
	"hunger": "Faim", "thirst": "Soif", "clean": "Propreté", "energy": "Énergie",
	"mood": "Bonheur", "health": "Santé", "outside": "Sortir", "affection": "Câlins",
}
const NEED_ICONS := {
	"hunger": "hunger", "thirst": "thirst", "clean": "clean", "energy": "energy",
	"mood": "mood", "health": "health", "outside": "outside", "affection": "affection",
}
const NEED_COLORS := {
	"hunger": Color(0.96, 0.6, 0.3), "thirst": Color(0.35, 0.7, 0.98), "clean": Color(0.55, 0.85, 0.95),
	"energy": Color(0.98, 0.85, 0.3), "mood": Color(0.65, 0.85, 0.4), "health": Color(0.95, 0.4, 0.45), "outside": Color(0.45, 0.75, 0.45),
	"affection": Color(0.95, 0.5, 0.75),
}

# ------------------------------------------------------------------ Races
# Proportions en mètres (échelle « jouet »). pattern = motif de pelage procédural.
const BREEDS := {
	"labrador": {
		"name": "Labrador", "species": "dog", "voice": "bark_mid",
		"desc": "Gentil et gourmand, il adore rapporter tout ce qu'on lui lance.",
		"body": Vector3(0.3, 0.28, 0.62), "leg_len": 0.3, "leg_rad": 0.06, "head": 0.18,
		"snout": Vector2(0.19, 0.085), "ear": "floppy", "ear_size": 0.11, "tail": "otter",
		"pattern": "solid", "scale": 1.0,
		"palettes": [
			{"name": "Sable", "main": Color(0.93, 0.78, 0.52), "second": Color(0.98, 0.9, 0.74)},
			{"name": "Chocolat", "main": Color(0.42, 0.26, 0.17), "second": Color(0.52, 0.34, 0.23)},
			{"name": "Réglisse", "main": Color(0.16, 0.15, 0.16), "second": Color(0.24, 0.22, 0.23)},
			{"name": "Crème", "main": Color(0.97, 0.9, 0.78), "second": Color(1.0, 0.96, 0.9)},
		],
		"stats": {"agility": 55, "nose": 70, "intelligence": 70, "stamina": 70},
		"traits": {"energy": 65, "obedience": 70, "curiosity": 55, "affection": 85, "gluttony": 85, "independence": 20},
	},
	"shiba": {
		"name": "Shiba Inu", "species": "dog", "voice": "yip",
		"desc": "Fier et malicieux, il obéit… quand il en a envie.",
		"body": Vector3(0.24, 0.23, 0.48), "leg_len": 0.24, "leg_rad": 0.048, "head": 0.158,
		"snout": Vector2(0.135, 0.066), "ear": "pointy", "ear_size": 0.085, "tail": "curl",
		"pattern": "shiba", "scale": 0.92,
		"palettes": [
			{"name": "Roux", "main": Color(0.88, 0.5, 0.22), "second": Color(0.99, 0.94, 0.85)},
			{"name": "Sésame", "main": Color(0.72, 0.45, 0.25), "second": Color(0.97, 0.9, 0.8)},
			{"name": "Noir & feu", "main": Color(0.17, 0.14, 0.13), "second": Color(0.96, 0.86, 0.72)},
			{"name": "Crème", "main": Color(0.96, 0.88, 0.74), "second": Color(1.0, 0.97, 0.92)},
		],
		"stats": {"agility": 75, "nose": 65, "intelligence": 65, "stamina": 65},
		"traits": {"energy": 70, "obedience": 35, "curiosity": 75, "affection": 45, "gluttony": 50, "independence": 80},
	},
	"poodle": {
		"name": "Caniche", "species": "dog", "voice": "bark_small",
		"desc": "Élégant et très vif d'esprit, il apprend les tours en un clin d'œil.",
		"body": Vector3(0.21, 0.24, 0.42), "leg_len": 0.32, "leg_rad": 0.042, "head": 0.148,
		"snout": Vector2(0.16, 0.056), "ear": "fluffy", "ear_size": 0.09, "tail": "pompom",
		"pattern": "poodle", "scale": 0.95,
		"palettes": [
			{"name": "Abricot", "main": Color(0.95, 0.72, 0.5), "second": Color(0.98, 0.8, 0.62)},
			{"name": "Blanc", "main": Color(0.97, 0.96, 0.94), "second": Color(1, 1, 1)},
			{"name": "Gris", "main": Color(0.6, 0.6, 0.63), "second": Color(0.7, 0.7, 0.73)},
			{"name": "Noir", "main": Color(0.14, 0.13, 0.15), "second": Color(0.2, 0.2, 0.22)},
		],
		"stats": {"agility": 70, "nose": 55, "intelligence": 90, "stamina": 55},
		"traits": {"energy": 60, "obedience": 80, "curiosity": 60, "affection": 70, "gluttony": 45, "independence": 30},
	},
	"shepherd": {
		"name": "Berger allemand", "species": "dog", "voice": "bark_big",
		"desc": "Courageux et appliqué, un partenaire idéal pour l'obéissance et le pistage.",
		"body": Vector3(0.29, 0.28, 0.66), "leg_len": 0.33, "leg_rad": 0.06, "head": 0.175,
		"snout": Vector2(0.215, 0.076), "ear": "pointy", "ear_size": 0.12, "tail": "bushy",
		"pattern": "saddle", "scale": 1.05,
		"palettes": [
			{"name": "Feu & noir", "main": Color(0.78, 0.52, 0.28), "second": Color(0.14, 0.12, 0.12)},
			{"name": "Sable", "main": Color(0.76, 0.64, 0.45), "second": Color(0.3, 0.26, 0.22)},
			{"name": "Noir", "main": Color(0.15, 0.14, 0.14), "second": Color(0.1, 0.1, 0.1)},
			{"name": "Blanc", "main": Color(0.96, 0.94, 0.9), "second": Color(0.9, 0.86, 0.8)},
		],
		"stats": {"agility": 70, "nose": 85, "intelligence": 80, "stamina": 80},
		"traits": {"energy": 75, "obedience": 85, "curiosity": 60, "affection": 60, "gluttony": 55, "independence": 35},
	},
	"beagle": {
		"name": "Beagle", "species": "dog", "voice": "bark_mid",
		"desc": "Un nez exceptionnel et une curiosité sans limite. Un peu distrait…",
		"body": Vector3(0.24, 0.23, 0.5), "leg_len": 0.22, "leg_rad": 0.05, "head": 0.162,
		"snout": Vector2(0.155, 0.064), "ear": "long", "ear_size": 0.13, "tail": "whip",
		"pattern": "beagle", "scale": 0.9,
		"palettes": [
			{"name": "Tricolore", "main": Color(0.82, 0.55, 0.3), "second": Color(0.15, 0.13, 0.12)},
			{"name": "Citron", "main": Color(0.93, 0.8, 0.55), "second": Color(0.85, 0.66, 0.42)},
			{"name": "Rouge", "main": Color(0.72, 0.38, 0.2), "second": Color(0.6, 0.3, 0.16)},
			{"name": "Bleu", "main": Color(0.75, 0.6, 0.45), "second": Color(0.4, 0.42, 0.48)},
		],
		"stats": {"agility": 60, "nose": 95, "intelligence": 60, "stamina": 70},
		"traits": {"energy": 75, "obedience": 45, "curiosity": 95, "affection": 75, "gluttony": 90, "independence": 50},
	},
	"cat": {
		"name": "Chat domestique", "species": "cat", "voice": "meow",
		"desc": "Indépendant et câlin à ses heures. Il apprend à son rythme.",
		"body": Vector3(0.18, 0.19, 0.44), "leg_len": 0.2, "leg_rad": 0.036, "head": 0.142,
		"snout": Vector2(0.05, 0.06), "ear": "cat", "ear_size": 0.075, "tail": "cat",
		"pattern": "tabby", "scale": 0.85,
		"palettes": [
			{"name": "Tigré roux", "main": Color(0.93, 0.6, 0.3), "second": Color(0.75, 0.4, 0.18)},
			{"name": "Tigré gris", "main": Color(0.62, 0.62, 0.62), "second": Color(0.35, 0.35, 0.38)},
			{"name": "Noir", "main": Color(0.12, 0.12, 0.14), "second": Color(0.18, 0.18, 0.2)},
			{"name": "Blanc", "main": Color(0.97, 0.97, 0.97), "second": Color(0.88, 0.88, 0.9)},
			{"name": "Siamois", "main": Color(0.95, 0.9, 0.8), "second": Color(0.36, 0.26, 0.2), "points": true},
		],
		"stats": {"agility": 90, "nose": 70, "intelligence": 65, "stamina": 50},
		"traits": {"energy": 55, "obedience": 25, "curiosity": 80, "affection": 55, "gluttony": 60, "independence": 90},
	},
}
const BREED_ORDER: Array[String] = ["labrador", "shiba", "poodle", "shepherd", "beagle", "cat"]

const EYE_COLORS := [Color(0.28, 0.17, 0.1), Color(0.12, 0.1, 0.1), Color(0.35, 0.55, 0.85), Color(0.45, 0.65, 0.25), Color(0.85, 0.6, 0.15)]
const EYE_NAMES := ["Noisette", "Ébène", "Azur", "Émeraude", "Ambre"]

const TEMPERAMENTS := {
	"joueur": {"name": "Joueur", "desc": "Toujours partant pour jouer : il rapporte plus volontiers.", "mod": {"energy": 10, "obedience": -5}},
	"calme": {"name": "Calme", "desc": "Posé, il se fatigue moins vite et reste concentré.", "mod": {"energy": -15, "obedience": 10}},
	"curieux": {"name": "Curieux", "desc": "Il fourre sa truffe partout : excellent à la recherche.", "mod": {"curiosity": 20}},
	"energique": {"name": "Énergique", "desc": "Infatigable, mais il a souvent besoin de sortir.", "mod": {"energy": 20, "independence": 5}},
	"affectueux": {"name": "Affectueux", "desc": "Il adore les câlins et s'attache vite.", "mod": {"affection": 20}},
	"timide": {"name": "Timide", "desc": "Réservé au début, il faut gagner sa confiance en douceur.", "mod": {"independence": 10, "affection": 5, "obedience": 5}},
}
## Anciens tempéraments (sauvegarde v1) -> nouveaux
const TEMPERAMENT_MIGRATION := {"tetu": "energique", "calin": "affectueux", "gourmand": "curieux"}

# ------------------------------------------------------------------ Énergie (coût par activité, avant modificateurs)
const ENERGY_COST := {
	"calm": 1.0, "train_rep": 0.35, "fetch_throw": 1.2, "tug": 2.0, "search": 3.0,
	"walk_km": 9.0, "agility": 6.0, "competition": 6.0,
}

# ------------------------------------------------------------------ Niveaux de l'animal
const MAX_PET_LEVEL := 30
static func pet_xp_for_level(lv: int) -> int:
	return int(round(60.0 * pow(float(lv), 1.35)))

## Activités débloquées par le niveau de l'animal.
const ACTIVITY_LEVELS := {"fetch": 1, "walk": 1, "search": 2, "tug": 2, "agility": 3, "competition": 4, "photo": 1, "brush": 1}
const ACTIVITY_NAMES := {"fetch": "Lancer de balle", "walk": "Promenade", "search": "Jeu de recherche", "tug": "Tir à la corde", "agility": "Parcours d'agilité", "competition": "Concours", "photo": "Mode photo", "brush": "Brossage"}

# ------------------------------------------------------------------ Commandes
# gesture : séquence de directions (U/D/L/R), "O" = cercle, "TT" = double tape.
const COMMANDS := {
	"sit": {"name": "Assis", "gesture": "D", "hint": "Glissez vers le bas", "difficulty": 1.0, "words": ["assis", "assieds"], "level": 1},
	"down": {"name": "Couché", "gesture": "DR", "hint": "Bas puis droite", "difficulty": 1.2, "words": ["couché", "couche"], "level": 1},
	"stand": {"name": "Debout", "gesture": "U", "hint": "Glissez vers le haut", "difficulty": 1.1, "words": ["debout"], "level": 1},
	"come": {"name": "Viens", "gesture": "TT", "hint": "Tapez deux fois", "difficulty": 1.0, "words": ["viens", "ici"], "level": 1},
	"stay": {"name": "Reste", "gesture": "UD", "hint": "Haut puis bas", "difficulty": 1.3, "words": ["reste", "pas bouger"], "level": 2},
	"paw": {"name": "Donne la patte", "gesture": "R", "hint": "Glissez vers la droite", "difficulty": 1.4, "words": ["patte"], "level": 2},
	"fetch": {"name": "Rapporte", "gesture": "L", "hint": "Glissez vers la gauche", "difficulty": 1.5, "words": ["rapporte"], "level": 2},
	"spin": {"name": "Tourne", "gesture": "O", "hint": "Dessinez un cercle", "difficulty": 1.6, "words": ["tourne"], "level": 3},
	"jump": {"name": "Saute", "gesture": "DU", "hint": "Bas puis haut", "difficulty": 1.8, "words": ["saute", "hop"], "level": 4},
	"beg": {"name": "Fais le beau", "gesture": "UDU", "hint": "Haut, bas, haut", "difficulty": 2.0, "words": ["beau"], "level": 5},
}
const COMMAND_ORDER: Array[String] = ["sit", "down", "stand", "come", "stay", "paw", "fetch", "spin", "jump", "beg"]
const SKILL_LEARNED := 50.0
const SKILL_MASTERED := 85.0

static func skill_label(v: float) -> String:
	if v >= SKILL_MASTERED: return "Maîtrisé"
	if v >= SKILL_LEARNED: return "Connu"
	if v >= 20.0: return "En apprentissage"
	return "Inconnu"

# ------------------------------------------------------------------ Objets
# cat : food, treat, toy, collar, accessory, deco, care
const ITEMS := {
	# Nourriture
	"kibble": {"name": "Croquettes", "cat": "food", "icon": "kibble", "price": 10, "fx": {"hunger": 45, "mood": 3}, "desc": "Repas équilibré."},
	"pate": {"name": "Pâtée du chef", "cat": "food", "icon": "pate", "price": 22, "fx": {"hunger": 60, "mood": 10, "health": 4}, "desc": "Un vrai régal."},
	"fish": {"name": "Poisson vapeur", "cat": "food", "icon": "fish", "price": 28, "fx": {"hunger": 55, "mood": 12, "health": 6}, "desc": "Riche en oméga 3."},
	"veggie": {"name": "Bol de légumes", "cat": "food", "icon": "veggie", "price": 16, "fx": {"hunger": 35, "health": 10}, "desc": "Léger et sain."},
	# Friandises
	"biscuit": {"name": "Biscuit os", "cat": "treat", "icon": "biscuit", "price": 5, "fx": {"hunger": 6, "mood": 8, "affection": 4}, "desc": "Parfait pour le dressage."},
	"chew": {"name": "Bâton à mâcher", "cat": "treat", "icon": "chew", "price": 9, "fx": {"hunger": 8, "mood": 12, "clean": 2}, "desc": "Bon pour les dents."},
	"cheese": {"name": "Dés de fromage", "cat": "treat", "icon": "cheese", "price": 8, "fx": {"hunger": 5, "mood": 14, "affection": 3}, "desc": "Irrésistible."},
	"cookie": {"name": "Cookie au potiron", "cat": "treat", "icon": "cookie", "price": 12, "fx": {"hunger": 10, "mood": 18, "affection": 6}, "desc": "La friandise de luxe."},
	# Soins
	"shampoo": {"name": "Shampooing doux", "cat": "care", "icon": "shampoo", "price": 15, "bath": true, "foam": Color(1, 1, 1), "fx": {"clean": 20}, "desc": "Indispensable pour le bain (+20 propreté)."},
	"shampoo_shine": {"name": "Shampooing brillance", "cat": "care", "icon": "shampoo", "price": 28, "bath": true, "foam": Color(1.0, 0.9, 0.95), "fx": {"clean": 20, "mood": 10}, "desc": "Pelage éclatant : propreté et bonne humeur."},
	"shampoo_care": {"name": "Shampooing soin", "cat": "care", "icon": "shampoo", "price": 34, "bath": true, "foam": Color(0.88, 1.0, 0.92), "fx": {"clean": 20, "health": 8}, "desc": "Aux plantes : propreté et un peu de santé."},
	"vitamins": {"name": "Vitamines", "cat": "care", "icon": "vitamins", "price": 30, "fx": {"health": 30}, "desc": "Redonne de la santé."},
	# Jouets
	"ball": {"name": "Balle rouge", "cat": "toy", "icon": "ball", "price": 0, "color": Color(0.9, 0.2, 0.2), "toy": "ball", "desc": "La balle classique.", "bonus": 0},
	"tennis": {"name": "Balle fluo", "cat": "toy", "icon": "tennis", "price": 40, "color": Color(0.8, 0.95, 0.2), "toy": "ball", "desc": "Rebondit mieux (+10 % de score).", "bonus": 10},
	"disc": {"name": "Disque volant", "cat": "toy", "icon": "disc", "price": 90, "color": Color(0.2, 0.6, 0.95), "toy": "disc", "desc": "Plane plus loin (+20 % de score).", "bonus": 20},
	"rope": {"name": "Corde nouée", "cat": "toy", "icon": "rope", "price": 55, "color": Color(0.85, 0.75, 0.5), "toy": "rope", "desc": "Facile à attraper (+15 % de score).", "bonus": 15},
	"plush": {"name": "Peluche canard", "cat": "toy", "icon": "plush", "price": 75, "color": Color(1.0, 0.85, 0.2), "toy": "plush", "desc": "Le doudou préféré (+humeur au jeu).", "bonus": 12},
	# Colliers
	"collar_red": {"name": "Collier rouge", "cat": "collar", "icon": "collar_red", "price": 0, "color": Color(0.85, 0.2, 0.2), "desc": "Simple et chic."},
	"collar_blue": {"name": "Collier bleu", "cat": "collar", "icon": "collar_blue", "price": 0, "color": Color(0.2, 0.45, 0.9), "desc": "Bleu océan."},
	"collar_green": {"name": "Collier vert", "cat": "collar", "icon": "collar_green", "price": 0, "color": Color(0.3, 0.75, 0.35), "desc": "Vert prairie."},
	"collar_pink": {"name": "Collier rose", "cat": "collar", "icon": "collar_pink", "price": 35, "color": Color(0.95, 0.5, 0.7), "desc": "Rose bonbon."},
	"collar_gold": {"name": "Collier doré", "cat": "collar", "icon": "collar_gold", "price": 150, "color": Color(0.95, 0.78, 0.25), "desc": "Pour les champions.", "metal": true},
	"collar_purple": {"name": "Collier violet", "cat": "collar", "icon": "collar_purple", "price": 60, "color": Color(0.55, 0.3, 0.8), "desc": "Majestueux."},
	# Accessoires
	"acc_none": {"name": "Aucun", "cat": "accessory", "icon": "acc_none", "price": 0, "desc": "Rien du tout."},
	"hat": {"name": "Chapeau de paille", "cat": "accessory", "shape": "hat", "icon": "hat", "price": 80, "color": Color(0.92, 0.8, 0.5), "color2": Color(0.86, 0.3, 0.3), "desc": "Idéal pour la plage."},
	"hat_sun": {"name": "Capeline d'été", "cat": "accessory", "shape": "hat", "icon": "hat", "price": 95, "color": Color(0.98, 0.96, 0.9), "color2": Color(0.3, 0.5, 0.85), "desc": "Blanche à ruban bleu.", "level": 2},
	"cap": {"name": "Casquette bleue", "cat": "accessory", "shape": "cap", "icon": "hat", "price": 90, "color": Color(0.25, 0.5, 0.85), "color2": Color(1, 1, 1), "desc": "Sportif et décontracté."},
	"cap_red": {"name": "Casquette rouge", "cat": "accessory", "shape": "cap", "icon": "hat", "price": 90, "color": Color(0.86, 0.25, 0.25), "color2": Color(1, 1, 1), "desc": "Pour les jours de match."},
	"cap_green": {"name": "Casquette verte", "cat": "accessory", "shape": "cap", "icon": "hat", "price": 90, "color": Color(0.3, 0.62, 0.4), "color2": Color(1, 0.9, 0.4), "desc": "Esprit nature.", "level": 2},
	"beret": {"name": "Béret rouge", "cat": "accessory", "shape": "beret", "icon": "hat", "price": 110, "color": Color(0.7, 0.2, 0.25), "color2": Color(1, 1, 1), "desc": "Chic à la française.", "level": 2},
	"beret_navy": {"name": "Béret marine", "cat": "accessory", "shape": "beret", "icon": "hat", "price": 110, "color": Color(0.18, 0.24, 0.42), "color2": Color(1, 1, 1), "desc": "L'élégance discrète.", "level": 2},
	"party": {"name": "Chapeau de fête rose", "cat": "accessory", "shape": "party", "icon": "daily_star", "price": 75, "color": Color(0.95, 0.4, 0.6), "color2": Color(1, 1, 1), "desc": "Pour les anniversaires."},
	"party_blue": {"name": "Chapeau de fête bleu", "cat": "accessory", "shape": "party", "icon": "daily_star", "price": 75, "color": Color(0.3, 0.6, 0.92), "color2": Color(1, 1, 1), "desc": "Pour les anniversaires."},
	"crown": {"name": "Couronne", "cat": "accessory", "shape": "crown", "icon": "crown", "price": 300, "color": Color(1, 0.82, 0.2), "color2": Color(1, 1, 1), "desc": "Réservée aux stars.", "level": 6},
	"tiara": {"name": "Diadème", "cat": "accessory", "shape": "tiara", "icon": "crown", "price": 220, "color": Color(0.86, 0.88, 0.92), "color2": Color(0.45, 0.7, 1), "desc": "Une pierre bleue au front.", "level": 5},
	"flower_crown": {"name": "Couronne de fleurs", "cat": "accessory", "shape": "flower_crown", "icon": "flowers", "price": 140, "color": Color(1, 0.6, 0.72), "color2": Color(1, 1, 1), "desc": "Fraîche comme le printemps.", "level": 3},
	"laurel": {"name": "Couronne de laurier", "cat": "accessory", "shape": "laurel", "icon": "leaf", "price": 180, "color": Color(0.42, 0.66, 0.3), "color2": Color(1, 1, 1), "desc": "Pour les champions.", "level": 5},
	"bow": {"name": "Nœud rose", "cat": "accessory", "shape": "bow", "icon": "bow", "price": 0, "color": Color(0.95, 0.45, 0.65), "color2": Color(1, 1, 1), "desc": "Adorable."},
	"bow_blue": {"name": "Nœud bleu", "cat": "accessory", "shape": "bow", "icon": "bow", "price": 40, "color": Color(0.35, 0.6, 0.95), "color2": Color(1, 1, 1), "desc": "Adorable."},
	"bow_yellow": {"name": "Nœud jaune", "cat": "accessory", "shape": "bow", "icon": "bow", "price": 40, "color": Color(1, 0.82, 0.3), "color2": Color(1, 1, 1), "desc": "Rayon de soleil."},
	"tophat": {"name": "Haut-de-forme", "cat": "accessory", "shape": "tophat", "icon": "hat", "price": 200, "color": Color(0.14, 0.14, 0.17), "color2": Color(0.75, 0.2, 0.25), "desc": "Monsieur est servi.", "level": 4},
	"cowboy": {"name": "Chapeau de cow-boy", "cat": "accessory", "shape": "cowboy", "icon": "hat", "price": 170, "color": Color(0.62, 0.44, 0.28), "color2": Color(0.3, 0.2, 0.14), "desc": "Le shérif du quartier.", "level": 3},
	"beanie": {"name": "Bonnet rouge", "cat": "accessory", "shape": "beanie", "icon": "hat", "price": 85, "color": Color(0.86, 0.28, 0.28), "color2": Color(1, 1, 1), "desc": "Bien au chaud."},
	"beanie_blue": {"name": "Bonnet bleu", "cat": "accessory", "shape": "beanie", "icon": "hat", "price": 85, "color": Color(0.28, 0.5, 0.82), "color2": Color(1, 1, 1), "desc": "Bien au chaud."},
	"beanie_green": {"name": "Bonnet vert", "cat": "accessory", "shape": "beanie", "icon": "hat", "price": 85, "color": Color(0.3, 0.6, 0.42), "color2": Color(1, 0.95, 0.8), "desc": "Bien au chaud.", "level": 2},
	"chef": {"name": "Toque de chef", "cat": "accessory", "shape": "chef", "icon": "feed", "price": 150, "color": Color(1, 1, 1), "color2": Color(1, 1, 1), "desc": "À table !", "level": 3},
	"wizard": {"name": "Chapeau de magicien", "cat": "accessory", "shape": "wizard", "icon": "sparkle", "price": 210, "color": Color(0.36, 0.26, 0.62), "color2": Color(0.95, 0.78, 0.3), "desc": "Abracadabra.", "level": 5},
	"santa": {"name": "Bonnet de Noël", "cat": "accessory", "shape": "santa", "icon": "daily_star", "price": 120, "color": Color(0.86, 0.2, 0.22), "color2": Color(1, 1, 1), "desc": "Ho ho ho.", "level": 2},
	"bunny": {"name": "Oreilles de lapin", "cat": "accessory", "shape": "bunny", "icon": "heart", "price": 130, "color": Color(1, 1, 1), "color2": Color(0.95, 0.6, 0.72), "desc": "Hop hop hop.", "level": 2},
	"antlers": {"name": "Bois de renne", "cat": "accessory", "shape": "antlers", "icon": "leaf", "price": 130, "color": Color(0.5, 0.34, 0.22), "color2": Color(0.3, 0.5, 0.3), "desc": "Avec deux grelots rouges.", "level": 2},
	"sailor": {"name": "Bob de marin", "cat": "accessory", "shape": "sailor", "icon": "hat", "price": 115, "color": Color(0.2, 0.35, 0.7), "color2": Color(1, 1, 1), "desc": "Toutes voiles dehors.", "level": 2},
	"grad": {"name": "Chapeau de diplômé", "cat": "accessory", "shape": "grad", "icon": "training", "price": 190, "color": Color(0.14, 0.16, 0.22), "color2": Color(1, 1, 1), "desc": "Premier de la classe.", "level": 6},
	"headphones": {"name": "Casque audio", "cat": "accessory", "shape": "headphones", "icon": "mic", "price": 160, "color": Color(0.25, 0.27, 0.32), "color2": Color(0.9, 0.35, 0.35), "desc": "En musique.", "level": 3},
	"headphones_pink": {"name": "Casque audio rose", "cat": "accessory", "shape": "headphones", "icon": "mic", "price": 160, "color": Color(0.95, 0.6, 0.75), "color2": Color(1, 1, 1), "desc": "En musique.", "level": 3},
	"earflower": {"name": "Fleur à l'oreille", "cat": "accessory", "shape": "earflower", "icon": "daisy", "price": 50, "color": Color(1, 0.55, 0.7), "color2": Color(1, 1, 1), "desc": "Une touche de douceur."},
	"earflower_white": {"name": "Marguerite à l'oreille", "cat": "accessory", "shape": "earflower", "icon": "daisy", "price": 50, "color": Color(1, 1, 1), "color2": Color(1, 1, 1), "desc": "Simple et jolie."},
	"viking": {"name": "Casque de viking", "cat": "accessory", "shape": "viking", "icon": "trophy", "price": 240, "color": Color(0.62, 0.64, 0.68), "color2": Color(0.96, 0.93, 0.84), "desc": "À l'abordage !", "level": 7},
	"halo": {"name": "Auréole", "cat": "accessory", "shape": "halo", "icon": "sparkle", "price": 260, "color": Color(1, 0.88, 0.4), "color2": Color(1, 1, 1), "desc": "Un petit ange.", "level": 8},
	"pirate": {"name": "Chapeau de pirate", "cat": "accessory", "shape": "pirate", "icon": "flag", "price": 140, "color": Color(0.14, 0.13, 0.16), "color2": Color(0.95, 0.8, 0.3), "desc": "Mille sabords.", "level": 3},
	"glasses": {"name": "Lunettes de soleil", "cat": "accessory", "shape": "glasses", "icon": "glasses", "price": 120, "color": Color(0.1, 0.1, 0.12), "color2": Color(1, 1, 1), "desc": "Trop cool.", "lens": Color(0.12, 0.14, 0.2, 0.62)},
	"round_glasses": {"name": "Lunettes rondes", "cat": "accessory", "shape": "glasses", "icon": "glasses", "price": 110, "color": Color(0.85, 0.68, 0.3), "color2": Color(1, 1, 1), "desc": "L'intello de la bande.", "level": 2, "lens": Color(0.85, 0.93, 1.0, 0.18)},
	"rose_glasses": {"name": "Lunettes roses", "cat": "accessory", "shape": "glasses", "icon": "glasses", "price": 130, "color": Color(0.95, 0.45, 0.65), "color2": Color(1, 1, 1), "desc": "La vie en rose.", "level": 3, "lens": Color(1.0, 0.55, 0.75, 0.42)},
	"monocle": {"name": "Monocle", "cat": "accessory", "shape": "monocle", "icon": "glasses", "price": 180, "color": Color(0.9, 0.75, 0.3), "color2": Color(1, 1, 1), "desc": "Très distingué.", "level": 5},
	"bandana": {"name": "Bandana rouge", "cat": "accessory", "shape": "bandana", "icon": "bandana", "price": 0, "color": Color(0.9, 0.3, 0.3), "color2": Color(1, 1, 1), "desc": "Style aventurier."},
	"bandana_blue": {"name": "Bandana bleu", "cat": "accessory", "shape": "bandana", "icon": "bandana", "price": 45, "color": Color(0.25, 0.5, 0.85), "color2": Color(1, 1, 1), "desc": "Style aventurier."},
	"bandana_green": {"name": "Bandana vert", "cat": "accessory", "shape": "bandana", "icon": "bandana", "price": 45, "color": Color(0.3, 0.62, 0.4), "color2": Color(1, 0.95, 0.6), "desc": "Style aventurier."},
	"scarf": {"name": "Écharpe bleue", "cat": "accessory", "shape": "scarf", "icon": "scarf", "price": 70, "color": Color(0.3, 0.55, 0.85), "color2": Color(0.85, 0.92, 1), "desc": "Toute douce."},
	"scarf_red": {"name": "Écharpe rouge", "cat": "accessory", "shape": "scarf", "icon": "scarf", "price": 70, "color": Color(0.82, 0.25, 0.28), "color2": Color(1, 1, 1), "desc": "Toute douce."},
	"scarf_mustard": {"name": "Écharpe moutarde", "cat": "accessory", "shape": "scarf", "icon": "scarf", "price": 70, "color": Color(0.9, 0.7, 0.25), "color2": Color(0.5, 0.34, 0.2), "desc": "Toute douce.", "level": 2},
	"bowtie": {"name": "Nœud papillon marine", "cat": "accessory", "shape": "bowtie", "icon": "bow", "price": 60, "color": Color(0.2, 0.25, 0.45), "color2": Color(1, 1, 1), "desc": "Très élégant."},
	"bowtie_red": {"name": "Nœud papillon rouge", "cat": "accessory", "shape": "bowtie", "icon": "bow", "price": 60, "color": Color(0.8, 0.2, 0.25), "color2": Color(1, 1, 1), "desc": "Très élégant."},
	"tie": {"name": "Cravate bleue", "cat": "accessory", "shape": "tie", "icon": "bow", "price": 90, "color": Color(0.22, 0.4, 0.72), "color2": Color(0.85, 0.9, 1), "desc": "Prêt pour le bureau.", "level": 2},
	"tie_red": {"name": "Cravate rouge", "cat": "accessory", "shape": "tie", "icon": "bow", "price": 90, "color": Color(0.78, 0.2, 0.24), "color2": Color(1, 0.85, 0.85), "desc": "Prêt pour le bureau.", "level": 2},
	"bell": {"name": "Grelot doré", "cat": "accessory", "shape": "bell", "icon": "collar_gold", "price": 55, "color": Color(1, 0.82, 0.25), "color2": Color(1, 1, 1), "desc": "Diling, diling."},
	"medal": {"name": "Médaille", "cat": "accessory", "shape": "medal", "icon": "medal", "price": 150, "color": Color(0.25, 0.45, 0.85), "color2": Color(0.9, 0.3, 0.3), "desc": "Fierté du quartier.", "level": 4},
	"lei": {"name": "Collier de fleurs", "cat": "accessory", "shape": "lei", "icon": "flowers", "price": 120, "color": Color(1, 0.6, 0.72), "color2": Color(1, 1, 1), "desc": "Aloha !", "level": 3},
	"ruff": {"name": "Collerette", "cat": "accessory", "shape": "ruff", "icon": "cloud_bed", "price": 160, "color": Color(1, 1, 1), "color2": Color(0.95, 0.93, 0.9), "desc": "Digne d'un roi.", "level": 5},
	"pearls": {"name": "Collier de perles", "cat": "accessory", "shape": "pearls", "icon": "gem", "price": 200, "color": Color(0.98, 0.96, 0.94), "color2": Color(1, 1, 1), "desc": "Raffiné.", "level": 6},
	"tag": {"name": "Médaillon en os", "cat": "accessory", "shape": "tag", "icon": "bone_old", "price": 65, "color": Color(1, 0.82, 0.25), "color2": Color(1, 1, 1), "desc": "Avec son nom gravé."},
	"backpack": {"name": "Sac à dos orange", "cat": "accessory", "shape": "backpack", "icon": "inventory", "price": 160, "color": Color(0.9, 0.55, 0.25), "color2": Color(1, 0.75, 0.45), "desc": "Prêt pour l'aventure.", "level": 4},
	"backpack_blue": {"name": "Sac à dos bleu", "cat": "accessory", "shape": "backpack", "icon": "inventory", "price": 160, "color": Color(0.28, 0.5, 0.82), "color2": Color(0.6, 0.78, 0.98), "desc": "Prêt pour l'aventure.", "level": 4},
	"saddlebags": {"name": "Sacoches de randonnée", "cat": "accessory", "shape": "saddlebags", "icon": "inventory", "price": 190, "color": Color(0.5, 0.6, 0.38), "color2": Color(0.82, 0.72, 0.5), "desc": "Pour les longues balades.", "level": 5},
	"cape": {"name": "Cape rouge", "cat": "accessory", "shape": "cape", "icon": "star", "price": 180, "color": Color(0.82, 0.18, 0.22), "color2": Color(1, 0.82, 0.25), "desc": "Super-compagnon.", "level": 4},
	"cape_blue": {"name": "Cape bleue", "cat": "accessory", "shape": "cape", "icon": "star", "price": 180, "color": Color(0.2, 0.4, 0.82), "color2": Color(1, 0.82, 0.25), "desc": "Super-compagnon.", "level": 4},
	"cape_purple": {"name": "Cape royale", "cat": "accessory", "shape": "cape", "icon": "star", "price": 230, "color": Color(0.48, 0.24, 0.62), "color2": Color(1, 1, 1), "desc": "Avec son col blanc.", "level": 6},
	"wings": {"name": "Ailes d'ange", "cat": "accessory", "shape": "wings", "icon": "feather", "price": 250, "color": Color(1, 1, 1), "color2": Color(0.92, 0.95, 1), "desc": "Un amour.", "level": 6, "wing": "angel"},
	"wings_fairy": {"name": "Ailes de fée", "cat": "accessory", "shape": "wings", "icon": "feather", "price": 250, "color": Color(1, 0.7, 0.85), "color2": Color(0.8, 0.9, 1), "desc": "Un peu de magie.", "level": 6, "wing": "angel"},
	"wings_butterfly": {"name": "Ailes de papillon", "cat": "accessory", "shape": "wings", "icon": "butterfly", "price": 270, "color": Color(1, 0.6, 0.2), "color2": Color(1, 0.82, 0.3), "desc": "Prêt à s'envoler.", "level": 7, "wing": "butterfly"},
	"balloon": {"name": "Ballon rouge", "cat": "accessory", "shape": "balloon", "icon": "ball", "price": 60, "color": Color(0.92, 0.25, 0.28), "color2": Color(1, 1, 1), "desc": "Il flotte au-dessus de lui."},
	"balloon_blue": {"name": "Ballon bleu", "cat": "accessory", "shape": "balloon", "icon": "ball", "price": 60, "color": Color(0.3, 0.58, 0.95), "color2": Color(1, 1, 1), "desc": "Il flotte au-dessus de lui."},
	"balloon_yellow": {"name": "Ballon jaune", "cat": "accessory", "shape": "balloon", "icon": "ball", "price": 60, "color": Color(1, 0.82, 0.25), "color2": Color(1, 1, 1), "desc": "Il flotte au-dessus de lui."},
	"tutu": {"name": "Tutu rose", "cat": "accessory", "shape": "tutu", "icon": "heart", "price": 150, "color": Color(1, 0.62, 0.78), "color2": Color(1, 1, 1), "desc": "Petit rat de l'opéra.", "level": 3},
	"tutu_blue": {"name": "Tutu bleu", "cat": "accessory", "shape": "tutu", "icon": "heart", "price": 150, "color": Color(0.55, 0.75, 1), "color2": Color(1, 1, 1), "desc": "Petit rat de l'opéra.", "level": 3},

	"rug_round": {"name": "Tapis rond", "cat": "deco", "slot": "rug", "icon": "rug_round", "price": 0, "color": Color(0.85, 0.55, 0.45), "desc": "Tapis de base."},
	"rug_blue": {"name": "Tapis océan", "cat": "deco", "slot": "rug", "icon": "rug_blue", "price": 60, "color": Color(0.35, 0.55, 0.85), "desc": "Fraîcheur garantie."},
	"rug_green": {"name": "Tapis mousse", "cat": "deco", "slot": "rug", "icon": "rug_green", "price": 60, "color": Color(0.45, 0.72, 0.45), "desc": "Doux comme l'herbe."},
	"bed_basic": {"name": "Panier simple", "cat": "deco", "slot": "bed", "icon": "bed", "price": 0, "color": Color(0.7, 0.45, 0.3), "desc": "Confortable."},
	"bed_cloud": {"name": "Coussin nuage", "cat": "deco", "slot": "bed", "icon": "cloud_bed", "price": 120, "color": Color(0.85, 0.88, 0.98), "desc": "Récupère l'énergie 30 % plus vite.", "bonus": 30},
	"bed_royal": {"name": "Lit royal", "cat": "deco", "slot": "bed", "icon": "royal_bed", "price": 260, "color": Color(0.6, 0.25, 0.45), "desc": "Récupère l'énergie 60 % plus vite.", "bonus": 60, "level": 5},
	"plant_fern": {"name": "Fougère", "cat": "deco", "slot": "plant", "icon": "fern", "price": 40, "color": Color(0.3, 0.65, 0.3), "desc": "Un coin de verdure."},
	"plant_cactus": {"name": "Cactus", "cat": "deco", "slot": "plant", "icon": "cactus", "price": 45, "color": Color(0.35, 0.6, 0.35), "desc": "Ne pas toucher !"},
	"plant_flowers": {"name": "Bouquet", "cat": "deco", "slot": "plant", "icon": "flowers", "price": 55, "color": Color(0.95, 0.5, 0.6), "desc": "Des couleurs !"},
	"lamp_warm": {"name": "Lampe douce", "cat": "deco", "slot": "lamp", "icon": "lamp", "price": 50, "color": Color(1.0, 0.85, 0.6), "desc": "Lumière chaleureuse."},
	"lamp_star": {"name": "Lampe étoile", "cat": "deco", "slot": "lamp", "icon": "star_lamp", "price": 90, "color": Color(1.0, 0.95, 0.5), "desc": "Magique."},
	"sofa_coral": {"name": "Canapé corail", "cat": "deco", "slot": "sofa", "icon": "sofa_coral", "price": 0, "color": Color(0.95, 0.55, 0.45), "desc": "Le canapé de base."},
	"sofa_teal": {"name": "Canapé lagon", "cat": "deco", "slot": "sofa", "icon": "sofa_teal", "price": 140, "color": Color(0.25, 0.6, 0.6), "desc": "Très tendance."},
	"sofa_mustard": {"name": "Canapé moutarde", "cat": "deco", "slot": "sofa", "icon": "sofa_mustard", "price": 140, "color": Color(0.88, 0.7, 0.25), "desc": "Vintage."},
	"wall_cream": {"name": "Murs crème", "cat": "deco", "slot": "wall", "icon": "wall_cream", "price": 0, "color": Color(0.98, 0.93, 0.84), "desc": "Classique."},
	"wall_mint": {"name": "Murs menthe", "cat": "deco", "slot": "wall", "icon": "wall_mint", "price": 80, "color": Color(0.78, 0.92, 0.84), "desc": "Frais."},
	"wall_lilac": {"name": "Murs lilas", "cat": "deco", "slot": "wall", "icon": "wall_lilac", "price": 80, "color": Color(0.88, 0.82, 0.95), "desc": "Doux."},
	"wall_peach": {"name": "Murs pêche", "cat": "deco", "slot": "wall", "icon": "wall_peach", "price": 80, "color": Color(0.99, 0.84, 0.74), "desc": "Chaleureux."},
	"frame_sun": {"name": "Tableau soleil", "cat": "deco", "slot": "frame", "icon": "frame_sun", "price": 35, "color": Color(0.98, 0.75, 0.3), "desc": "Plein d'énergie."},
	"frame_sea": {"name": "Tableau mer", "cat": "deco", "slot": "frame", "icon": "frame_sea", "price": 35, "color": Color(0.3, 0.6, 0.9), "desc": "Apaisant."},
	"toybox": {"name": "Coffre à jouets", "cat": "deco", "slot": "box", "icon": "toybox", "price": 70, "color": Color(0.55, 0.75, 0.95), "desc": "+5 humeur par jour au réveil."},
	"plant_monstera": {"name": "Grande plante", "cat": "deco", "slot": "plant", "icon": "leaf", "price": 95, "color": Color(0.28, 0.58, 0.3), "desc": "Une touche de jungle.", "level": 2},
	"lamp_paper": {"name": "Lanterne en papier", "cat": "deco", "slot": "lamp", "icon": "lamp", "price": 110, "color": Color(1.0, 0.9, 0.72), "desc": "Lumière tamisée.", "level": 3},
	"frame_paw": {"name": "Tableau empreinte", "cat": "deco", "slot": "frame", "icon": "paw", "price": 45, "color": Color(0.85, 0.5, 0.4), "desc": "La patte de l'artiste."},
	"rug_plum": {"name": "Tapis prune", "cat": "deco", "slot": "rug", "icon": "rug_round", "price": 75, "color": Color(0.62, 0.38, 0.6), "desc": "Chaleureux et profond."},
	"rug_sand": {"name": "Tapis sable", "cat": "deco", "slot": "rug", "icon": "rug_round", "price": 75, "color": Color(0.9, 0.8, 0.62), "desc": "Naturel et lumineux."},
	"sofa_rose": {"name": "Canapé rose poudré", "cat": "deco", "slot": "sofa", "icon": "sofa", "price": 160, "color": Color(0.92, 0.68, 0.72), "desc": "Tout en douceur."},
	"sofa_slate": {"name": "Canapé ardoise", "cat": "deco", "slot": "sofa", "icon": "sofa", "price": 160, "color": Color(0.42, 0.48, 0.58), "desc": "Sobre et moderne."},
	"wall_sky": {"name": "Murs bleu ciel", "cat": "deco", "slot": "wall", "icon": "wall_mint", "price": 80, "color": Color(0.78, 0.88, 0.97), "desc": "Aérien."},
	"wall_butter": {"name": "Murs jaune beurre", "cat": "deco", "slot": "wall", "icon": "wall_cream", "price": 80, "color": Color(0.99, 0.93, 0.7), "desc": "Ensoleillé."},
	"shelf_oak": {"name": "Bibliothèque en chêne", "cat": "deco", "slot": "shelf", "icon": "album", "price": 150, "color": Color(0.8, 0.6, 0.42), "desc": "Des livres et un trophée.", "level": 2},
	"shelf_white": {"name": "Bibliothèque blanche", "cat": "deco", "slot": "shelf", "icon": "album", "price": 150, "color": Color(0.96, 0.95, 0.92), "desc": "Claire et épurée.", "level": 2},
	"table_vase": {"name": "Guéridon et bouquet", "cat": "deco", "slot": "table", "icon": "flowers", "price": 90, "color": Color(0.62, 0.8, 0.9), "desc": "Des fleurs fraîches."},
	"table_aquarium": {"name": "Aquarium", "cat": "deco", "slot": "table", "icon": "fish", "price": 220, "color": Color(0.45, 0.78, 0.95), "desc": "Trois poissons à contempler.", "level": 4},
	"pouf_pink": {"name": "Pouf rose", "cat": "deco", "slot": "pouf", "icon": "cloud_bed", "price": 65, "color": Color(0.95, 0.62, 0.72), "desc": "Moelleux."},
	"pouf_teal": {"name": "Pouf lagon", "cat": "deco", "slot": "pouf", "icon": "cloud_bed", "price": 65, "color": Color(0.3, 0.66, 0.66), "desc": "Moelleux."},
	"clock_wood": {"name": "Horloge en bois", "cat": "deco", "slot": "clock", "icon": "timer", "price": 70, "color": Color(0.8, 0.6, 0.42), "desc": "Tic, tac."},
	"clock_mint": {"name": "Horloge menthe", "cat": "deco", "slot": "clock", "icon": "timer", "price": 70, "color": Color(0.62, 0.86, 0.78), "desc": "Tic, tac."},
	# Objets de collection (trouvailles de promenade et de recherche) : rareté 1 à 3, valeur de vente
	"daisy": {"name": "Pâquerette", "cat": "collection", "icon": "daisy", "price": 0, "sell": 3, "rarity": 1, "envs": ["garden", "park"], "desc": "Cueillie dans l'herbe."},
	"snail": {"name": "Escargot", "cat": "collection", "icon": "snail", "price": 0, "sell": 4, "rarity": 1, "envs": ["garden", "forest"], "desc": "Il a laissé une trace brillante."},
	"leaf": {"name": "Feuille d'automne", "cat": "collection", "icon": "leaf", "price": 0, "sell": 2, "rarity": 1, "envs": ["garden", "park", "forest"], "desc": "Rousse et craquante."},
	"worm": {"name": "Ver de terre", "cat": "collection", "icon": "worm", "price": 0, "sell": 2, "rarity": 1, "envs": ["garden"], "desc": "Il gigote encore."},
	"strawberry": {"name": "Fraise des bois", "cat": "collection", "icon": "strawberry", "price": 0, "sell": 6, "rarity": 2, "envs": ["garden", "forest"], "desc": "Sucrée et minuscule."},
	"acorn": {"name": "Gland", "cat": "collection", "icon": "acorn", "price": 0, "sell": 3, "rarity": 1, "envs": ["park", "forest"], "desc": "Tombé d'un chêne."},
	"feather": {"name": "Plume", "cat": "collection", "icon": "feather", "price": 0, "sell": 4, "rarity": 1, "envs": ["park", "forest", "beach"], "desc": "Légère comme l'air."},
	"mushroom": {"name": "Champignon", "cat": "collection", "icon": "mushroom", "price": 0, "sell": 5, "rarity": 1, "envs": ["park", "forest"], "desc": "À ne pas manger !"},
	"butterfly": {"name": "Papillon", "cat": "collection", "icon": "butterfly", "price": 0, "sell": 8, "rarity": 2, "envs": ["garden", "park"], "desc": "Il s'est posé sur la truffe."},
	"stick": {"name": "Joli bâton", "cat": "collection", "icon": "stick", "price": 0, "sell": 3, "rarity": 1, "envs": ["park", "forest", "center"], "desc": "Le meilleur des jouets."},
	"maple": {"name": "Feuille d'érable", "cat": "collection", "icon": "maple", "price": 0, "sell": 4, "rarity": 1, "envs": ["park", "forest"], "desc": "Rouge flamboyant."},
	"shell": {"name": "Coquillage", "cat": "collection", "icon": "shell", "price": 0, "sell": 5, "rarity": 1, "envs": ["beach"], "desc": "On entend la mer."},
	"starfish": {"name": "Étoile de mer", "cat": "collection", "icon": "starfish", "price": 0, "sell": 9, "rarity": 2, "envs": ["beach"], "desc": "Cinq bras orange."},
	"crab": {"name": "Petit crabe", "cat": "collection", "icon": "crab", "price": 0, "sell": 7, "rarity": 2, "envs": ["beach"], "desc": "Attention aux pinces."},
	"coral": {"name": "Corail", "cat": "collection", "icon": "coral", "price": 0, "sell": 10, "rarity": 2, "envs": ["beach"], "desc": "Rose et dentelé."},
	"pebble": {"name": "Galet rond", "cat": "collection", "icon": "pebble", "price": 0, "sell": 2, "rarity": 1, "envs": ["beach", "forest"], "desc": "Poli par les vagues."},
	"driftwood": {"name": "Bois flotté", "cat": "collection", "icon": "driftwood", "price": 0, "sell": 4, "rarity": 1, "envs": ["beach"], "desc": "Blanchi par le sel."},
	"pinecone": {"name": "Pomme de pin", "cat": "collection", "icon": "pinecone", "price": 0, "sell": 3, "rarity": 1, "envs": ["forest"], "desc": "Elle sent la résine."},
	"marble": {"name": "Bille", "cat": "collection", "icon": "marble", "price": 0, "sell": 5, "rarity": 1, "envs": ["house", "garden", "center"], "desc": "Perdue sous un meuble."},
	"sock": {"name": "Chaussette perdue", "cat": "collection", "icon": "sock", "price": 0, "sell": 2, "rarity": 1, "envs": ["house"], "desc": "Enfin retrouvée !"},
	"coin_old": {"name": "Pièce ancienne", "cat": "collection", "icon": "coin_old", "price": 0, "sell": 18, "rarity": 2, "envs": ["house", "park", "center", "beach"], "desc": "Frappée il y a longtemps."},
	"key_old": {"name": "Vieille clé", "cat": "collection", "icon": "key_old", "price": 0, "sell": 15, "rarity": 2, "envs": ["house", "garden", "forest"], "desc": "Quelle porte ouvre-t-elle ?"},
	"bottle": {"name": "Bouteille à message", "cat": "collection", "icon": "bottle", "price": 0, "sell": 20, "rarity": 2, "envs": ["beach"], "desc": "Un mot d'un autre rivage."},
	"gem": {"name": "Pierre brillante", "cat": "collection", "icon": "gem", "price": 0, "sell": 60, "rarity": 3, "envs": ["forest", "beach", "park"], "desc": "Elle scintille au soleil."},
	"bone_old": {"name": "Os fossile", "cat": "collection", "icon": "bone_old", "price": 0, "sell": 45, "rarity": 3, "envs": ["forest", "garden"], "desc": "Un trésor de chien."},
	"medal_old": {"name": "Médaille oubliée", "cat": "collection", "icon": "medal_old", "price": 0, "sell": 50, "rarity": 3, "envs": ["park", "center", "house"], "desc": "Un champion l'a perdue."},
	"pearl": {"name": "Perle nacrée", "cat": "collection", "icon": "pearl", "price": 0, "sell": 70, "rarity": 3, "envs": ["beach"], "desc": "Cachée dans une huître."},
}
const SHOP_TABS: Array[String] = ["food", "treat", "care", "toy", "collar", "accessory", "deco", "env", "sell"]
const SHOP_TAB_NAMES := {
	"food": "Repas", "treat": "Friandises", "care": "Soins", "toy": "Jouets", "collar": "Colliers",
	"accessory": "Accessoires", "deco": "Déco", "env": "Lieux", "sell": "Vendre",
}
## Catégories comptées dans l'inventaire (empilables) : consommables et objets de collection.
const CONSUMABLE_CATS: Array[String] = ["food", "treat", "care", "collection"]
const RARITY_NAMES := ["", "Courant", "Peu courant", "Rare"]
const DECO_SLOTS: Array[String] = ["wall", "rug", "sofa", "bed", "plant", "lamp", "frame", "box", "shelf", "table", "pouf", "clock"]
const DECO_SLOT_NAMES := {
	"wall": "Murs", "rug": "Tapis", "sofa": "Canapé", "bed": "Couchage", "plant": "Plante",
	"lamp": "Lampe", "frame": "Tableau", "box": "Rangement",
	"shelf": "Bibliothèque", "table": "Table d'appoint", "pouf": "Pouf", "clock": "Horloge",
}

# ------------------------------------------------------------------ Lieux
const ENVIRONMENTS := {
	"house": {"name": "Maison", "icon": "house", "price": 0, "level": 1, "amb": "amb_house", "walk": false},
	"garden": {"name": "Jardin", "icon": "garden", "price": 0, "level": 1, "amb": "amb_garden", "walk": true},
	"park": {"name": "Parc", "icon": "park", "price": 150, "level": 2, "amb": "amb_park", "walk": true},
	"forest": {"name": "Forêt", "icon": "forest", "price": 250, "level": 3, "amb": "amb_forest", "walk": true},
	"beach": {"name": "Plage", "icon": "beach", "price": 400, "level": 4, "amb": "amb_beach", "walk": true},
	"center": {"name": "Terrain d'entraînement", "icon": "center", "price": 0, "level": 1, "amb": "amb_center", "walk": false},
	"shelter": {"name": "Refuge", "icon": "shelter", "price": 0, "level": 1, "amb": "amb_shelter", "walk": false},
	"town": {"name": "Quartier", "icon": "map", "price": 0, "level": 1, "amb": "amb_park", "walk": false, "hidden": true},
	"field": {"name": "Grand pré", "icon": "field", "price": 0, "level": 1, "amb": "amb_park", "walk": false, "hidden": true},
}
const ENV_ORDER: Array[String] = ["house", "garden", "park", "forest", "beach", "center", "shelter"]

# ------------------------------------------------------------------ Carte des promenades
## Quartier parcouru en promenade (coordonnées en mètres de jeu, ×10 affichés).
## kind : home, road, water, shop, park, beach, forest, center, comp. env : lieu à débloquer.
const WALK_NODES := {
	"home": {"name": "Maison", "icon": "house", "kind": "home", "pos": Vector2(0, 31.5), "zone": "village"},
	"lane": {"name": "Rue des Lilas", "icon": "route", "kind": "road", "pos": Vector2(0, 20.25), "zone": "village"},
	"fountain": {"name": "Place de la fontaine", "icon": "water", "kind": "water", "pos": Vector2(0, 9), "zone": "village"},
	"bakery": {"name": "Boulangerie", "icon": "biscuit", "kind": "bakery", "pos": Vector2(12.375, 21.375), "zone": "village"},
	"shop": {"name": "Boutique", "icon": "shop", "kind": "shop", "pos": Vector2(15.75, 9), "zone": "village"},
	"groomer": {"name": "Toiletteur", "icon": "brush", "kind": "groomer", "pos": Vector2(27, 18), "zone": "village"},
	"cafe": {"name": "Café des chiens", "icon": "bottle", "kind": "cafe", "pos": Vector2(-12.375, 23.625), "zone": "village"},
	"market": {"name": "Marché", "icon": "strawberry", "kind": "market", "pos": Vector2(-15.75, 11.25), "zone": "village"},
	"vet": {"name": "Vétérinaire", "icon": "health", "kind": "vet", "pos": Vector2(14.625, -3.375), "zone": "village"},
	"school": {"name": "École du chiot", "icon": "training", "kind": "school", "pos": Vector2(29.25, -4.5), "zone": "village"},
	"park": {"name": "Parc à chiens", "icon": "park", "kind": "park", "pos": Vector2(-29.25, 2.25), "env": "park"},
	"pond": {"name": "Étang aux canards", "icon": "fish", "kind": "pond", "pos": Vector2(-38.25, -11.25)},
	"bridge_n": {"name": "Vieux pont", "icon": "route", "kind": "road", "pos": Vector2(0, -8.1), "zone": "village"},
	"bridge_s": {"name": "Vieux pont", "icon": "route", "kind": "road", "pos": Vector2(0, -18.9)},
	"center": {"name": "Terrain d'agilité", "icon": "agility", "kind": "center", "pos": Vector2(20.25, -22.5)},
	"comp": {"name": "Salle des concours", "icon": "trophy", "kind": "comp", "pos": Vector2(9, -33.75)},
	"farm": {"name": "Ferme", "icon": "feather", "kind": "farm", "pos": Vector2(-18, -24.75)},
	"forest": {"name": "Lisière de la forêt", "icon": "forest", "kind": "forest", "pos": Vector2(-33.75, -33.75), "env": "forest"},
	"meadow": {"name": "Grand pré", "icon": "field", "kind": "meadow", "pos": Vector2(-9, -40.5)},
	"viewpoint": {"name": "Belvédère", "icon": "camera", "kind": "viewpoint", "pos": Vector2(27, -38.25)},
	"beach": {"name": "Plage", "icon": "beach", "kind": "beach", "pos": Vector2(0, -56.25), "env": "beach"},
	"lighthouse": {"name": "Phare", "icon": "lamp", "kind": "lighthouse", "pos": Vector2(22.5, -56.25)},
}
const WALK_EDGES := [
	["home", "lane"], ["lane", "fountain"], ["lane", "bakery"], ["lane", "cafe"], ["bakery", "shop"], ["bakery", "groomer"],
	["shop", "fountain"], ["shop", "groomer"], ["cafe", "market"], ["market", "fountain"], ["market", "park"], ["park", "pond"],
	["fountain", "bridge_n"], ["fountain", "vet"], ["shop", "vet"], ["vet", "school"], ["vet", "bridge_n"], ["bridge_n", "bridge_s"],
	["bridge_s", "center"], ["bridge_s", "comp"], ["bridge_s", "farm"], ["school", "center"], ["pond", "farm"], ["farm", "forest"],
	["farm", "meadow"], ["forest", "meadow"], ["comp", "meadow"], ["comp", "viewpoint"], ["center", "viewpoint"],
	["meadow", "beach"], ["viewpoint", "lighthouse"], ["beach", "lighthouse"],
]
## Rivière qui traverse le quartier d'ouest en est (franchie par le vieux pont et deux passerelles).
const WALK_RIVER: Array[Vector2] = [Vector2(-76.5, -20.25), Vector2(-49.5, -18.9), Vector2(-27, -16.65), Vector2(0, -13.5), Vector2(18, -12.6), Vector2(36, -14.4), Vector2(76.5, -12.15)]
const WALK_SCALE := 10.0
## Limites du quartier (mètres de jeu) : début du sable et rivage, au nord.
const WALK_SAND_Z := -48.0
const WALK_SHORE_Z := -65.25
## Endurance de promenade (mètres affichés) : grandit avec le niveau du compagnon.
static func walk_endurance(level: int) -> float:
	return minf(1050.0 + 180.0 * float(maxi(1, level) - 1), 7500.0)

static func walk_neighbors(id: String) -> Array:
	var out: Array = []
	for e in WALK_EDGES:
		if e[0] == id:
			out.append(e[1])
		elif e[1] == id:
			out.append(e[0])
	return out

static func walk_edge_len(a: String, b: String) -> float:
	return (WALK_NODES[a]["pos"] as Vector2).distance_to(WALK_NODES[b]["pos"]) * WALK_SCALE

# ------------------------------------------------------------------ Compétitions
const COMP_CATS := {
	"obedience": {"name": "Obéissance", "icon": "obedience", "desc": "Exécutez une série d'ordres le plus vite possible.", "skills": ["sit", "down", "stand", "come", "stay"]},
	"agility": {"name": "Agilité", "icon": "agility", "desc": "Franchissez les obstacles avec le meilleur chrono.", "skills": ["jump"]},
	"search": {"name": "Recherche", "icon": "search", "desc": "Retrouvez les objets cachés avec un minimum d'essais.", "skills": []},
	"tricks": {"name": "Dressage avancé", "icon": "tricks", "desc": "Enchaînez les tours avec style.", "skills": ["paw", "spin", "jump", "beg"]},
	"walk": {"name": "Défi de promenade", "icon": "walk", "desc": "Bouclez l'itinéraire vite en ramassant un maximum de trouvailles.", "skills": []},
}
const COMP_ORDER: Array[String] = ["obedience", "agility", "search", "tricks", "walk"]
## Itinéraire du défi de promenade selon le niveau du concours
const COMP_WALK_ROUTES: Array[String] = ["garden_loop", "park_pond", "forest_ferns", "beach_shore"]
const COMP_LEVELS := [
	{"name": "Débutant", "fee": 20, "player_level": 1, "relation": 1, "skill": 30.0, "rivals": 45.0, "prize": 80, "xp": 60},
	{"name": "Confirmé", "fee": 50, "player_level": 3, "relation": 3, "skill": 50.0, "rivals": 60.0, "prize": 180, "xp": 120},
	{"name": "Expert", "fee": 100, "player_level": 6, "relation": 5, "skill": 70.0, "rivals": 72.0, "prize": 380, "xp": 220},
	{"name": "Champion", "fee": 200, "player_level": 9, "relation": 7, "skill": 85.0, "rivals": 82.0, "prize": 800, "xp": 400},
]
const RIVAL_NAMES: Array[String] = ["Biscotte", "Filou", "Nala", "Pépite", "Moka", "Rocky", "Lulu", "Caramel", "Oslo", "Praline", "Tornade", "Gribouille", "Simba", "Noisette", "Pixel", "Grizzly"]

# ------------------------------------------------------------------ Progression
const RELATION_XP: Array[int] = [0, 60, 160, 320, 550, 850, 1250, 1750, 2400, 3200]
const RELATION_NAMES: Array[String] = ["Inconnu", "Curieux", "Copain", "Complice", "Ami", "Grand ami", "Inséparable", "Âme sœur", "Légende", "Lien éternel"]
const MAX_PLAYER_LEVEL := 30
const ADOPT_PRICE := 300

static func xp_for_level(lv: int) -> int:
	return int(round(80.0 * pow(float(lv), 1.45)))

const ACHIEVEMENTS := {
	"first_pet": {"name": "Premier compagnon", "desc": "Adopter un animal.", "stat": "adopted", "value": 1, "reward": 50},
	"two_pets": {"name": "La famille s'agrandit", "desc": "Adopter 2 animaux.", "stat": "adopted", "value": 2, "reward": 150},
	"feeder": {"name": "Cordon bleu", "desc": "Nourrir 20 fois.", "stat": "feed", "value": 20, "reward": 80},
	"cuddles": {"name": "Câlinothérapie", "desc": "Caresser 200 fois.", "stat": "pet", "value": 200, "reward": 80},
	"bath": {"name": "Tout propre", "desc": "Donner 10 bains.", "stat": "bath", "value": 10, "reward": 80},
	"photographer": {"name": "Paparazzi", "desc": "Prendre 10 photos.", "stat": "photo", "value": 10, "reward": 60},
	"thrower": {"name": "Bras d'or", "desc": "Lancer 50 fois la balle.", "stat": "throw", "value": 50, "reward": 100},
	"student": {"name": "Bon élève", "desc": "Maîtriser une commande.", "stat": "mastered", "value": 1, "reward": 100},
	"professor": {"name": "Professeur", "desc": "Maîtriser 5 commandes.", "stat": "mastered", "value": 5, "reward": 300},
	"genius": {"name": "Génie canin", "desc": "Maîtriser toutes les commandes.", "stat": "mastered", "value": 10, "reward": 800},
	"first_comp": {"name": "Premiers pas", "desc": "Participer à une compétition.", "stat": "comp", "value": 1, "reward": 50},
	"winner": {"name": "Champion !", "desc": "Gagner une compétition.", "stat": "comp_win", "value": 1, "reward": 150},
	"champion": {"name": "Collectionneur de coupes", "desc": "Gagner 10 compétitions.", "stat": "comp_win", "value": 10, "reward": 600},
	"walker": {"name": "Randonneur", "desc": "Faire 10 promenades.", "stat": "walk", "value": 10, "reward": 120},
	"finder": {"name": "Fin limier", "desc": "Trouver 30 objets cachés.", "stat": "found", "value": 30, "reward": 150},
	"collector": {"name": "Trésors de balade", "desc": "Ramasser 50 trouvailles.", "stat": "collect", "value": 50, "reward": 150},
	"rich": {"name": "Tirelire", "desc": "Gagner 2000 pièces au total.", "stat": "coins_earned", "value": 2000, "reward": 200},
	"bff": {"name": "Meilleurs amis", "desc": "Atteindre le niveau de relation 5.", "stat": "relation_max", "value": 5, "reward": 250},
	"loyal": {"name": "Fidèle au poste", "desc": "Jouer 7 jours différents.", "stat": "days", "value": 7, "reward": 300},
	"decorator": {"name": "Décorateur", "desc": "Posséder 8 décorations.", "stat": "decos", "value": 8, "reward": 150},
	"agile": {"name": "Éclair", "desc": "Finir un parcours sans faute.", "stat": "agility_clean", "value": 1, "reward": 120},
	"level10": {"name": "Expert animalier", "desc": "Atteindre le niveau 10.", "stat": "level", "value": 10, "reward": 500},
}

## Missions du jour : la cible et la récompense augmentent avec le palier du compagnon
## (palier 0 : niv. 1-3, 1 : niv. 4-7, 2 : niv. 8+). min = niveau minimum pour apparaître.
## Missions et objectifs. "need" limite une mission aux fonctions déjà débloquées :
## "act:<activité>" (niveau du compagnon), "env:<lieu>" (lieu acheté), "cmd" (au moins un ordre appris).
## "target" : cible par palier de niveau (débutant, confirmé, expert). "cat" sert à varier le tirage.
const DAILY_POOL := [
	{"id": "d_feed", "cat": "soin", "text": "Nourrir votre compagnon %d fois", "stat": "feed", "target": [2, 2, 3], "reward": 30},
	{"id": "d_water", "cat": "soin", "text": "Remplir %d fois la gamelle d'eau", "stat": "water", "target": [1, 2, 2], "reward": 20},
	{"id": "d_pet", "cat": "soin", "text": "Faire %d caresses", "stat": "pet", "target": [20, 30, 40], "reward": 25},
	{"id": "d_treat", "cat": "soin", "text": "Donner %d friandises", "stat": "treat", "target": [2, 3, 4], "reward": 20},
	{"id": "d_bath", "cat": "soin", "text": "Donner %d bain", "stat": "bath", "target": [1, 1, 1], "reward": 30},
	{"id": "d_brush", "cat": "soin", "text": "Brosser votre compagnon %d fois", "stat": "brush", "target": [1, 1, 2], "reward": 20},
	{"id": "d_cuddle", "cat": "soin", "text": "Partager %d moment câlin", "stat": "cuddle", "target": [1, 1, 2], "reward": 20},
	{"id": "d_photo", "cat": "jeu", "text": "Prendre %d photos", "stat": "photo", "target": [2, 2, 3], "reward": 20},
	{"id": "d_throw", "cat": "jeu", "text": "Lancer %d fois un jouet", "stat": "throw", "target": [8, 12, 16], "reward": 30},
	{"id": "d_toy", "cat": "jeu", "text": "Le laisser jouer %d fois avec son jouet", "stat": "toy_play", "target": [1, 2, 2], "reward": 20},
	{"id": "d_tug", "cat": "jeu", "text": "Jouer %d fois à la corde", "stat": "tug", "target": [1, 2, 2], "reward": 25, "need": "act:tug"},
	{"id": "d_tugwin", "cat": "jeu", "text": "Gagner %d fois à la corde", "stat": "tug_win", "target": [1, 1, 2], "reward": 35, "need": "act:tug"},
	{"id": "d_train", "cat": "dressage", "text": "Réussir %d exercices de dressage", "stat": "train_ok", "target": [3, 5, 8], "reward": 40},
	{"id": "d_order", "cat": "dressage", "text": "Faire obéir %d fois à un ordre", "stat": "order_ok", "target": [3, 5, 8], "reward": 30, "need": "cmd"},
	{"id": "d_walk", "cat": "balade", "text": "Faire %d balade", "stat": "walk", "target": [1, 1, 2], "reward": 40},
	{"id": "d_walkm", "cat": "balade", "text": "Parcourir %d m en balade", "stat": "walk_m", "target": [400, 800, 1400], "reward": 45},
	{"id": "d_poi", "cat": "balade", "text": "Visiter %d lieux du quartier", "stat": "poi", "target": [2, 3, 5], "reward": 35},
	{"id": "d_collect", "cat": "balade", "text": "Ramasser %d trouvailles", "stat": "collect", "target": [3, 5, 7], "reward": 30},
	{"id": "d_meet", "cat": "balade", "text": "Saluer %d autre chien", "stat": "meet", "target": [1, 1, 2], "reward": 25},
	{"id": "d_poop", "cat": "balade", "text": "Ramasser %d crotte en balade", "stat": "poop", "target": [1, 1, 1], "reward": 20},
	{"id": "d_sell", "cat": "balade", "text": "Vendre %d objets à la boutique", "stat": "sold", "target": [2, 4, 6], "reward": 25},
	{"id": "d_buy", "cat": "balade", "text": "Acheter %d article dans un commerce", "stat": "bought", "target": [1, 2, 3], "reward": 20},
	{"id": "d_fetchpark", "cat": "balade", "text": "Jouer %d fois à la balle au parc ou au pré", "stat": "fetch_game", "target": [1, 1, 2], "reward": 35},
	{"id": "d_find", "cat": "jeu", "text": "Trouver %d objets cachés", "stat": "found", "target": [2, 3, 5], "reward": 35, "need": "act:search"},
	{"id": "d_agility", "cat": "jeu", "text": "Terminer %d parcours d'agilité", "stat": "agility_run", "target": [1, 1, 2], "reward": 40, "need": "act:agility"},
	{"id": "d_comp", "cat": "jeu", "text": "Participer à %d concours", "stat": "comp", "target": [1, 1, 2], "reward": 50, "need": "act:competition"},
]
## Objectifs du jour : plus larges, ils récompensent une journée bien remplie.
const DAILY_GOALS := [
	{"id": "g_missions", "text": "Terminer %d missions du jour", "stat": "mission", "target": [3, 4, 5], "reward": 60},
	{"id": "g_coins", "text": "Gagner %d pièces aujourd'hui", "stat": "coins_gain", "target": [80, 150, 250], "reward": 40},
	{"id": "g_xp", "text": "Gagner %d points d'expérience", "stat": "xp_gain", "target": [60, 120, 200], "reward": 40},
	{"id": "g_care", "text": "Prendre soin de lui %d fois (repas, eau, bain, brossage, câlin)", "stat": "care_any", "target": [4, 6, 8], "reward": 45},
	{"id": "g_play", "text": "Jouer %d fois avec lui (balle, corde, jouet, jeux)", "stat": "play_any", "target": [3, 4, 6], "reward": 45},
	{"id": "g_walkm", "text": "Parcourir %d m en balade", "stat": "walk_m", "target": [600, 1200, 2000], "reward": 55},
]
const WEEKLY_POOL := [
	{"id": "w_feed", "cat": "soin", "text": "Nourrir votre compagnon %d fois", "stat": "feed", "target": [10, 12, 14], "reward": 120},
	{"id": "w_bath", "cat": "soin", "text": "Donner %d bains", "stat": "bath", "target": [2, 3, 4], "reward": 110},
	{"id": "w_brush", "cat": "soin", "text": "Brosser votre compagnon %d fois", "stat": "brush", "target": [4, 5, 7], "reward": 100},
	{"id": "w_cuddle", "cat": "soin", "text": "Partager %d moments câlins", "stat": "cuddle", "target": [5, 7, 9], "reward": 100},
	{"id": "w_pet", "cat": "soin", "text": "Faire %d caresses", "stat": "pet", "target": [120, 180, 250], "reward": 110},
	{"id": "w_throw", "cat": "jeu", "text": "Lancer %d fois un jouet", "stat": "throw", "target": [40, 60, 90], "reward": 130},
	{"id": "w_photo", "cat": "jeu", "text": "Prendre %d photos", "stat": "photo", "target": [8, 10, 14], "reward": 90},
	{"id": "w_tug", "cat": "jeu", "text": "Gagner %d fois à la corde", "stat": "tug_win", "target": [3, 5, 7], "reward": 140, "need": "act:tug"},
	{"id": "w_train", "cat": "dressage", "text": "Réussir %d exercices de dressage", "stat": "train_ok", "target": [20, 35, 50], "reward": 160},
	{"id": "w_order", "cat": "dressage", "text": "Faire obéir %d fois à un ordre", "stat": "order_ok", "target": [20, 30, 45], "reward": 130, "need": "cmd"},
	{"id": "w_walk", "cat": "balade", "text": "Faire %d balades", "stat": "walk", "target": [4, 5, 7], "reward": 160},
	{"id": "w_walkm", "cat": "balade", "text": "Parcourir %d m en balade", "stat": "walk_m", "target": [3000, 6000, 10000], "reward": 180},
	{"id": "w_poi", "cat": "balade", "text": "Visiter %d lieux du quartier", "stat": "poi", "target": [10, 16, 24], "reward": 150},
	{"id": "w_collect", "cat": "balade", "text": "Ramasser %d trouvailles", "stat": "collect", "target": [15, 25, 35], "reward": 140},
	{"id": "w_meet", "cat": "balade", "text": "Saluer %d autres chiens", "stat": "meet", "target": [4, 6, 8], "reward": 110},
	{"id": "w_sell", "cat": "balade", "text": "Vendre %d objets à la boutique", "stat": "sold", "target": [10, 16, 24], "reward": 120},
	{"id": "w_find", "cat": "jeu", "text": "Trouver %d objets cachés", "stat": "found", "target": [10, 15, 22], "reward": 150, "need": "act:search"},
	{"id": "w_agility", "cat": "jeu", "text": "Terminer %d parcours d'agilité", "stat": "agility_run", "target": [3, 5, 7], "reward": 170, "need": "act:agility"},
	{"id": "w_comp", "cat": "jeu", "text": "Participer à %d concours", "stat": "comp", "target": [2, 3, 5], "reward": 200, "need": "act:competition"},
]
const WEEKLY_GOALS := [
	{"id": "wg_days", "text": "Jouer %d jours différents cette semaine", "stat": "days", "target": [4, 5, 6], "reward": 200},
	{"id": "wg_missions", "text": "Terminer %d missions du jour", "stat": "mission", "target": [12, 18, 25], "reward": 250},
	{"id": "wg_dailyall", "text": "Terminer toutes les missions du jour %d fois", "stat": "daily_all", "target": [2, 3, 4], "reward": 220},
	{"id": "wg_coins", "text": "Gagner %d pièces", "stat": "coins_gain", "target": [600, 1100, 1800], "reward": 160},
	{"id": "wg_xp", "text": "Gagner %d points d'expérience", "stat": "xp_gain", "target": [400, 800, 1300], "reward": 160},
]
const DAILY_COUNT := 5
const WEEKLY_COUNT := 6
const GOAL_COUNT := 3
## Récompense de connexion (cycle de 7 jours) : [pièces, objet, quantité]
const LOGIN_REWARDS := [[30, "", 0], [0, "biscuit", 3], [50, "", 0], [0, "kibble", 2], [80, "", 0], [0, "cookie", 2], [150, "shampoo", 1]]

# ------------------------------------------------------------------ Déblocages (niveau du compagnon le plus avancé)
const BREED_LEVELS := {"labrador": 1, "shiba": 1, "cat": 1, "beagle": 2, "poodle": 4, "shepherd": 6}
const PALETTE_LEVELS := [1, 1, 3, 5, 7]
const EYE_LEVELS := [1, 1, 2, 3, 5]

# ------------------------------------------------------------------ Agilité
const AGILITY_LEVELS := [
	{"name": "Initiation", "obstacles": 4, "kinds": ["hurdle", "tunnel"], "layouts": ["oval"], "window": 2.4, "speed": 0.85, "pet_level": 3, "energy": 15.0, "cmds": {}, "coins": 20, "xp": 25},
	{"name": "Débutant", "obstacles": 6, "kinds": ["hurdle", "tunnel", "weave", "hoop"], "layouts": ["oval", "serpentine"], "window": 2.1, "speed": 0.95, "pet_level": 4, "energy": 20.0, "cmds": {"jump": 20.0}, "coins": 35, "xp": 40},
	{"name": "Intermédiaire", "obstacles": 8, "kinds": ["hurdle", "tunnel", "weave", "hoop", "platform", "stop"], "layouts": ["serpentine", "figure8", "loop"], "window": 1.8, "speed": 1.05, "pet_level": 6, "energy": 25.0, "cmds": {"jump": 40.0, "sit": 30.0}, "coins": 55, "xp": 60},
	{"name": "Avancé", "obstacles": 10, "kinds": ["hurdle", "tunnel", "weave", "hoop", "platform", "stop", "walkway", "combo"], "layouts": ["figure8", "loop", "serpentine"], "window": 1.6, "speed": 1.15, "pet_level": 9, "energy": 30.0, "cmds": {"jump": 55.0, "stay": 40.0}, "coins": 80, "xp": 85},
	{"name": "Expert", "obstacles": 12, "kinds": ["hurdle", "tunnel", "weave", "hoop", "platform", "stop", "walkway", "combo"], "layouts": ["oval", "serpentine", "figure8", "loop"], "window": 1.35, "speed": 1.3, "pet_level": 13, "energy": 35.0, "cmds": {"jump": 70.0, "stay": 60.0, "sit": 50.0}, "coins": 120, "xp": 120},
]
const AGILITY_OBSTACLES := {
	"hurdle": {"name": "Haie", "action": "Saute !", "icon": "hurdle", "span": 0.0},
	"tunnel": {"name": "Tunnel", "action": "Baisse-toi !", "icon": "tunnel", "span": 1.5},
	"weave": {"name": "Slalom", "action": "Slalome !", "icon": "weave", "span": 1.8},
	"hoop": {"name": "Cerceau", "action": "Traverse !", "icon": "hoop", "span": 0.0},
	"platform": {"name": "Plateforme", "action": "Monte !", "icon": "platform", "span": 1.2},
	"walkway": {"name": "Passerelle", "action": "Avance !", "icon": "walkway", "span": 2.6},
	"stop": {"name": "Zone d'arrêt", "action": "Stop !", "icon": "stop_zone", "span": 0.8},
	"combo": {"name": "Combiné", "action": "Enchaîne !", "icon": "combo", "span": 0.0},
}
const AGILITY_LAYOUT_NAMES := {"oval": "Ovale", "serpentine": "Serpentin", "figure8": "Huit", "loop": "Boucle"}
## Médailles : [clé, note minimale, nom]
const MEDALS := [["gold", 85.0, "Or"], ["silver", 65.0, "Argent"], ["bronze", 45.0, "Bronze"]]

static func medal_for(score: float) -> String:
	for m in MEDALS:
		if score >= float(m[1]):
			return str(m[0])
	return ""

static func medal_name(key: String) -> String:
	for m in MEDALS:
		if str(m[0]) == key:
			return str(m[2])
	return ""

# ------------------------------------------------------------------ Promenades
## length = distance affichée en mètres (1 m de jeu = 10 m affichés), diff 1..3, level = niveau du compagnon requis.
const ROUTES := [
	{"id": "garden_loop", "env": "garden", "name": "Tour du jardin", "length": 150, "diff": 1, "level": 1, "finds": 2, "desc": "Une petite boucle tranquille autour de la pelouse."},
	{"id": "park_pond", "env": "park", "name": "Boucle de l'étang", "length": 300, "diff": 1, "level": 1, "finds": 3, "desc": "Le tour de l'étang, on y croise souvent d'autres chiens."},
	{"id": "park_alley", "env": "park", "name": "Grande allée", "length": 550, "diff": 2, "level": 3, "finds": 4, "desc": "Une longue promenade ombragée sous les arbres."},
	{"id": "forest_ferns", "env": "forest", "name": "Sentier des fougères", "length": 400, "diff": 2, "level": 3, "finds": 4, "desc": "Un sentier riche en odeurs et en trésors."},
	{"id": "forest_ridge", "env": "forest", "name": "Crête des sapins", "length": 750, "diff": 3, "level": 6, "finds": 5, "desc": "Une longue randonnée pour chiens endurants."},
	{"id": "beach_shore", "env": "beach", "name": "Bord de mer", "length": 450, "diff": 2, "level": 4, "finds": 4, "desc": "Les pattes dans le sable, le nez au vent."},
	{"id": "beach_dunes", "env": "beach", "name": "Les dunes", "length": 800, "diff": 3, "level": 7, "finds": 5, "desc": "Un parcours exigeant entre dunes et rochers."},
]
const ROUTE_DIFF_NAMES := ["", "Facile", "Moyen", "Difficile"]

static func route(id: String) -> Dictionary:
	for r in ROUTES:
		if r["id"] == id:
			return r
	return {}

# ------------------------------------------------------------------ Recherche
## tries = erreurs tolérées, clues = usages du flair, rare = chance d'objet rare par objet caché
const SEARCH_LEVELS := [
	{"name": "Facile", "spots": 4, "tries": 3, "objects": 1, "clues": 2, "rare": 0.03, "reward": 25, "xp": 15},
	{"name": "Simple", "spots": 6, "tries": 4, "objects": 2, "clues": 2, "rare": 0.06, "reward": 45, "xp": 25},
	{"name": "Moyen", "spots": 8, "tries": 4, "objects": 3, "clues": 2, "rare": 0.1, "reward": 70, "xp": 35},
	{"name": "Difficile", "spots": 10, "tries": 5, "objects": 3, "clues": 1, "rare": 0.14, "reward": 100, "xp": 45},
	{"name": "Expert", "spots": 12, "tries": 5, "objects": 4, "clues": 1, "rare": 0.2, "reward": 140, "xp": 60},
]
const SEARCH_ENVS: Array[String] = ["house", "garden", "park", "forest", "beach", "center"]
## Cachettes : kind -> nom affiché (le lieu fournit position, type et libellé précis)
const HIDE_KINDS := {
	"under": "sous un meuble", "cushion": "sous un coussin", "box": "dans un carton", "basket": "dans un panier",
	"bush": "dans un buisson", "leaves": "sous un tas de feuilles", "rock": "derrière un rocher", "log": "derrière un tronc",
	"flowerbed": "dans les fleurs", "sand": "sous le sable", "crate": "dans une caisse", "tire": "dans un pneu",
}
## Objets que l'on peut trouver en recherche, en plus des objets de collection du lieu
const SEARCH_TOYS: Array[String] = ["tennis", "disc", "rope", "plush"]
const SEARCH_ACCESSORIES: Array[String] = ["hat", "glasses", "scarf"]

## Objets de collection disponibles dans un lieu (rareté facultative).
static func collectibles(env: String, rarity: int = 0) -> Array[String]:
	var out: Array[String] = []
	for id in ITEMS.keys():
		var it: Dictionary = ITEMS[id]
		if it.get("cat", "") != "collection":
			continue
		if not (it.get("envs", []) as Array).has(env):
			continue
		if rarity > 0 and int(it.get("rarity", 1)) != rarity:
			continue
		out.append(id)
	return out

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func breed(id: String) -> Dictionary:
	return BREEDS.get(id, BREEDS["labrador"])
