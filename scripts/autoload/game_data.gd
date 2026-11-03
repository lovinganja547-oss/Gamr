extends Node
## Données statiques du jeu (races, objets, commandes, compétitions, succès…).
## Toutes les chaînes affichées passent par tr() côté interface.

const SAVE_VERSION := 1
const NEED_KEYS: Array[String] = ["hunger", "thirst", "clean", "energy", "mood", "health", "affection"]
const NEED_NAMES := {
	"hunger": "Faim", "thirst": "Soif", "clean": "Propreté", "energy": "Énergie",
	"mood": "Humeur", "health": "Santé", "affection": "Affection",
}
const NEED_ICONS := {
	"hunger": "🍖", "thirst": "💧", "clean": "🫧", "energy": "⚡",
	"mood": "😊", "health": "❤️", "affection": "💞",
}
const NEED_COLORS := {
	"hunger": Color(0.96, 0.6, 0.3), "thirst": Color(0.35, 0.7, 0.98), "clean": Color(0.55, 0.85, 0.95),
	"energy": Color(0.98, 0.85, 0.3), "mood": Color(0.65, 0.85, 0.4), "health": Color(0.95, 0.4, 0.45),
	"affection": Color(0.95, 0.5, 0.75),
}

# ------------------------------------------------------------------ Races
# Proportions en mètres (échelle « jouet »). pattern = motif de pelage procédural.
const BREEDS := {
	"labrador": {
		"name": "Labrador", "species": "dog", "voice": "bark_mid",
		"desc": "Gentil et gourmand, il adore rapporter tout ce qu'on lui lance.",
		"body": Vector3(0.30, 0.27, 0.56), "leg_len": 0.27, "leg_rad": 0.065, "head": 0.19,
		"snout": Vector2(0.15, 0.085), "ear": "floppy", "ear_size": 0.11, "tail": "otter",
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
		"body": Vector3(0.24, 0.22, 0.44), "leg_len": 0.22, "leg_rad": 0.052, "head": 0.165,
		"snout": Vector2(0.11, 0.07), "ear": "pointy", "ear_size": 0.085, "tail": "curl",
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
		"body": Vector3(0.22, 0.24, 0.40), "leg_len": 0.30, "leg_rad": 0.045, "head": 0.155,
		"snout": Vector2(0.14, 0.06), "ear": "fluffy", "ear_size": 0.09, "tail": "pompom",
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
		"body": Vector3(0.30, 0.28, 0.62), "leg_len": 0.31, "leg_rad": 0.065, "head": 0.18,
		"snout": Vector2(0.18, 0.08), "ear": "pointy", "ear_size": 0.12, "tail": "bushy",
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
		"body": Vector3(0.24, 0.22, 0.46), "leg_len": 0.2, "leg_rad": 0.055, "head": 0.17,
		"snout": Vector2(0.13, 0.064), "ear": "long", "ear_size": 0.13, "tail": "whip",
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
		"body": Vector3(0.19, 0.19, 0.42), "leg_len": 0.18, "leg_rad": 0.04, "head": 0.15,
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
	"joueur": {"name": "Joueur", "desc": "Toujours partant pour jouer.", "mod": {"energy": 15, "obedience": -5}},
	"calme": {"name": "Calme", "desc": "Posé, il se fatigue moins vite.", "mod": {"energy": -15, "obedience": 10}},
	"tetu": {"name": "Têtu", "desc": "Il faut de la patience pour le dresser.", "mod": {"obedience": -20, "independence": 15}},
	"calin": {"name": "Câlin", "desc": "Il adore les caresses.", "mod": {"affection": 20}},
	"curieux": {"name": "Curieux", "desc": "Il fourre sa truffe partout.", "mod": {"curiosity": 20}},
	"gourmand": {"name": "Gourmand", "desc": "Les friandises le motivent énormément.", "mod": {"gluttony": 20}},
}

# ------------------------------------------------------------------ Commandes
# gesture : séquence de directions (U/D/L/R), "O" = cercle, "TT" = double tape.
const COMMANDS := {
	"sit": {"name": "Assis", "gesture": "D", "hint": "Glissez vers le bas", "difficulty": 1.0, "words": ["assis", "assieds"], "level": 1},
	"down": {"name": "Couché", "gesture": "DR", "hint": "Bas puis droite", "difficulty": 1.2, "words": ["couché", "couche"], "level": 1},
	"stand": {"name": "Debout", "gesture": "U", "hint": "Glissez vers le haut", "difficulty": 1.1, "words": ["debout"], "level": 1},
	"come": {"name": "Viens", "gesture": "TT", "hint": "Tapez deux fois", "difficulty": 1.0, "words": ["viens", "ici"], "level": 1},
	"paw": {"name": "Donne la patte", "gesture": "R", "hint": "Glissez vers la droite", "difficulty": 1.4, "words": ["patte"], "level": 2},
	"fetch": {"name": "Rapporte", "gesture": "L", "hint": "Glissez vers la gauche", "difficulty": 1.5, "words": ["rapporte"], "level": 2},
	"spin": {"name": "Tourne", "gesture": "O", "hint": "Dessinez un cercle", "difficulty": 1.6, "words": ["tourne"], "level": 3},
	"jump": {"name": "Saute", "gesture": "DU", "hint": "Bas puis haut", "difficulty": 1.8, "words": ["saute", "hop"], "level": 4},
	"beg": {"name": "Fais le beau", "gesture": "UDU", "hint": "Haut, bas, haut", "difficulty": 2.0, "words": ["beau"], "level": 5},
}
const COMMAND_ORDER: Array[String] = ["sit", "down", "stand", "come", "paw", "fetch", "spin", "jump", "beg"]
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
	"kibble": {"name": "Croquettes", "cat": "food", "icon": "🥣", "price": 10, "fx": {"hunger": 45, "mood": 3}, "desc": "Repas équilibré."},
	"pate": {"name": "Pâtée du chef", "cat": "food", "icon": "🍲", "price": 22, "fx": {"hunger": 60, "mood": 10, "health": 4}, "desc": "Un vrai régal."},
	"fish": {"name": "Poisson vapeur", "cat": "food", "icon": "🐟", "price": 28, "fx": {"hunger": 55, "mood": 12, "health": 6}, "desc": "Riche en oméga 3."},
	"veggie": {"name": "Bol de légumes", "cat": "food", "icon": "🥕", "price": 16, "fx": {"hunger": 35, "health": 10}, "desc": "Léger et sain."},
	# Friandises
	"biscuit": {"name": "Biscuit os", "cat": "treat", "icon": "🦴", "price": 5, "fx": {"hunger": 6, "mood": 8, "affection": 4}, "desc": "Parfait pour le dressage."},
	"chew": {"name": "Bâton à mâcher", "cat": "treat", "icon": "🥢", "price": 9, "fx": {"hunger": 8, "mood": 12, "clean": 2}, "desc": "Bon pour les dents."},
	"cheese": {"name": "Dés de fromage", "cat": "treat", "icon": "🧀", "price": 8, "fx": {"hunger": 5, "mood": 14, "affection": 3}, "desc": "Irrésistible."},
	"cookie": {"name": "Cookie au potiron", "cat": "treat", "icon": "🍪", "price": 12, "fx": {"hunger": 10, "mood": 18, "affection": 6}, "desc": "La friandise de luxe."},
	# Soins
	"shampoo": {"name": "Shampooing doux", "cat": "care", "icon": "🧴", "price": 15, "fx": {"clean": 20}, "desc": "Bain plus efficace (+20 propreté)."},
	"vitamins": {"name": "Vitamines", "cat": "care", "icon": "💊", "price": 30, "fx": {"health": 30}, "desc": "Redonne de la santé."},
	# Jouets
	"ball": {"name": "Balle rouge", "cat": "toy", "icon": "🔴", "price": 0, "color": Color(0.9, 0.2, 0.2), "toy": "ball", "desc": "La balle classique.", "bonus": 0},
	"tennis": {"name": "Balle fluo", "cat": "toy", "icon": "🎾", "price": 40, "color": Color(0.8, 0.95, 0.2), "toy": "ball", "desc": "Rebondit mieux (+10 % de score).", "bonus": 10},
	"disc": {"name": "Disque volant", "cat": "toy", "icon": "🥏", "price": 90, "color": Color(0.2, 0.6, 0.95), "toy": "disc", "desc": "Plane plus loin (+20 % de score).", "bonus": 20},
	"rope": {"name": "Corde nouée", "cat": "toy", "icon": "🪢", "price": 55, "color": Color(0.85, 0.75, 0.5), "toy": "rope", "desc": "Facile à attraper (+15 % de score).", "bonus": 15},
	"plush": {"name": "Peluche canard", "cat": "toy", "icon": "🦆", "price": 75, "color": Color(1.0, 0.85, 0.2), "toy": "plush", "desc": "Le doudou préféré (+humeur au jeu).", "bonus": 12},
	# Colliers
	"collar_red": {"name": "Collier rouge", "cat": "collar", "icon": "🔴", "price": 0, "color": Color(0.85, 0.2, 0.2), "desc": "Simple et chic."},
	"collar_blue": {"name": "Collier bleu", "cat": "collar", "icon": "🔵", "price": 0, "color": Color(0.2, 0.45, 0.9), "desc": "Bleu océan."},
	"collar_green": {"name": "Collier vert", "cat": "collar", "icon": "🟢", "price": 0, "color": Color(0.3, 0.75, 0.35), "desc": "Vert prairie."},
	"collar_pink": {"name": "Collier rose", "cat": "collar", "icon": "🩷", "price": 35, "color": Color(0.95, 0.5, 0.7), "desc": "Rose bonbon."},
	"collar_gold": {"name": "Collier doré", "cat": "collar", "icon": "🟡", "price": 150, "color": Color(0.95, 0.78, 0.25), "desc": "Pour les champions.", "metal": true},
	"collar_purple": {"name": "Collier violet", "cat": "collar", "icon": "🟣", "price": 60, "color": Color(0.55, 0.3, 0.8), "desc": "Majestueux."},
	# Accessoires
	"acc_none": {"name": "Aucun", "cat": "accessory", "icon": "✖️", "price": 0, "desc": "Rien du tout."},
	"bandana": {"name": "Bandana", "cat": "accessory", "icon": "🧣", "price": 0, "color": Color(0.9, 0.3, 0.3), "desc": "Style aventurier."},
	"bow": {"name": "Nœud", "cat": "accessory", "icon": "🎀", "price": 0, "color": Color(0.95, 0.45, 0.65), "desc": "Adorable."},
	"hat": {"name": "Chapeau de paille", "cat": "accessory", "icon": "👒", "price": 80, "color": Color(0.92, 0.8, 0.5), "desc": "Idéal pour la plage."},
	"crown": {"name": "Couronne", "cat": "accessory", "icon": "👑", "price": 300, "color": Color(1.0, 0.82, 0.2), "desc": "Réservée aux stars.", "level": 6},
	"glasses": {"name": "Lunettes de soleil", "cat": "accessory", "icon": "🕶️", "price": 120, "color": Color(0.1, 0.1, 0.12), "desc": "Trop cool."},
	"scarf": {"name": "Écharpe", "cat": "accessory", "icon": "🧶", "price": 70, "color": Color(0.3, 0.55, 0.85), "desc": "Toute douce."},
	# Décorations (maison)
	"rug_round": {"name": "Tapis rond", "cat": "deco", "slot": "rug", "icon": "⭕", "price": 0, "color": Color(0.85, 0.55, 0.45), "desc": "Tapis de base."},
	"rug_blue": {"name": "Tapis océan", "cat": "deco", "slot": "rug", "icon": "🟦", "price": 60, "color": Color(0.35, 0.55, 0.85), "desc": "Fraîcheur garantie."},
	"rug_green": {"name": "Tapis mousse", "cat": "deco", "slot": "rug", "icon": "🟩", "price": 60, "color": Color(0.45, 0.72, 0.45), "desc": "Doux comme l'herbe."},
	"bed_basic": {"name": "Panier simple", "cat": "deco", "slot": "bed", "icon": "🧺", "price": 0, "color": Color(0.7, 0.45, 0.3), "desc": "Confortable."},
	"bed_cloud": {"name": "Coussin nuage", "cat": "deco", "slot": "bed", "icon": "☁️", "price": 120, "color": Color(0.85, 0.88, 0.98), "desc": "Récupère l'énergie 30 % plus vite.", "bonus": 30},
	"bed_royal": {"name": "Lit royal", "cat": "deco", "slot": "bed", "icon": "🛏️", "price": 260, "color": Color(0.6, 0.25, 0.45), "desc": "Récupère l'énergie 60 % plus vite.", "bonus": 60, "level": 5},
	"plant_fern": {"name": "Fougère", "cat": "deco", "slot": "plant", "icon": "🌿", "price": 40, "color": Color(0.3, 0.65, 0.3), "desc": "Un coin de verdure."},
	"plant_cactus": {"name": "Cactus", "cat": "deco", "slot": "plant", "icon": "🌵", "price": 45, "color": Color(0.35, 0.6, 0.35), "desc": "Ne pas toucher !"},
	"plant_flowers": {"name": "Bouquet", "cat": "deco", "slot": "plant", "icon": "💐", "price": 55, "color": Color(0.95, 0.5, 0.6), "desc": "Des couleurs !"},
	"lamp_warm": {"name": "Lampe douce", "cat": "deco", "slot": "lamp", "icon": "💡", "price": 50, "color": Color(1.0, 0.85, 0.6), "desc": "Lumière chaleureuse."},
	"lamp_star": {"name": "Lampe étoile", "cat": "deco", "slot": "lamp", "icon": "⭐", "price": 90, "color": Color(1.0, 0.95, 0.5), "desc": "Magique."},
	"sofa_coral": {"name": "Canapé corail", "cat": "deco", "slot": "sofa", "icon": "🛋️", "price": 0, "color": Color(0.95, 0.55, 0.45), "desc": "Le canapé de base."},
	"sofa_teal": {"name": "Canapé lagon", "cat": "deco", "slot": "sofa", "icon": "🛋️", "price": 140, "color": Color(0.25, 0.6, 0.6), "desc": "Très tendance."},
	"sofa_mustard": {"name": "Canapé moutarde", "cat": "deco", "slot": "sofa", "icon": "🛋️", "price": 140, "color": Color(0.88, 0.7, 0.25), "desc": "Vintage."},
	"wall_cream": {"name": "Murs crème", "cat": "deco", "slot": "wall", "icon": "🟨", "price": 0, "color": Color(0.98, 0.93, 0.84), "desc": "Classique."},
	"wall_mint": {"name": "Murs menthe", "cat": "deco", "slot": "wall", "icon": "🟩", "price": 80, "color": Color(0.78, 0.92, 0.84), "desc": "Frais."},
	"wall_lilac": {"name": "Murs lilas", "cat": "deco", "slot": "wall", "icon": "🟪", "price": 80, "color": Color(0.88, 0.82, 0.95), "desc": "Doux."},
	"wall_peach": {"name": "Murs pêche", "cat": "deco", "slot": "wall", "icon": "🟧", "price": 80, "color": Color(0.99, 0.84, 0.74), "desc": "Chaleureux."},
	"frame_sun": {"name": "Tableau soleil", "cat": "deco", "slot": "frame", "icon": "🖼️", "price": 35, "color": Color(0.98, 0.75, 0.3), "desc": "Plein d'énergie."},
	"frame_sea": {"name": "Tableau mer", "cat": "deco", "slot": "frame", "icon": "🖼️", "price": 35, "color": Color(0.3, 0.6, 0.9), "desc": "Apaisant."},
	"toybox": {"name": "Coffre à jouets", "cat": "deco", "slot": "box", "icon": "🧰", "price": 70, "color": Color(0.55, 0.75, 0.95), "desc": "+5 humeur par jour au réveil."},
}
const SHOP_TABS: Array[String] = ["food", "treat", "care", "toy", "collar", "accessory", "deco", "env"]
const SHOP_TAB_NAMES := {
	"food": "Repas", "treat": "Friandises", "care": "Soins", "toy": "Jouets", "collar": "Colliers",
	"accessory": "Accessoires", "deco": "Déco", "env": "Lieux",
}
const CONSUMABLE_CATS: Array[String] = ["food", "treat", "care"]
const DECO_SLOTS: Array[String] = ["wall", "rug", "sofa", "bed", "plant", "lamp", "frame", "box"]
const DECO_SLOT_NAMES := {
	"wall": "Murs", "rug": "Tapis", "sofa": "Canapé", "bed": "Couchage", "plant": "Plante",
	"lamp": "Lampe", "frame": "Tableau", "box": "Rangement",
}

