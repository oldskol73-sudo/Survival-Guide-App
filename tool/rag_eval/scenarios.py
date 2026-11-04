"""Realistic things a person would type into the three screens. Each row:
   (screen, area, text, have, expect)
 screen: solver = Step By Step Problem Solver (area chip), ask = Ask a Question (whole library), plan = Priority Plan
 area:   category id of the Problem Solver chip (water food medical energy mechanical transport carpentry comms longterm) or None
 have:   what the person says they have (optional)
 expect: words a correct source page would contain; a scenario passes if the top passages contain any of them.
Sources are NOT limited to the bundled PDFs: rows the library cannot answer show up as gaps to fill from the web.
"""
S = []


def add(screen, area, text, have, expect):
    S.append((screen, area, text, have, expect))


# ------------------------------------------------------------ WATER
for t, h, e in [
    ("My only water source is a muddy stream", "pot, lighter, cotton cloth, a little bleach", ["boil", "filter", "sediment", "disinfect"]),
    ("How long do I boil water to make it safe", "", ["boil", "minute"]),
    ("How much bleach do I add to a gallon of water", "unscented household bleach", ["bleach", "drops", "hypochlorite", "chlorine"]),
    ("Water from a pond smells bad and has green algae", "", ["algae", "filter", "boil", "turbid"]),
    ("Make a water filter from sand and charcoal", "sand, gravel, charcoal, bottle", ["charcoal", "sand", "gravel", "filter"]),
    ("Solar still to get drinking water in the desert", "plastic sheet, cup, digging tool", ["still", "condens", "plastic"]),
    ("Collect rain water safely", "tarp, buckets", ["rain", "collect", "catchment", "tarp"]),
    ("Is it safe to drink melted snow", "", ["snow", "melt", "boil"]),
    ("What are signs of dehydration", "", ["dehydrat", "thirst", "urine"]),
    ("How much water does a person need per day", "", ["gallon", "quart", "liter", "per day"]),
    ("Find water in dry country", "", ["dry", "water", "dew", "vegetation", "seep", "dig"]),
    ("Purify water with iodine tablets", "iodine tablets", ["iodine", "tablet"]),
    ("Water tastes like chemicals after treating it", "", ["taste", "aerat", "chlor"]),
    ("Store drinking water for emergencies", "", ["store", "container", "rotate", "sanitiz"]),
    ("Well water after a flood", "", ["flood", "well", "disinfect", "shock"]),
    ("Pipes frozen and no water", "", ["frozen", "pipe", "thaw"]),
    ("Build a latrine away from our water", "shovel", ["latrine", "sanitation", "feet", "yards", "meters"]),
    ("Wash hands with no running water", "", ["wash", "hand", "soap"]),
    ("Giardia from stream water what now", "", ["giardia", "diarrhea", "parasite"]),
    ("Can I drink seawater", "", ["sea", "salt", "desalin", "brackish"]),
    ("Distill water with a pot and lid", "pot, lid, tubing", ["distill", "steam", "condens"]),
    ("Cloudy water how to clear it", "alum, cloth", ["cloud", "turbid", "settle", "coagulat", "alum"]),
    ("Septic system backed up after storm", "", ["septic", "sewage", "waste", "sanitation"]),
    ("Dispose of human waste in camp", "", ["waste", "latrine", "cat hole", "bury"]),
    ("How to treat water for a baby", "", ["boil", "infant", "baby", "water"]),
]:
    add("solver", "water", t, h, e)

