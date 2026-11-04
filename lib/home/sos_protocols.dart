// Built-in emergency protocols. These are short, general first-aid summaries that work with no
// library, no model and no signal. They are not a substitute for training: each screen says so.

class Protocol {
  const Protocol(this.title, this.subtitle, this.steps, {this.warning});
  final String title;
  final String subtitle;
  final List<String> steps;
  final String? warning;
}

const protocols = <Protocol>[
  Protocol('Severe bleeding', 'Heavy bleeding that will not stop', [
    'Call your local emergency number if you can. Put the phone on speaker.',
    'Press hard, straight down on the wound with a clean cloth or your hand. Use both hands and your body weight.',
    'Do not lift the cloth to look. If blood soaks through, add more cloth on top and keep pressing.',
    'If bleeding from an arm or leg is life-threatening and pressure is not working, put a tourniquet 2-3 inches (5-8 cm) above the wound, never on a joint. Tighten until the bleeding stops.',
    'Write down the time the tourniquet was applied. Do not loosen it.',
    'Lay the person down, keep them warm, and keep checking their breathing until help arrives.',
  ]),
  Protocol('Adult CPR (hands-only)', 'Person is unresponsive and not breathing normally', [
    'Tap their shoulders and shout. If no response and no normal breathing, call your emergency number or send someone. Ask for an AED.',
    'Lay them on their back on a firm surface.',
    'Place the heel of one hand on the center of the chest, other hand on top.',
    'Push hard and fast: about 2 inches (5 cm) deep, 100-120 pushes per minute. Let the chest rise fully between pushes.',
    'Do not stop until help takes over, an AED is ready, or the person starts breathing normally.',
    'When an AED arrives, turn it on and follow its voice prompts.',
  ]),
  Protocol('CPR on a child or baby', 'Child (1 year to puberty) or baby (under 1 year)', [
    'Check for response and normal breathing. If none and you are alone, give 2 minutes of CPR first, then call for help. If someone else is there, send them to call now.',
    'Child: push on the center of the chest with one or two hands, about 2 inches (5 cm) deep.',
    'Baby: push with two fingers just below the nipple line, about 1.5 inches (4 cm) deep.',
    'Push 100-120 times per minute, letting the chest rise fully each time.',
    'If you are trained: after every 30 pushes give 2 gentle breaths (child: mouth to mouth; baby: cover mouth and nose). If not trained, give pushes only.',
    'Continue until help arrives or the child starts breathing normally.',
  ]),
  Protocol('Choking adult', 'Cannot cough, speak or breathe', [
    'Ask "Are you choking?" If they can cough or speak, encourage coughing and stay with them.',
    'If they cannot breathe, call or send someone to call your emergency number.',
    'Stand behind them. Give 5 firm back blows between the shoulder blades with the heel of your hand.',
    'Then give 5 abdominal thrusts: fist just above the belly button, other hand over it, pull sharply in and up.',
    'Alternate 5 back blows and 5 thrusts until the object comes out or they pass out.',
    'If they become unresponsive, lay them down and begin CPR. Look in the mouth before each set of breaths and remove any object you see.',
  ]),
  Protocol('Choking baby (under 1 year)', 'Baby cannot cry, cough or breathe', [
    'Call or send someone to call your emergency number.',
    'Lay the baby face-down along your forearm, head lower than the body, supporting the jaw. Rest your arm on your thigh.',
    'Give 5 firm back blows between the shoulder blades with the heel of your hand.',
    'Turn the baby face-up, head lower than the body. Give 5 chest thrusts with two fingers on the center of the chest, about 1.5 inches (4 cm) deep.',
    'Repeat back blows and chest thrusts until the object comes out or the baby becomes unresponsive.',
    'If unresponsive, begin infant CPR. Never do abdominal thrusts on a baby.',
  ]),
  Protocol('Anaphylaxis', 'Severe allergic reaction', [
    'Signs: swelling of lips or throat, trouble breathing, wheeze, hives with dizziness or fainting.',
    'Use an epinephrine auto-injector right away in the outer middle thigh, through clothing if needed.',
    'Call your emergency number, even if the person improves.',
    'Lay them flat with legs raised. If they are struggling to breathe or vomiting, let them sit up or lie on their side.',
    'If symptoms do not improve in 5-15 minutes and a second injector is available, give it.',
    'Do not let them stand or walk. They must be seen at a hospital afterward.',
  ]),
  Protocol('Heat stroke', 'Hot, confused, or collapsed in the heat', [
    'Signs: very hot skin, confusion, fainting, fast pulse, headache. This is an emergency. Call your emergency number.',
    'Move them into shade or a cool room. Remove extra clothing.',
    'Cool them fast by any means: cold water immersion if you can, or soak the skin with cool water and fan them.',
    'Put cold packs or wet cloths on the neck, armpits and groin.',
    'If awake and able to swallow, give small sips of cool water. Give nothing by mouth if confused or unconscious.',
    'Keep cooling until help arrives.',
  ]),
  Protocol('Hypothermia', 'Cold, shivering, slow or confused', [
    'Call your emergency number. Handle the person gently.',
    'Move them out of wind, rain and snow. Remove wet clothing.',
    'Insulate from the ground, then wrap in blankets, sleeping bags or dry clothing. Cover the head.',
    'Warm the center of the body first: chest, neck, groin. Do not rub the arms or legs.',
    'If awake and able to swallow, give warm sweet drinks. No alcohol.',
    'If they stop breathing, start CPR and keep warming.',
  ]),
  Protocol('Snakebite or suspected venomous bite', 'Bitten and swelling, pain or discoloration', [
    'Move away from the snake. Do not try to catch or kill it.',
    'Call your emergency number and get to a hospital as soon as possible so antivenom can be given if needed.',
    'Keep the person calm and still. Keep the bitten limb at or slightly below heart level.',
    'Remove rings, watches and tight clothing near the bite before swelling starts.',
    'Wash gently with soap and water and cover with a clean, dry dressing.',
    'Do not cut the wound, suck out venom, apply ice, or use a tourniquet.',
  ]),
  Protocol('Burns', 'Heat, hot liquid or chemical burns', [
    'Stop the burning. Remove the person from the source. Remove jewelry and tight clothing near the burn unless stuck to the skin.',
    'Cool the burn under cool running water for 20 minutes.',
    'Cover loosely with a clean, non-stick dressing or plastic wrap.',
    'Do not use ice, butter or creams. Do not pop blisters.',
    'Call your emergency number for burns that are large, deep, on the face, hands, feet or genitals, or caused by chemicals or electricity.',
  ], warning: 'For chemical burns, brush off dry powder first, then flush with water for at least 20 minutes.'),
];