# ------------------------------------------------------------------ Lieux
const ENVIRONMENTS := {
	"house": {"name": "Maison", "icon": "🏠", "price": 0, "level": 1, "amb": "amb_house", "walk": false},
	"garden": {"name": "Jardin", "icon": "🌻", "price": 0, "level": 1, "amb": "amb_garden", "walk": true},
	"park": {"name": "Parc", "icon": "🌳", "price": 150, "level": 2, "amb": "amb_park", "walk": true},
	"beach": {"name": "Plage", "icon": "🏖️", "price": 400, "level": 4, "amb": "amb_beach", "walk": true},
	"center": {"name": "Centre de dressage", "icon": "🏟️", "price": 0, "level": 1, "amb": "amb_center", "walk": false},
	"shelter": {"name": "Refuge", "icon": "🏡", "price": 0, "level": 1, "amb": "amb_shelter", "walk": false},
}
const ENV_ORDER: Array[String] = ["house", "garden", "park", "beach", "center", "shelter"]

# ------------------------------------------------------------------ Compétitions
const COMP_CATS := {
	"obedience": {"name": "Obéissance", "icon": "🎓", "desc": "Exécutez une série d'ordres le plus vite possible.", "skills": ["sit", "down", "stand", "come"]},
	"agility": {"name": "Agilité", "icon": "🏃", "desc": "Franchissez les obstacles avec le meilleur chrono.", "skills": ["jump"]},
	"search": {"name": "Recherche", "icon": "👃", "desc": "Retrouvez les objets cachés avec un minimum d'essais.", "skills": []},
	"tricks": {"name": "Dressage avancé", "icon": "⭐", "desc": "Enchaînez les tours avec style.", "skills": ["paw", "spin", "jump", "beg"]},
}
const COMP_ORDER: Array[String] = ["obedience", "agility", "search", "tricks"]
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
	"genius": {"name": "Génie canin", "desc": "Maîtriser toutes les commandes.", "stat": "mastered", "value": 9, "reward": 800},
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