# ------------------------------------------------------------ FOOD
for t, h, e in [
    ("How do I can green beans safely", "pressure canner, jars", ["pressure", "canner", "pound", "minute"]),
    ("Signs that canned food has spoiled botulism", "", ["botulism", "bulg", "spoil", "leak"]),
    ("Store flour and rice for years", "buckets, mylar bags", ["store", "oxygen", "container", "shelf"]),
    ("Preserve meat without a freezer", "salt, smoke", ["cure", "salt", "smok", "jerky", "dry"]),
    ("How to dry fruit and vegetables", "oven", ["dry", "dehydrat", "temperature"]),
    ("Plant a survival garden first season", "seeds, small yard", ["garden", "plant", "seed", "soil"]),
    ("What wild plants are safe to eat", "", ["edible", "plant", "universal edibility", "test"]),
    ("Universal edibility test steps", "", ["edibility", "test", "taste", "hours"]),
    ("Catch fish with no fishing rod", "string, hook", ["fish", "trap", "hook", "net"]),
    ("Set a snare for small game", "wire", ["snare", "trap", "game", "wire"]),
    ("How to clean and gut a rabbit", "knife", ["skin", "clean", "dress", "game", "rabbit"]),
    ("Cook without a stove or pots", "", ["cook", "fire", "roast", "boil"]),
    ("Food in power outage fridge freezer how long safe", "", ["refrigerat", "freezer", "hours", "spoil", "temperature"]),
    ("Make bread without yeast", "flour, salt, water", ["bread", "dough", "flour", "yeast"]),
    ("Pickle vegetables in jars", "vinegar, jars", ["pickl", "vinegar", "brine"]),
    ("Keep bugs and mice out of stored grain", "", ["pest", "insect", "rodent", "grain", "store"]),
    ("How long does honey and salt and sugar last", "", ["honey", "salt", "sugar", "store"]),
    ("How to render fat and make tallow or lard", "", ["fat", "render", "lard", "tallow"]),
    ("Sprout seeds for fresh greens in winter", "jar, seeds", ["sprout", "seed", "germinat"]),
    ("Raise chickens for eggs", "", ["chicken", "poultry", "egg", "coop"]),
    ("How to butcher a deer in the field", "knife", ["deer", "game", "field dress", "butcher", "carcass"]),
    ("Cooking food safely to avoid food poisoning", "", ["temperature", "food poison", "bacteria", "cook"]),
    ("Feed a family of four for a month on stored food", "", ["ration", "calorie", "store", "meal"]),
    ("Insects as a food source", "", ["insect", "grasshopper", "protein", "cricket"]),
    ("Fermenting food without special equipment", "", ["ferment", "brine", "sauerkraut"]),
]:
    add("solver", "food", t, h, e)

