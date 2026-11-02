package com.neonrush.core;

/** Catalogue des skins. Les couleurs sont au format ARGB. */
public final class Skins {
    public static final int TRAIL_RIBBON = 0, TRAIL_EMBERS = 1, TRAIL_ZIGZAG = 2, TRAIL_HELIX = 3,
            TRAIL_RAINBOW = 4, TRAIL_GLITCH = 5, TRAIL_SPARKLE = 6, TRAIL_DRIP = 7, TRAIL_STARS = 8;
    public static final int DECO_NONE = 0, DECO_PULSE = 1, DECO_RAYS = 2, DECO_FACETS = 3, DECO_MOONS = 4,
            DECO_RGB = 5, DECO_DARK = 6, DECO_RINGS = 7, DECO_CORE = 8, DECO_SPIKES = 9, DECO_DNA = 10;

    public static final class Skin {
        public final String name, tagline;
        public final int price, core, glow, accent, trail, deco;

        Skin(String name, String tagline, int price, int core, int glow, int accent, int trail, int deco) {
            this.name = name; this.tagline = tagline; this.price = price;
            this.core = core; this.glow = glow; this.accent = accent; this.trail = trail; this.deco = deco;
        }
    }

    public static final Skin[] ALL = {
            new Skin("NOVA", "L'étincelle d'origine", 0, 0xFFE8FFFF, 0xFF00E5FF, 0xFF7DF9FF, TRAIL_RIBBON, DECO_NONE),
            new Skin("PULSAR", "Bat au rythme du néon", 100, 0xFFFFE0F7, 0xFFFF2BD6, 0xFFFF7BE9, TRAIL_RIBBON, DECO_PULSE),
            new Skin("BRAISE", "Laisse des cendres ardentes", 150, 0xFFFFF1D6, 0xFFFF7A1A, 0xFFFFC14D, TRAIL_EMBERS, DECO_CORE),
            new Skin("VOLT", "Survolté en permanence", 250, 0xFFF7FFD9, 0xFFB6FF1F, 0xFFFFF04D, TRAIL_ZIGZAG, DECO_SPIKES),
            new Skin("GIVRE", "Cristal de glace pure", 350, 0xFFFFFFFF, 0xFF8FD8FF, 0xFFD6F3FF, TRAIL_SPARKLE, DECO_FACETS),
            new Skin("ABYSSE", "Lueur des profondeurs", 500, 0xFF2A0F4D, 0xFF9B4DFF, 0xFFC99BFF, TRAIL_RIBBON, DECO_DARK),
            new Skin("VENIN", "Toxique et instable", 650, 0xFFE9FFE0, 0xFF39FF6A, 0xFF9DFF4D, TRAIL_DRIP, DECO_PULSE),
            new Skin("SOLAR", "Une couronne de feu", 800, 0xFFFFFBE6, 0xFFFFC21A, 0xFFFF8A00, TRAIL_EMBERS, DECO_RAYS),
            new Skin("GLITCH", "Erreur de rendu volontaire", 1000, 0xFFFFFFFF, 0xFF00F0FF, 0xFFFF1F8F, TRAIL_GLITCH, DECO_RGB),
            new Skin("ORBITE", "Escorté par deux lunes", 1250, 0xFFFFFFFF, 0xFF6F8BFF, 0xFFB8C6FF, TRAIL_RIBBON, DECO_MOONS),
            new Skin("HÉLIX", "Code génétique lumineux", 1500, 0xFFFFFFFF, 0xFF00E5FF, 0xFFFF2BD6, TRAIL_HELIX, DECO_DNA),
            new Skin("VIDE", "Horizon des événements", 1800, 0xFF000000, 0xFFB026FF, 0xFFFF2BD6, TRAIL_STARS, DECO_DARK),
            new Skin("PRISME", "Toutes les couleurs à la fois", 2200, 0xFFFFFFFF, 0xFFFF2BD6, 0xFF00E5FF, TRAIL_RAINBOW, DECO_FACETS),
            new Skin("SINGULARITÉ", "La légende de la grille", 2800, 0xFFFFFFFF, 0xFFFFD36B, 0xFFFF2BD6, TRAIL_STARS, DECO_RINGS),
    };

    public static int count() { return ALL.length; }

    public static Skin get(int i) { return ALL[(i < 0 || i >= ALL.length) ? 0 : i]; }

    private Skins() {}
}