const DAILY_POOL := [
	{"id": "d_feed", "text": "Nourrir votre compagnon 2 fois", "stat": "feed", "target": 2, "reward": 30},
	{"id": "d_pet", "text": "Faire 30 caresses", "stat": "pet", "target": 30, "reward": 25},
	{"id": "d_train", "text": "Réussir 5 exercices de dressage", "stat": "train_ok", "target": 5, "reward": 40},
	{"id": "d_throw", "text": "Lancer 10 fois un jouet", "stat": "throw", "target": 10, "reward": 30},
	{"id": "d_walk", "text": "Faire une promenade", "stat": "walk", "target": 1, "reward": 40},
	{"id": "d_bath", "text": "Donner un bain", "stat": "bath", "target": 1, "reward": 25},
	{"id": "d_photo", "text": "Prendre 2 photos", "stat": "photo", "target": 2, "reward": 20},
	{"id": "d_find", "text": "Trouver 3 objets cachés", "stat": "found", "target": 3, "reward": 35},
	{"id": "d_comp", "text": "Participer à une compétition", "stat": "comp", "target": 1, "reward": 50},
	{"id": "d_agility", "text": "Terminer un parcours d'agilité", "stat": "agility_run", "target": 1, "reward": 40},
	{"id": "d_treat", "text": "Donner 3 friandises", "stat": "treat", "target": 3, "reward": 20},
]

const SEARCH_LEVELS := [
	{"spots": 4, "tries": 3, "objects": 1, "reward": 25},
	{"spots": 6, "tries": 4, "objects": 2, "reward": 45},
	{"spots": 8, "tries": 5, "objects": 3, "reward": 70},
	{"spots": 10, "tries": 5, "objects": 3, "reward": 100},
	{"spots": 12, "tries": 6, "objects": 4, "reward": 140},
]

const WALK_FINDS := {
	"garden": [["🌼", "Pâquerette"], ["🐌", "Escargot"], ["🍂", "Feuille d'automne"], ["🪱", "Ver de terre"], ["🍓", "Fraise des bois"]],
	"park": [["🌰", "Gland"], ["🪶", "Plume"], ["🍄", "Champignon"], ["🦋", "Papillon"], ["🪵", "Joli bâton"], ["🍁", "Feuille d'érable"]],
	"beach": [["🐚", "Coquillage"], ["⭐", "Étoile de mer"], ["🦀", "Petit crabe"], ["🪸", "Corail"], ["🫧", "Galet rond"], ["🌊", "Bois flotté"]],
}

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func breed(id: String) -> Dictionary:
	return BREEDS.get(id, BREEDS["labrador"])