# ------------------------------------------------------------ MEDICAL
for t, h, e in [
    ("Heavy bleeding from a deep cut on the arm", "clean shirt, belt", ["bleed", "pressure", "tourniquet", "dressing"]),
    ("How do I apply a tourniquet", "belt, stick", ["tourniquet", "tighten", "limb"]),
    ("Someone is not breathing and has no pulse", "", ["cpr", "compress", "breath", "pulse"]),
    ("Choking adult cannot speak", "", ["chok", "abdominal", "heimlich", "thrust"]),
    ("Broken leg and no hospital nearby", "sticks, cloth", ["fracture", "splint", "immobil", "break"]),
    ("Severe burn on the hand", "", ["burn", "cool", "dressing", "blister"]),
    ("Child has a high fever", "", ["fever", "temperature", "child", "fluid"]),
    ("Snake bite on the ankle", "", ["snake", "bite", "venom", "immobil"]),
    ("Signs of hypothermia and how to treat", "blankets", ["hypothermia", "shiver", "warm", "rewarm"]),
    ("Heat stroke vs heat exhaustion", "", ["heat stroke", "heat exhaustion", "cool", "temperature"]),
    ("Deep puncture wound in the foot from a nail", "", ["puncture", "tetanus", "wound", "clean"]),
    ("Infection spreading red streaks from a wound", "", ["infect", "wound", "antibiotic", "pus"]),
    ("How to clean and close a wound without stitches", "tape, alcohol", ["wound", "clean", "irrigat", "closure", "suture"]),
    ("Diarrhea for two days dehydration", "salt, sugar, water", ["diarrhea", "rehydrat", "oral", "salt", "sugar"]),
    ("Make oral rehydration solution", "salt, sugar, clean water", ["rehydrat", "salt", "sugar", "liter"]),
    ("Allergic reaction swelling face", "", ["allerg", "anaphyla", "epinephrine", "swell"]),
    ("Dislocated shoulder", "", ["dislocat", "shoulder", "reduce", "sling"]),
    ("Head injury after a fall confused", "", ["head", "concussion", "unconscious", "skull"]),
    ("Frostbite on fingers and toes", "", ["frostbite", "rewarm", "frozen", "tissue"]),
    ("Tooth abscess and severe tooth pain", "", ["tooth", "dental", "abscess"]),
    ("Childbirth with no doctor", "", ["childbirth", "deliver", "labor", "newborn", "birth"]),
    ("Diabetic person with no insulin", "", ["diabet", "insulin", "blood sugar"]),
    ("Chest pain and left arm numb", "", ["heart", "chest pain", "cardiac", "myocardial"]),
    ("Bee sting swelling", "", ["sting", "bee", "venom", "allerg"]),
    ("Tick bite how to remove", "tweezers", ["tick", "remove", "lyme"]),
    ("Sprained ankle can't walk", "", ["sprain", "ankle", "ligament", "wrap"]),
    ("Eye chemical splash", "", ["eye", "chemical", "flush", "irrigat"]),
    ("Carbon monoxide headache dizzy in the house", "", ["carbon monoxide", "headache", "ventilat"]),
    ("Drowning victim pulled from water", "", ["drown", "rescue breathing", "resuscitat"]),
    ("Treat shock after injury", "", ["shock", "pale", "elevate", "lie"]),
    ("Make a splint for a broken arm", "", ["splint", "arm", "fracture", "padd"]),
    ("Antibiotic alternatives in a long emergency", "", ["antibiotic", "garlic", "honey", "natural"]),
    ("Pain relief without medicine", "", ["pain", "analgesic", "relief"]),
    ("Treat poison ivy rash", "", ["poison ivy", "rash", "itch"]),
    ("Someone swallowed bleach or chemicals", "", ["poison", "swallow", "ingest", "poison control"]),
    ("Asthma attack no inhaler", "", ["asthma", "breath", "wheez"]),
    ("Seizure what to do", "", ["seizure", "convuls", "epilep"]),
    ("Stroke signs face drooping", "", ["stroke", "droop", "speech", "paraly"]),
    ("Lice or scabies outbreak in a shelter", "", ["lice", "scabies", "parasite", "hygiene"]),
    ("Infant not feeding and weak", "", ["infant", "baby", "feeding", "breast"]),
    ("Elderly parent dehydrated and confused", "", ["elderly", "dehydrat", "confus", "fluid"]),
    ("Pandemic isolation mask and hygiene", "", ["quarantine", "isolat", "mask", "infect", "disease"]),
    ("Radiation exposure what to do", "", ["radiation", "fallout", "decontamin", "shelter"]),
]:
    add("solver", "medical", t, h, e)

# ------------------------------------------------------------ SHELTER / BUILDING
for t, h, e in [
    ("Build an emergency shelter in the woods tonight", "tarp, rope, knife", ["shelter", "lean-to", "debris", "tarp"]),
    ("Trees down on my roof, patch a hole", "tarp, nails, boards", ["roof", "patch", "tarp", "repair"]),
    ("Frame a small cabin wall", "lumber, hammer, nails", ["frame", "stud", "wall", "lumber"]),
    ("How do I build a door and hinge", "boards, screws", ["door", "hinge", "frame"]),
    ("Insulate a room to keep heat in", "blankets, cardboard", ["insulat", "heat", "r-value", "draft"]),
    ("Build a log cabin joint notch", "axe, saw", ["notch", "log", "joint", "cabin"]),
    ("Board up windows before a hurricane", "plywood, screws", ["window", "plywood", "board", "storm"]),
    ("Build a storage shed", "pallets, screws", ["shed", "frame", "floor", "build"]),
    ("Sharpen an axe and a saw", "file, stone", ["sharpen", "axe", "saw", "file"]),
    ("Make a simple table and bench", "boards", ["table", "bench", "joint", "build"]),
    ("Waterproof a wood roof", "tar, plastic", ["roof", "water", "shingle", "waterproof"]),
    ("Build a chimney or stove pipe through a wall", "", ["chimney", "flue", "stove pipe", "clearance"]),
    ("Dig a root cellar", "shovel", ["cellar", "dig", "earth", "storage"]),
    ("Estimate lumber needed to build a 12 by 16 shed", "", ["lumber", "board feet", "estimate", "stud"]),
    ("Use hand tools: plane, chisel, drill", "", ["plane", "chisel", "brace", "hand tool"]),
]:
    add("solver", "carpentry", t, h, e)

