#!/usr/bin/env python3
"""Route 666 "jacked" splash cards: one image-generation brief per roster car.

The robbery's last beat shows the driver and their ride left on the shoulder
(ui/robbery_screen.gd, art under assets/img/jacked/<car_id>.png). This tool is
the single source of truth for WHAT each card shows; it renders the brief an
image model works from. Contract, review checklist and the full regeneration
recipe: docs/art_briefs/jacked_cards.md.

    tools/jacked_brief.py --list            # car ids and one-line scenes
    tools/jacked_brief.py hornet            # the brief, to stdout
    tools/jacked_brief.py --write-all DIR   # brief_<id>.md for every car

CONTINUITY IS THE WHOLE JOB: the car and driver on a jacked card MUST be the
car and driver from the selection carousel. Every brief is run with that
car's bio portrait attached (assets/img/bios/<id>.png) as the identity
reference, and every scene below was written against the PORTRAIT, not the
roster's flavor text — where the two disagree, the portrait wins.
"""

import sys
from pathlib import Path

# id -> (one-liner, who and what must stay recognisable, the scene)
CARDS = {
    "bumper": (
        "Thumb out in his boxers; the land yacht sits on its frame",
        "Driver: a big, heavyset man with a purple bandana tied on his head and a "
        "cigar. Car: a long hot-pink 1970s land-yacht sedan with a chrome grille and "
        "quad headlights.",
        "The man stands at the roadside hitchhiking, thumb out, scowling. He has "
        "been stripped to a white tank top, heart-print boxer shorts, socks and "
        "sneakers; he still wears the purple bandana, and the cigar in his mouth is "
        "bent and gone out. His denim jacket and gold chain are gone. Behind him the "
        "pink land yacht sits flat on its frame on the asphalt: all four wheels "
        "gone, both hood guns gone (bare mounting brackets), the spiked bumper "
        "blades gone, trunk lid open and empty.",
    ),
    "coldfront": (
        "Arms crossed, plow gone; the door says THANKS",
        "Driver: a weathered woman with long blonde hair, a dark red knit beanie, a "
        "scarf and a red-and-black plaid work jacket. Car: a crimson 1980s pickup "
        "truck with a roof light bar.",
        "The woman stands beside the truck with her arms crossed, glaring straight "
        "at the viewer, utterly unimpressed. The big yellow snowplow blade is GONE: "
        "the bare plow mount on the truck's nose dangles loose chains and cut "
        "hydraulic hoses. The roof rocket pod is gone too. On the driver's door "
        "someone has spray-painted one word in dripping white paint: THANKS. Light "
        "snow falls.",
    ),
    "cricket": (
        "Sulking against the buggy on its belly, gum in her hair",
        "Driver: a young woman with a messy red-brown ponytail, a rust-red t-shirt "
        "and ripped blue jeans. Car: a bright green caged dune buggy / dirt-track "
        "midget car with a tube frame.",
        "The woman sits on the ground with her back against the buggy, knees up, "
        "arms crossed, sulking furiously. A popped pink bubble-gum bubble is stuck "
        "across her cheek and tangled in her hair. The green buggy sits on its "
        "belly in the dirt: all four wheels gone, bare hubs and shock absorbers "
        "hanging, the roof gun gone. One lonely lug nut lies in the dust.",
    ),
    "cyclone": (
        "Calmly measuring the skid marks; the racer is on bricks",
        "Driver: a woman with long blonde hair in a blue racing suit with red and "
        "white stripes. Car: a blue open-wheel single-seat racing car with a red "
        "and white stripe down the nose.",
        "The woman crouches on the asphalt, completely calm and professional, "
        "measuring a long black skid mark with a steel tape measure, a clipboard "
        "tucked under one arm, her striped helmet set on the ground beside her. "
        "Behind her the blue open-wheel racer sits propped on four stacks of "
        "bricks: all four wheels gone, front wing and rear wing gone, the guns "
        "gone. She is treating the robbery as data.",
    ),
    "ghost": (
        "Still smiling for a camera that isn't there; boot prints on the paint",
        "Driver: a tanned, square-jawed man with a big pompadour and aviator "
        "sunglasses. Car: a pristine cream-white 1960s long-nose sports coupe.",
        "The man checks his hair in a cracked hand mirror, forcing a bright "
        "showbiz smile that does not reach his eyes. One lens of his aviators is "
        "cracked, his purple blazer is gone and his black shirt has a torn sleeve, "
        "but the pompadour is still perfect. Behind him the white sports coupe is "
        "covered in muddy boot prints across the hood and roof, both doors are "
        "gone and the wire wheels have been swapped for bare steel rims.",
    ),
    "hammertoe": (
        "The monster truck on four tiny donut spares; they blame each other",
        "Drivers: TWO young men. One has shaggy dark brown hair and a plain black "
        "t-shirt and scowls. The other has long stringy blonde hair, a red tank "
        "top and a manic wide-eyed grin. Car: a black lifted monster pickup truck "
        "with purple flame paint.",
        "The black monster truck stands in the road on four comically tiny "
        "compact spare 'donut' wheels, its huge wheel arches yawning empty above "
        "them. In front of it the two men argue: the dark-haired one points an "
        "accusing finger at the blonde one, who is still grinning and throwing "
        "devil horns with one hand as if this were the best night of his life. "
        "Crushed drink cans litter the asphalt.",
    ),
    "hornet": (
        "Hood up, rotgut in hand, a hole where the part was",
        "Driver: a weathered older man with grey hair under a flat cap, a worn "
        "dark work jacket over an open-collared shirt, and a round yellow TAXI "
        "badge. Car: a battered yellow checker taxi cab with a black-and-white "
        "checker stripe and a roof TAXI sign.",
        "The man stands beside his cab holding a bottle of rotgut liquor in one "
        "hand and wiping his brow with the back of the other, exhausted. The "
        "cab's hood is raised. Wisps of smoke curl out of the engine bay, where "
        "wires and rubber hoses lie in a tangle around an obvious empty hole: a "
        "key component has been ripped out. The roof gun is gone. The taxi "
        "meter's light still glows through the windshield.",
    ),
    "hubcap": (
        "Strapped to a bare axle, steering with a lone hubcap",
        "Driver: a shirtless, scarred, muscular man in a studded mask with red "
        "goggle lenses, blue jeans and work boots. Vehicle: he normally stands on "
        "a small axle platform between two enormous truck tires taller than he is.",
        "Both enormous tires are GONE. The man sits on the cracked asphalt, still "
        "strapped by his harness to the bare axle frame and its little platform, "
        "with empty hub mounts where the giant wheels and guns used to be. He "
        "holds a single dented chrome hubcap out in front of him in both hands "
        "like a steering wheel, staring straight ahead, still driving.",
    ),
    "kandykane": (
        "Pouting on the curb; the ice cream truck is on cinderblocks",
        "Driver: a heavyset woman in a stitched white clown mask with a red nose, "
        "wild red hair, a black leather corset, red gloves and a yellow skirt with "
        "big blue and red polka dots and a red bow. Car: a battered white-and-pink "
        "armoured ice cream truck with a clown face painted on its side.",
        "The clown sits on the curb with her elbows on her knees and her chin in "
        "her gloved hands, pouting like a small child who has been sent to her "
        "room. A melting ice cream cone lies dropped on the pavement at her feet. "
        "Behind her the ice cream truck is up on cinderblocks: all four wheels "
        "gone, the roof gun and the loudspeaker gone, the serving hatch hanging "
        "open and empty.",
    ),
    "lovebug": (
        "Meditating in the road, one eye twitching; a daisy in the tailpipe",
        "Driver: a woman with very long dark brown hair with beads and feathers, a "
        "patterned headband, a fringed suede vest, peace-sign necklaces and patched "
        "blue jeans. Car: a sunshine-yellow classic Beetle painted with flowers "
        "and peace signs.",
        "The woman sits cross-legged in the middle of the road in a meditation "
        "pose, one hand raised in a peace sign, eyes closed, smiling serenely "
        "through gritted teeth with one eyelid visibly twitching. Behind her the "
        "yellow Beetle is stripped: wheels gone, sitting on its floor pan, the "
        "roof rack and guns gone, the front bumper gone. A single daisy has been "
        "left sticking out of the tailpipe.",
    ),
    "mrghastly": (
        "Death hitchhikes with a cardboard sign and the handlebars",
        "Driver: a skeleton with a bare skull face, wearing a brass spiked "
        "helmet, a black leather biker jacket, a chain belt and heavy boots. "
        "Vehicle: an old-school chopper motorcycle with a dark red tank.",
        "The skeleton biker stands alone at the side of an empty desert highway, "
        "hitchhiking: one bony thumb out. Under his other arm he carries the "
        "chopper's handlebars, which are all that is left of the motorcycle. "
        "Propped against his boot is a torn cardboard sign with one hand-lettered "
        "word: ANYWHERE. A tumbleweed rolls past. No motorcycle anywhere in the "
        "picture.",
    ),
    "smoky": (
        "In his drawers in the road, shaking a fist at the horizon",
        "Driver: a stern, square-faced police officer with short grey hair. Car: "
        "a black-and-white police SUV with a push bar and a red-and-blue roof "
        "light bar.",
        "A long straight desert road stretches away to the horizon, seen from "
        "road level behind the man. On the shoulder sits the busted-up police "
        "SUV: doors open, light bar hanging off, wheels gone. In the MIDDLE of "
        "the road stands the officer, seen from behind and slightly to the side, "
        "wearing only a white t-shirt, white boxer shorts, black socks and his "
        "duty boots, angrily shaking one raised fist at a distant pack of "
        "vehicles speeding away toward the horizon in a cloud of dust.",
    ),
    "splatkat": (
        "One undelivered package, one wheel clamp, one parking ticket",
        "Driver: a wiry man with long messy black hair and a full beard, a black "
        "leather vest over a red shirt, and a wallet chain. Car: a rust-red "
        "armour-plated muscle car with riveted panels.",
        "The man stands beside his car hugging a single battered cardboard "
        "delivery parcel to his chest, looking down at it, the only thing they "
        "left him. The armoured muscle car has three wheels gone and sits on its "
        "brake discs; the one remaining wheel wears a big yellow wheel clamp. "
        "The roof harpoon is gone, leaving an empty mount and a frayed cable, and "
        "a parking ticket is tucked under the windshield wiper.",
    ),
    "warpig": (
        "Peeling potatoes in his skivvies; the Hummer is stripped",
        "Driver: a huge, muscular, stern soldier with a green beret. Car: an "
        "olive-drab military Humvee-style 4x4.",
        "The huge soldier sits on an empty wooden ammunition crate peeling "
        "potatoes into a steel bucket with a tiny paring knife, glowering. He "
        "wears only his green beret, an olive undershirt, olive boxer shorts, dog "
        "tags and combat boots. Behind him the military 4x4 is stripped: the big "
        "roof rocket launcher is gone (bare mounting rails), armour panels "
        "missing to show the frame, up on blocks with the wheels gone.",
    ),
}

