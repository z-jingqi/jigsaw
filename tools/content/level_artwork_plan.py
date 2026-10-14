"""Art direction for the 2026 content rebuild. Images use the built-in imagegen tool."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / ".artifacts/content-rebuild-20261005"

COMMON = (
    "Create one standalone full-bleed artwork for an adult jigsaw puzzle, portrait "
    "aspect ratio exactly 3:4, high resolution. One unified scene, not a collage. "
    "Elegant mature composition, natural anatomy, varied recognizable details throughout "
    "the frame for satisfying puzzling. No text, lettering, logos, watermark, borders, UI, "
    "puzzle grid or seams. No chibi, baby proportions, cute emoji faces, plastic 3D or cartoon. "
)

STYLES = {
    "topic_01": (
        "Refined luminous Chinese landscape fantasy illustration matching the supplied "
        "autumn nine-tailed fox: delicate flowing brush lines, soft painted scenery, "
        "layered atmospheric mountains, precise fur and feather detail. Each artwork "
        "has a distinct pose, environment and rich palette. No distressed paper or weathering. "
    ),
    "topic_02": (
        "Bright Mediterranean classical painting, expressive fine gouache brushwork, "
        "luminous daylight, turquoise and cobalt sea, cream marble, olive green, coral "
        "and warm ochre accents. Elegant classical adult proportions, clear sunlit "
        "layered compositions and graceful architecture. "
    ),
    "topic_03": (
        "Warm, detailed painterly gouache storybook illustration for adults, soft visible "
        "brushwork, restrained ochre, teal, moss green and rust palette, tactile still-life "
        "objects, natural cat anatomy and thoughtful light. Match the sensibility of a "
        "calico cat on green cushions in a sunlit plant-filled room, without copying that scene. "
    ),
    "topic_04": (
        "Traditional colored-pencil and soft pastel illustration, delicate pencil strokes, "
        "fresh sky blues, warm golden light, natural greens and orange accents. Friendly "
        "dogs with realistic proportions and lively believable gestures. Match a pencil "
        "painting of a beagle in a sunny wildflower meadow, with richer adult storytelling. "
    ),
    "theme_flowers": (
        "Elegant botanical gouache and watercolor illustration on warm ivory, fine contour "
        "lines, softly brushed opaque petals, sage leaves, dusty blush, cream, coral and "
        "small cobalt accents. Detailed mature decorative botanical art, balanced negative "
        "space and graceful overlapping stems, matching a refined floral garden plate. "
    ),
    "theme_ocean": (
        "Decorative fine painterly gouache and watercolor marine illustration, flowing "
        "contours, turquoise and deep blue water, cream, muted gold and coral rust details. "
        "Layered underwater life, natural animal anatomy, rich graceful ornament and "
        "subtle brush texture, matching an elegant whale-and-coral marine painting. "
    ),
    "theme_birds": (
        "Refined natural-history gouache bird illustration, detailed layered feather "
        "brushwork and delicate contour lines, warm ivory ground, muted teal, ochre, "
        "cobalt, coral and sage, elegant decorative flowering branches. Natural avian "
        "proportions, sophisticated botanical composition like a vintage bird plate, "
        "but clean and well preserved, no distressed paper. "
    ),
    "theme_forest": (
        "Quiet, detailed painterly gouache woodland illustration, soft layered brush "
        "strokes, moss and olive greens, warm amber and ivory light, gentle atmospheric "
        "depth, carefully observed animals and plants. Match an elegant stag among "
        "sunlit white birches; mature contemplative nature art with natural anatomy. "
    ),
}

# The cat_02 space-cat artwork is retained and encoded as WebP for the first cat level.
SCENES = {
    "topic_01": [
        ("九尾狐", "Use the supplied autumn nine-tailed fox artwork directly, for both cover and first level."),
        ("应龙渡海", "A mighty golden winged Chinese dragon flying above turquoise waves and dark jade sea cliffs; cinnabar clouds, distant island temples and seabirds, dramatic sweeping diagonal composition."),
        ("精卫衔石", "The mythic Jingwei bird with a patterned white beak carrying a small red stone toward an immense blue sea; coral shoreline pebbles, curling waves and flowering cliff plants."),
        ("白泽问山", "A wise elegant white horned lion-like Bai Ze beast on turquoise mountain steps beneath an ancient pine; open scrolls with no writing, flowers, patterned clouds and red temple roofs."),
        ("烛龙长夜", "A long majestic crimson Chinese dragon winding through a blue cavern and emerging beside a luminous gold sun, calm mythic presence, no horror; intricate cloud and water ornaments."),
        ("鲲鹏云海", "A giant blue mythic whale rising from a jade sea and transforming visually into a magnificent golden-winged Peng bird above swirling cloud bands; grand expansive scale and graceful movement."),
        ("凤凰梧桐", "A magnificent cinnabar phoenix with long patterned gold and blue tail feathers landing in a flowering parasol tree; ivory cloud ribbons, green hills and jewel-like flowers."),
        ("鹿蜀竹径", "The mythical Lushu, an elegant horse-shaped creature with white head, tiger-striped body and flowing red tail, walking through jade bamboo and ochre grasses beside a stream."),
        ("毕方流焰", "A single-legged blue crane-like Bifang with red markings standing elegantly amid stylized cinnabar flame-shaped leaves and ivory clouds; turquoise rocks, gold grasses and distant hills."),
        ("夔临雷泽", "A powerful mythic one-legged ox-like Kui on a rock in a circular turquoise lake; golden thunder-cloud spirals overhead, cinnabar reeds and intricate concentric wave patterns, no frightening expression."),
    ],
    "topic_02": [
        ("阿波罗晨曲", "Apollo, an elegant adult man in draped cream robes, playing a golden lyre on a sunlit marble amphitheater overlooking the Aegean; laurel branches, mosaic steps and small distant boats."),
        ("波塞冬潮汐", "Poseidon in turquoise drapery holding a slender trident at a white harbor jetty, a magnificent white horse emerging from curling seafoam; blue fishing boats, terracotta amphorae and distant islands."),
        ("月桂狩歌", "Artemis with a graceful bow resting at her side and a natural deer in a bright cypress grove above a Mediterranean bay; white wildflowers, laurel leaves, cream stone and sunlight."),
        ("赫尔墨斯风途", "Hermes in light classical robes and subtly winged sandals stepping over a marble bridge between white island buildings; olive baskets, fluttering fabric, pink bougainvillea and an open turquoise vista."),
        ("德墨忒尔丰年", "Demeter gathering golden wheat in a bright terraced Mediterranean field with olive trees, ripe figs, ceramic harvest bowls and a white farmhouse; rich harvest details and luminous blue sea far below."),
        ("贝湾的诞生", "Aphrodite, a graceful fully draped adult woman beside a large pearlescent shell in a sunlit cove; coral flowers, turquoise water, ivory stone, doves and elegant flowing fabrics."),
        ("雅典娜书院", "Athena studying an unlettered celestial diagram in an airy classical library with a small owl, blue ceramic vessels, olive branches and open arches revealing a radiant white coastal town."),
        ("伊卡洛斯蓝天", "An adult Icarus with beautifully constructed feather wings gliding high above a bright white Greek island town; sweeping cobalt sky, turquoise coves, sailing boats and warm sunlit rooftops, adventurous but elegant."),
        ("奥德修斯归航", "Odysseus at the prow of a richly detailed ancient Greek wooden sailing ship returning to an emerald and turquoise island harbor; cream sail, ropes, olive cliffs, white homes and calm morning light."),
        ("缪斯的剧场", "Three elegant adult muses performing lyre, flute and a small hand drum in a white marble outdoor theater; patterned cushions, flowering vines, terracotta vessels and luminous sea beyond."),
    ],
    "topic_03": [
        ("柠檬窗台", "A natural calico cat stretched on a sunlit deep window ledge beside a small lemon tree, a blue ceramic cup and linen curtains; leafy garden beyond and warm geometric light."),
        ("旧书店管理员", "A natural striped tabby balanced halfway up a wooden rolling bookshop ladder, looking toward a moth; layered old books without legible text, green velvet chair, brass lamp and tall sunlit windows."),
        ("雨夜唱片", "A natural black cat seated beside a softly glowing table lamp and a spinning vinyl record player; rain on a teal window, amber reflections, carefully arranged books and one red flower."),
        ("屋顶观星", "A ginger cat on a tiled rooftop terrace beside a brass telescope, terracotta pots and folded wool blanket; a wide deep blue starry sky and warm lit windows across an old town."),
        ("温室访客", "A natural white cat stepping through a lush glass greenhouse with orchids, ferns, patterned green leaves, watering cans and one butterfly; shafts of warm sunlight through the glass."),
        ("港口清晨", "A natural gray cat sitting on a coil of rope in a moored wooden fishing boat; blue harbor water, striped cloth, baskets, weathered but well-kept boat planks and warm dawn reflections."),
        ("画室印记", "A natural tortoiseshell cat examining a paintbrush beside an unfinished botanical canvas with no text; artist palettes, ceramic jars, patterned rug and late-afternoon studio light."),
        ("枫叶列车", "A natural long-haired brown cat on the green seat of a vintage train, watching brilliant autumn maples through the window; leather luggage, a scarf and blue teacup create a rich interior still life."),
        ("面包店守候", "A natural Siamese cat sitting beside a wicker basket of fresh bread in a warm bakery; copper pans, blue tiles, linen cloths, flour-dusted wooden table and soft morning window light."),
    ],
    "topic_04": [
        ("灯塔来信", "A natural golden retriever carrying a folded unlettered envelope along a coastal path toward a white lighthouse; blue sea, windswept grasses, old rope and red poppies."),
        ("雪地脚印", "A natural husky trotting along a snowy pine trail, its footprints curving behind it; pale blue shadows, warm sunlight, red scarf draped over a nearby wooden fence and distant cabin."),
        ("花市偶遇", "A natural brown dachshund peeking beneath a stall of terracotta pots and colorful grown flowers at a morning flower market; blue watering cans, wicker baskets and cobbled street."),
        ("雨后漫步", "A natural border collie walking along a rain-washed old town street; puddle reflections, folded green umbrella, window flower boxes and a bicycle beside cream walls."),
        ("湖边夏日", "A natural cream Labrador shaking water from its coat beside a quiet blue lake; a wooden canoe, reeds, patterned towel, pebbles and golden summer sun."),
        ("山径领航", "A natural Australian shepherd on a rugged hill trail above layered green mountains; wildflowers, walking boots and a canvas backpack on a stone, dramatic but welcoming daylight."),
        ("秋园拾叶", "A natural red Shiba Inu carrying one large maple leaf across an autumn garden bridge; a small pond, copper leaves, mossy rocks and pale gold light."),
        ("茶馆午睡", "A natural old beagle asleep beneath a wooden tea-room table; blue porcelain teapot, woven chairs, potted geraniums and sunlit checkerboard floor, calm detailed still life."),
        ("海风与风筝", "A natural black-and-white spaniel running beside a fallen bright orange kite on a beach; curling strings, dune grasses, shells, blue sea and a high clear sky."),
        ("牧场晨钟", "A natural collie standing at a wooden pasture gate with sheep in distant rolling fields; brass bell, wild daisies, red barn and early golden morning light."),
    ],
    "theme_flowers": [
        ("牡丹一庭", "Large layered ivory and blush peonies in an elegant Chinese ceramic vase beside scattered petals and patterned leaves; decorative botanical close-up with varied flower stages."),
        ("鸢尾溪岸", "Cobalt and violet iris flowers growing along a shallow stream; slender reeds, ivory water reflections, two dragonflies and graceful large green blades."),
        ("铃兰晨露", "Arching white lily-of-the-valley stems above curled fern fronds and moss; large translucent dew drops and a small ladybird, intimate woodland botanical view."),
        ("玫瑰拱门", "An elegant climbing rose arbor, cream and dusty coral blossoms against a sage garden gate; butterflies, buds, thorned vines and a stone path beyond."),
        ("荷塘清风", "Cream and pale blush lotus flowers at different stages above broad turquoise-green leaves; seed pods, rippling water and delicate damselflies."),
        ("向日葵小院", "Tall mature golden sunflowers around a blue ceramic basin in an ivory-walled courtyard; seed heads, striped shadows and a few small birds, decorative botanical setting."),
        ("山茶雪信", "Deep coral and ivory camellia blossoms on glossy dark sage leaves, small snow caps and a porcelain bowl; elegant winter still-life composition."),
        ("蓝绣球雨", "Rounded clusters of dusty blue hydrangea after gentle rain; broad veined leaves, reflected light, a small snail on a stone and cream garden background."),
        ("紫藤长廊", "Cascades of lilac wisteria hanging from a garden pergola; twisted stems, a quiet wooden bench, fresh green leaves and tiny hovering bees."),
        ("野花手札", "A sophisticated still life of meadow flowers gathered with botanical tools: cornflowers, poppies, daisies, seed pods, unlettered cream paper, twine and a glass bottle."),
    ],
    "theme_ocean": [
        ("鲸歌入蓝", "A great natural blue whale diving diagonally through layered deep blue and turquoise water; shafts of light, small silver fish, golden plankton and trailing coral branches."),
        ("章鱼藏书", "A natural copper-red octopus exploring an old intact ceramic amphora on the seabed; shells, coral, small fish and turquoise shafts of light, intricate flowing arms."),
        ("海龟远行", "A natural green sea turtle swimming over a colorful coral garden toward open turquoise water; fish schools, patterned corals and seagrass."),
        ("水母灯海", "An elegant group of translucent cream and pale coral jellyfish drifting vertically through deep turquoise water; fine flowing tentacles, tiny fish and soft scattered light."),
        ("鳐鱼沙洲", "Two natural manta rays gliding above patterned pale sand channels and sea grass; turquoise reef walls, red coral accents and bright sunlight from the surface."),
        ("海马花园", "A detailed natural ochre seahorse curled around branching coral among purple sea fans, turquoise plants, tiny shrimp and pearls of bubbles."),
        ("潮池拾光", "An intricate coastal tide pool viewed from above with starfish, anemones, shells, a hermit crab and seaweed; cream rocks, blue water reflections and coral accents."),
        ("沉船新生", "An old graceful wooden sailing-ship wreck now a living reef; turquoise water, red coral around a porthole, patterned fish and an elegant ray in the distance, no frightening atmosphere."),
        ("银鱼旋舞", "A swirling school of natural small silver-blue fish forming a large spiral around a sunlit turquoise opening; vivid coral clusters and delicate sea plants frame the bottom."),
        ("海豹冰湾", "A natural spotted seal swimming beneath an ivory floating ice arch in luminous blue water; small fish, bubbles, cold turquoise light and warm cream-gold decorative accents."),
    ],
    "theme_birds": [
        ("翠鸟落水", "A natural cobalt and rust kingfisher diving beside flowering reeds over a clear stream; one small silver fish, graceful splash, sage foliage and warm ivory ground."),
        ("鹤舞芦洲", "Two elegant natural red-crowned cranes, one wings open and one bending its long neck, among ochre reeds and pale blossoms; quiet water and fine botanical detail."),
        ("蜂鸟花宴", "Three natural iridescent hummingbirds hovering around coral trumpet flowers and sage vines; delicate wings, buds and layered leaves on warm ivory."),
        ("孔雀屏风", "A natural peacock turning beneath flowering magnolia branches; a splendid fan of teal, cobalt and restrained gold eye-pattern feathers, refined ornamental composition."),
        ("猫头鹰夜枝", "A natural barn owl perched in flowering dark branches beneath a pale moon; finely patterned cream feathers, moths, sage foliage and a restrained deep teal evening ground."),
        ("鹦鹉雨林", "Two natural scarlet and cobalt macaws on curved rainforest branches; broad sage leaves, ivory orchids, curling vines and warm decorative botanical spacing."),
        ("燕归屋檐", "Natural swallows flying and resting near the elegant eaves of a garden pavilion; trailing wisteria, buds, patterned feathers and warm ivory sky."),
        ("红雀冬园", "A natural deep coral cardinal on a frost-covered branch of red berries, with muted teal evergreens, ivory snow and intricate leaf shapes."),
        ("戴胜春信", "A natural hoopoe with raised ochre crest and black-and-cream patterned wings beside almond blossoms; a small beetle and layered sage garden foliage."),
        ("火烈鸟浅滩", "Three natural coral flamingos in distinct graceful poses on a pale turquoise shallow lagoon; slim reeds, delicate flowers and cream rippling reflections."),
    ],
    "theme_forest": [
        ("白桦鹿影", "A natural elegant spotted stag walking between sunlit white birches, viewed from a different angle than a portrait; moss, ferns, little white flowers and a winding woodland path."),
        ("红狐苔阶", "A natural red fox crossing old moss-covered stone steps in a deep green wood; ferns, mushrooms, fallen amber leaves and soft golden light."),
        ("溪流筑梦", "A natural beaver beside a small clear forest stream and a carefully layered wooden dam; water lilies, birch reflections, pebbles and dense olive ferns."),
        ("夜林听风", "A natural tawny owl on a mossy branch in a quiet moonlit woodland; ivory moonlight, layered muted teal trees, moths and delicate seed heads, calm rather than ominous."),
        ("蘑菇微光", "An intimate woodland-floor scene of many natural patterned mushrooms, tiny ferns, amber leaves, a beetle and sunlit dew under an arching root; detailed contemplative botanical art."),
        ("松间拾果", "A natural red squirrel carrying a pinecone across a branch above a forest floor of fallen cones, moss and small flowers; warm amber beams through dark olive pines."),
        ("秋日木屋", "A quiet small timber cabin beside a stream in a golden autumn woodland; stacked logs, mossy stone bridge, copper leaves, cream light and subtle smoke, no people."),
        ("獾的归途", "A natural badger walking along a fern-covered path near the roots of a grand oak; blue dusk, warm amber leaves, berries and tiny pale flowers."),
        ("林间旧桥", "An elegant old wooden footbridge over a reflective emerald woodland pool; hanging willow, mossy stones, delicate white wildflowers and sunlight opening through the canopy."),
        ("晨雾野马", "Two natural wild horses moving through a misty forest clearing among olive trees and amber grasses; warm ivory dawn, layered trunks and a small winding stream."),
    ],
}


def entries() -> list[dict]:
    result = []
    shanhai = json.loads((Path(__file__).parent / "shanhai_artwork_prompts.json").read_text(encoding="utf-8"))
    scenes_by_theme = dict(SCENES)
    scenes_by_theme["topic_01"] = [SCENES["topic_01"][0]] + [
        (asset["title"], asset["prompt"].split("Scene and subject: ", 1)[1])
        for asset in shanhai["assets"]
    ]
    for theme_id, scenes in scenes_by_theme.items():
        for index, (title, subject) in enumerate(scenes, 1):
            stem = {"topic_01": "shanhai", "topic_02": "greek", "topic_03": "cat", "topic_04": "dog"}.get(theme_id, theme_id.removeprefix("theme_"))
            level_id = f"{stem}_v2_{index:02d}"
            result.append({
                "id": level_id, "theme_id": theme_id, "title": title,
                "sort_order": index if theme_id == "topic_03" else index - 1,
                "subject": subject, "prompt": COMMON + STYLES[theme_id] + "Subject: " + subject,
                "source": f"sources/{level_id}.png", "status": "pending",
            })
    return result


if __name__ == "__main__":
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / "sources").mkdir(exist_ok=True)
    path = WORK / "manifest.json"
    if not path.exists():
        path.write_text(json.dumps({"route": "built-in imagegen", "preserved_level": "cat_02", "entries": entries()}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(entries())} new level artworks planned; manifest: {path}")