# ------------------------------------------------------------ ASK: general survival (whole library)
for t, h, e in [
    ("Start a fire in the rain", "lighter, knife", ["fire", "tinder", "kindling", "wet"]),
    ("No matches how to make fire", "knife, string", ["friction", "bow", "flint", "fire"]),
    ("Keep warm at night without a heater", "blankets, newspaper", ["warm", "insulat", "clothing", "cold"]),
    ("Heat a room safely with a wood stove", "wood stove", ["stove", "wood", "chimney", "heat"]),
    ("Stay cool in a heat wave with no power", "", ["heat", "cool", "shade", "hydrat"]),
    ("Lost in the forest what do I do first", "", ["lost", "stop", "signal", "stay"]),
    ("Find north without a compass", "", ["north", "star", "sun", "shadow", "compass"]),
    ("Cross a fast river safely", "rope", ["river", "stream", "cross", "current"]),
    ("Survive a blizzard in a car", "", ["blizzard", "snow", "car", "vehicle"]),
    ("Build a snow shelter", "shovel", ["snow", "shelter", "cave", "igloo", "trench"]),
    ("Tornado warning what to do at home", "", ["tornado", "shelter", "basement", "storm"]),
    ("Earthquake just happened now what", "", ["earthquake", "aftershock", "drop", "collapse"]),
    ("Flood waters rising", "", ["flood", "evacuat", "water", "higher ground"]),
    ("Wildfire approaching evacuation", "", ["wildfire", "evacuat", "fire", "smoke"]),
    ("Hurricane preparation checklist", "", ["hurricane", "storm", "prepare", "evacuat"]),
    ("Lightning storm while hiking", "", ["lightning", "storm", "shelter"]),
    ("Power grid down for weeks", "", ["power", "grid", "outage", "blackout"]),
    ("Defend my home from looters", "", ["defen", "security", "perimeter", "protect"]),
    ("Stay hidden and quiet in an unsafe area", "", ["conceal", "hide", "camouflage", "evasion", "security"]),
    ("Bug out bag what to pack", "", ["pack", "bag", "kit", "gear", "bug out"]),
    ("Emergency kit for a car", "", ["kit", "vehicle", "emergency", "supplies"]),
    ("Nuclear fallout shelter basics", "", ["fallout", "shelter", "radiation", "nuclear"]),
    ("Chemical spill or gas leak evacuate", "", ["chemical", "gas", "evacuat", "hazard"]),
    ("Pandemic stockpile what do I need", "", ["pandemic", "stockpile", "supplies", "disease"]),
    ("Economic collapse barter goods", "", ["barter", "trade", "currency", "economic"]),
    ("How to sharpen a knife in the field", "stone", ["sharpen", "knife", "stone", "edge"]),
    ("Tie knots for shelter and rescue", "rope", ["knot", "hitch", "rope", "lash"]),
    ("Make rope from natural fibers", "", ["cordage", "rope", "fiber", "twist"]),
    ("Hunting small game traps trapping laws and methods", "", ["trap", "snare", "game"]),
    ("Teach kids what to do if lost", "", ["child", "lost", "whistle", "hug a tree", "stay"]),
    ("Pets in an emergency", "", ["pet", "animal", "dog"]),
    ("Mental stress and panic in a crisis", "", ["stress", "fear", "panic", "morale", "psycholog"]),
    ("Keep a group organized and make decisions", "", ["leader", "group", "decision", "organiz"]),
    ("Long term food and seed saving plan for a year", "", ["seed", "store", "year", "plan"]),
    ("Soap making from ash and fat", "", ["soap", "lye", "fat", "ash"]),
    ("Make charcoal", "", ["charcoal", "kiln", "wood"]),
    ("Candle and lamp from fat and oil", "", ["candle", "lamp", "oil", "wick"]),
    ("Sewing and repairing clothes by hand", "needle, thread", ["sew", "stitch", "needle", "thread", "repair"]),
    ("Make clothing from animal hides", "", ["tan", "hide", "leather", "skin"]),
]:
    add("ask", None, t, h, e)