BRIEF = """\
Task: generate ONE raster image with the built-in image_gen tool, then copy \
the final PNG to ./{car}.png in the current working directory. Do not create \
or modify any other file besides that PNG. Finish by reporting the saved path.

Use: a full-screen splash card for an indie vehicular-combat video game. The \
player has just been run down and robbed by a gang of road bandits. The card \
shows their driver and vehicle left on the side of the road afterwards. The \
tone is CHEEKY and embarrassing, a comic beat at the driver's expense: \
humiliated, not hurt. Nobody is injured, bleeding or dead.

Attached image: the character's official portrait. Role = IDENTITY AND STYLE \
REFERENCE. The driver and the vehicle in your image must be unmistakably the \
SAME driver and the SAME vehicle: same face, hair, build and signature \
clothing (except where the scene says something was taken), same vehicle \
make, shape, colour and paintwork. Match the portrait's illustration style \
exactly. Do NOT copy its pose or composition; stage the new scene below.

Who and what must stay recognisable: {identity}

Scene: {scene}

Canvas: landscape 3:2 (1536x1024). Full-bleed illustration, no border, no \
frame. COMPOSITION RULE: keep the bottom 15% of the image free of faces, \
hands and anything important; a caption strip covers it in the game. Driver \
and vehicle both clearly readable at a glance.

Style: gritty hand-inked comic-book illustration, heavy black cross-hatching \
and ink spatter, distressed print texture, muted wasteland palette of amber, \
rust and black with the vehicle's own signature colour as the accent. Dusty \
post-apocalyptic roadside, low sun, long shadows.

Text: {text_rule}

Avoid: gore, blood, wounds, corpses, nudity, real-world brand names, logos or \
badges, real band names, watermark, signature, caption, speech bubbles, UI, \
extra people beyond those described, a second copy of the vehicle, photoreal \
rendering, 3D render look, clean vector look.
"""