# ------------------------------------------------------------ ENERGY
for t, h, e in [
    ("Run a fridge on a small solar panel", "100 watt panel, battery", ["solar", "panel", "watt", "battery"]),
    ("Size a battery bank for a cabin", "", ["battery", "amp", "hour", "bank", "capacity"]),
    ("Charge phones with no electricity", "hand crank, car", ["charge", "battery", "crank", "solar", "usb"]),
    ("Use a generator safely indoors", "generator", ["generator", "carbon monoxide", "ventilat", "outdoor"]),
    ("Wire a solar panel to a charge controller", "", ["charge controller", "wire", "panel", "series", "parallel"]),
    ("Make a small wind turbine", "", ["wind", "turbine", "generator", "blade"]),
    ("Micro hydro from a creek", "", ["hydro", "water", "turbine", "stream"]),
    ("Inverter picks and what it can run", "", ["inverter", "watt", "ac", "dc"]),
    ("Connect a generator to the house panel safely", "", ["transfer switch", "backfeed", "generator", "panel"]),
    ("Test a battery with a multimeter", "multimeter", ["multimeter", "voltage", "battery", "test"]),
    ("Convert watts to amps", "", ["watt", "amp", "volt", "ohm"]),
    ("Store fuel safely for years", "", ["fuel", "store", "stabil", "gasoline"]),
    ("Biogas or wood gas for fuel", "", ["biogas", "gasif", "methane", "wood gas"]),
    ("Solar oven cooking", "", ["solar", "oven", "cook", "reflect"]),
    ("Lead acid vs lithium batteries", "", ["lead", "acid", "lithium", "battery"]),
]:
    add("solver", "energy", t, h, e)

# ------------------------------------------------------------ MECHANICAL / ELECTRICAL
for t, h, e in [
    ("Repair a leaking pipe", "tape, clamp", ["pipe", "leak", "repair", "clamp"]),
    ("Why did the breaker trip", "", ["breaker", "circuit", "overload", "short"]),
    ("Fix a small engine that will not start", "", ["engine", "spark", "carburetor", "start", "fuel"]),
    ("Replace a faucet washer", "wrench", ["faucet", "washer", "valve", "plumb"]),
    ("Basic electronics resistor capacitor", "", ["resistor", "capacitor", "circuit", "current"]),
    ("Join two pieces of metal without a welder", "", ["weld", "solder", "braz", "join"]),
    ("Use a lever or pulley to move something heavy", "", ["lever", "pulley", "mechanical advantage", "block"]),
    ("Hand pump a well", "", ["pump", "well", "pipe"]),
    ("Lubricate and maintain tools", "", ["lubric", "oil", "grease", "maintenance"]),
    ("Fix a bike or wheelbarrow tire", "", ["tire", "tube", "patch", "wheel"]),
    ("Soldering a wire connection", "soldering iron", ["solder", "flux", "joint", "wire"]),
    ("Read a schematic", "", ["schematic", "symbol", "diagram", "circuit"]),
    ("Measure with a micrometer or caliper", "", ["micrometer", "caliper", "measure", "reading"]),
    ("Make a simple generator from a motor", "", ["motor", "generator", "magnet", "coil"]),
    ("Someone is electrocuted what do I do", "", ["electric", "shock", "current", "rescue"]),
]:
    add("solver", "mechanical", t, h, e)

# ------------------------------------------------------------ VEHICLE
for t, h, e in [
    ("Car will not start clicking sound", "jumper cables", ["battery", "starter", "click", "jump"]),
    ("Jump start a dead battery", "jumper cables", ["jump", "cable", "battery", "terminal"]),
    ("Engine overheating on the road", "", ["overheat", "coolant", "radiator", "temperature"]),
    ("Change a flat tire", "jack, spare", ["tire", "jack", "lug", "wheel"]),
    ("Brakes feel soft or spongy", "", ["brake", "fluid", "bleed", "pedal"]),
    ("Stuck in mud or snow", "shovel, boards", ["stuck", "traction", "mud", "snow", "rock"]),
    ("Run a vehicle on old gasoline", "", ["gasoline", "fuel", "old", "stale", "water"]),
    ("Siphon fuel safely", "hose", ["siphon", "fuel", "hose", "tank"]),
    ("Fix a broken fan belt", "", ["belt", "fan", "alternator", "tension"]),
    ("Cold weather diesel won't start", "", ["diesel", "glow plug", "cold", "start"]),
    ("Engine knocking noise", "", ["knock", "engine", "bearing", "detonation"]),
    ("Change oil without a shop", "", ["oil", "drain", "filter", "change"]),
    ("Transmission slipping or won't shift", "", ["transmission", "clutch", "shift", "fluid"]),
    ("Fuel pump not working", "", ["fuel pump", "fuel", "pressure", "fuel line"]),
    ("Radiator leak temporary fix", "", ["radiator", "leak", "coolant", "hose"]),
    ("Clean a carburetor", "", ["carburetor", "jet", "clean", "float"]),
    ("Use a car alternator to power tools", "", ["alternator", "inverter", "battery", "power"]),
    ("Drive on a flooded road", "", ["flood", "water", "vehicle", "engine"]),
]:
    add("solver", "transport", t, h, e)

# ------------------------------------------------------------ COMMUNICATIONS / NAVIGATION
for t, h, e in [
    ("Signal for rescue from a mountain", "mirror, whistle", ["signal", "mirror", "whistle", "rescue"]),
    ("Set up a ham radio for emergency contact", "handheld radio", ["radio", "frequency", "antenna", "amateur"]),
    ("Build a simple antenna", "wire", ["antenna", "wire", "dipole", "length"]),
    ("What are emergency radio frequencies", "", ["frequency", "mhz", "channel", "emergency"]),
    ("Send morse code with a flashlight", "flashlight", ["morse", "code", "sos", "dot"]),
    ("Use a map and compass to find my position", "map, compass", ["map", "compass", "azimuth", "bearing"]),
    ("Read a topographic map", "map", ["contour", "topograph", "map", "elevation"]),
    ("CB or FRS radio range tips", "", ["range", "radio", "antenna", "channel"]),
    ("Radio procedure words and phonetic alphabet", "", ["phonetic", "procedure", "radio", "alpha"]),
    ("Signal fire and ground to air signals", "", ["signal", "ground", "air", "panel", "smoke"]),
    ("Build a crystal radio receiver", "", ["receiver", "crystal", "radio", "detector"]),
    ("Charge a radio battery with solar", "", ["battery", "radio", "solar", "charge"]),
    ("Send an SOS with a whistle", "whistle", ["whistle", "three", "distress", "signal"]),
    ("Pace count to measure distance walking", "", ["pace", "distance", "count", "measure"]),
    ("Navigate by the stars at night", "", ["star", "north", "polaris", "navigate"]),
    ("Antenna grounding and lightning protection", "", ["ground", "lightning", "antenna", "protect"]),
]:
    add("solver", "comms", t, h, e)