# Cards whose scene contains lettering: the exact words, and nothing else.
LETTERING = {
    "coldfront": ["THANKS"],
    "hornet": ["TAXI"],
    "mrghastly": ["ANYWHERE"],
    "kandykane": ["I SCREAM"],
}


def brief_for(car: str) -> str:
    _, identity, scene = CARDS[car]
    words = LETTERING.get(car)
    if words:
        text_rule = (
            "the only lettering allowed anywhere in the image is, verbatim: "
            + ", ".join('"%s"' % w for w in words)
            + ". No other words, letters or numbers."
        )
    else:
        text_rule = "no words, letters or numbers anywhere in the image."
    return BRIEF.format(car=car, identity=identity, scene=scene, text_rule=text_rule)


def main(argv: list) -> int:
    if len(argv) == 2 and argv[1] == "--list":
        for car in sorted(CARDS):
            print("%-10s %s" % (car, CARDS[car][0]))
        return 0
    if len(argv) == 3 and argv[1] == "--write-all":
        out = Path(argv[2])
        out.mkdir(parents=True, exist_ok=True)
        for car in sorted(CARDS):
            (out / ("brief_%s.md" % car)).write_text(brief_for(car))
        print("wrote %d briefs to %s" % (len(CARDS), out))
        return 0
    if len(argv) == 2 and argv[1] in CARDS:
        sys.stdout.write(brief_for(argv[1]))
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