# ------------------------------------------------------------ LONG TERM
for t, h, e in [
    ("Rebuild a community after a long collapse", "", ["community", "rebuild", "society", "organization"]),
    ("Medicine you can grow in a garden", "", ["herb", "medicin", "plant", "remedy"]),
    ("Make and use lye and ash", "", ["lye", "ash", "alkali", "soap"]),
    ("Blacksmithing basics forge and anvil", "", ["forge", "anvil", "smith", "iron", "steel"]),
    ("Making glass or pottery", "", ["glass", "pottery", "kiln", "clay"]),
    ("Teach children reading and math without school", "", ["teach", "education", "reading", "math"]),
    ("Spin thread and make cloth", "", ["spin", "weave", "cloth", "fiber"]),
    ("Brew vinegar or alcohol for disinfectant", "", ["alcohol", "distill", "vinegar", "ferment"]),
    ("Beekeeping basics", "", ["bee", "hive", "honey", "colony"]),
    ("Save seeds from heirloom vegetables", "", ["seed", "save", "heirloom", "pollinat"]),
    ("Make paper and ink", "", ["paper", "ink", "pulp", "write"]),
    ("Water mill or windmill", "", ["mill", "water", "wheel", "wind"]),
    ("Sanitation and disease prevention in a camp", "", ["sanitation", "disease", "camp", "latrine"]),
    ("Raise goats or rabbits for meat and milk", "", ["goat", "rabbit", "milk", "livestock"]),
    ("Make cheese and butter", "", ["cheese", "butter", "milk", "curd"]),
]:
    add("solver", "longterm", t, h, e)

# ------------------------------------------------------------ ASK: factual questions
for t, e in [
    ("What is the boiling time at high altitude", ["altitude", "boil", "minute"]),
    ("How many calories does a person need per day", ["calorie", "day"]),
    ("How long can a person live without food", ["without food", "days", "starv"]),
    ("What is the rule of threes in survival", ["three", "rule", "hours", "days", "weeks"]),
    ("What is the first thing to do in a survival situation", ["survival", "stop", "think", "observe", "plan"]),
    ("How do I know if a mushroom is poisonous", ["mushroom", "poison", "fung"]),
    ("What temperature is safe for storing food", ["temperature", "40", "degrees", "refrigerat"]),
    ("What are the symptoms of hypothermia", ["hypothermia", "symptom", "shiver"]),
    ("How far can I walk in a day", ["miles", "walk", "march", "day"]),
    ("What are the parts of a first aid kit", ["first aid", "kit", "bandage"]),
    ("What is the shelf life of canned food", ["canned", "shelf", "year"]),
    ("How do I treat a fever naturally", ["fever", "temperature"]),
    ("How do I purify water with bleach", ["bleach", "water", "drops"]),
    ("What do the colors of a wire mean", ["wire", "color", "black", "white", "ground"]),
    ("How to tie a bowline knot", ["bowline", "knot"]),
    ("What is a fire triangle", ["fire", "oxygen", "heat", "fuel"]),
    ("How much food per person for 72 hours", ["72", "hours", "food", "ration"]),
    ("What is the best way to stay warm in a sleeping bag", ["sleeping bag", "warm", "insulat"]),
    ("Is it safe to eat snow", ["snow", "eat", "melt"]),
    ("How many pounds of pressure for canning", ["pound", "pressure", "canning"]),
    ("What's the difference between a hurricane watch and warning", ["watch", "warning", "hurricane"]),
    ("How to treat a jellyfish sting", ["jellyfish", "sting", "vinegar"]),
    ("What is the Heimlich maneuver", ["heimlich", "abdominal thrust", "chok"]),
    ("What does SOS stand for and how do I signal it", ["sos", "signal", "distress"]),
    ("How do I read a compass bearing", ["compass", "bearing", "azimuth"]),
    ("Which direction does moss grow", ["moss", "north"]),
    ("What fuel can I burn in a camp stove", ["stove", "fuel", "alcohol", "kerosene"]),
    ("How do I keep my feet dry and avoid trench foot", ["trench foot", "feet", "dry", "sock"]),
    ("What is the correct CPR rate", ["cpr", "compress", "per minute", "rate"]),
    ("What is Lyme disease", ["lyme", "tick"]),
]:
    add("ask", None, t, "", e)

# ------------------------------------------------------------ PLAN (situation, people, days, supplies)
for t, p, d, h, e in [
    ("Power out in winter, house is cold, no tap water", 4, 5, "wood stove, firewood, canned food", ["cold", "heat", "water", "warm", "stove"]),
    ("Hurricane coming in 48 hours", 5, 7, "gas tank half full, some canned goods", ["hurricane", "storm", "evacuat", "prepare", "water"]),
    ("Lost on a hike with an injured friend", 2, 2, "water bottle, jacket, phone with no signal", ["lost", "signal", "shelter", "injur"]),
    ("Earthquake damaged my house and gas smells", 3, 3, "flashlight, first aid kit", ["earthquake", "gas", "evacuat", "shelter"]),
    ("Flooding in the basement and power going out", 2, 4, "sump pump, generator", ["flood", "electric", "pump", "water"]),
    ("Car broke down in desert heat with no cell service", 2, 1, "2 liters of water", ["heat", "water", "shade", "signal", "vehicle"]),
    ("Stranded in a snowstorm in my car", 3, 2, "blanket, snacks, full tank", ["snow", "car", "warm", "exhaust", "carbon monoxide"]),
    ("Grid down for a month in the city", 4, 30, "two weeks of food, 10 gallons of water", ["water", "food", "sanitation", "security", "power"]),
    ("Wildfire evacuation in 30 minutes", 4, 3, "", ["wildfire", "evacuat", "kit", "go bag"]),
    ("Tornado destroyed part of our home", 4, 7, "tarp, tools, bottled water", ["shelter", "tarp", "roof", "tornado"]),
    ("Water main contaminated boil order for a week", 3, 7, "stove, bleach", ["boil", "water", "bleach", "disinfect"]),
    ("Chemical plant accident shelter in place", 4, 2, "duct tape, plastic sheeting", ["chemical", "shelter", "seal", "hazard", "gas"]),
    ("Pandemic lockdown with sick family member", 4, 21, "masks, fever medicine", ["isolat", "disease", "fever", "hygiene", "quarantine"]),
    ("Camping trip gone wrong, tent collapsed in storm", 2, 1, "tarp, rope", ["shelter", "tarp", "storm", "rope"]),
    ("Remote cabin, generator failed, winter", 2, 10, "wood, food for a month", ["heat", "wood", "stove", "generator", "cold"]),
    ("Extended blackout in summer heat, elderly parent", 3, 5, "fans, water", ["heat", "cool", "water", "elderly"]),
    ("Ice storm, trees down, no road access", 4, 6, "wood stove, propane, canned food", ["ice", "storm", "heat", "road", "tree"]),
    ("Boat capsized, now on a deserted shore", 2, 3, "life jackets, knife", ["shore", "water", "shelter", "signal", "sea"]),
    ("Plane crash survivors in mountains", 3, 4, "parachute cloth, few snacks", ["crash", "shelter", "signal", "cold", "mountain"]),
    ("Civil unrest, need to stay home safely", 4, 14, "food for two weeks, water", ["security", "home", "water", "stay", "defen"]),
    ("Nuclear detonation warning", 4, 3, "basement, canned food", ["fallout", "shelter", "radiation", "nuclear"]),
    ("Drought, well running dry on the homestead", 4, 30, "rain barrels, some stored water", ["water", "well", "rain", "conserv", "drought"]),
    ("Job loss and no money, food running low", 3, 30, "garden space, pantry", ["food", "garden", "ration", "store"]),
    ("Alone in the wilderness, ankle sprained", 1, 3, "pack, tent, little food", ["sprain", "shelter", "water", "signal", "ankle"]),
    ("Solar storm knocked out electronics", 4, 14, "radio, batteries", ["power", "battery", "radio", "electric"]),
]:
    S.append(("plan", None, t, f"{p} people, {d} days, have: {h}", e))
