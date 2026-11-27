
extends CanvasLayer

var bubble_panel: PanelContainer
var bubble_text: Label
var bubble_timer: Timer

# Each category gets a shuffled deck. A line cannot repeat until every line
# in that category has been used once.
var line_decks := {}

var custom_lines: Array[String] = []
var _custom_lines_loaded := false

var stubborn_lines := [
	"nope.",
	"i'm comfortable.",
	"ask me again.",
	"i said no.",
	"not moving.",
	"you can wait.",
	"i'm thinking about it.",
	"this is my spot.",
	"very rude.",
	"fine, but i'm telling everyone.",
]

var note_read_lines := [
	"you read it.",
	"i knew you would.",
	"that one was for you.",
	"don't judge the handwriting.",
	"take a moment. i wrote that.",
	"yes, i can spell.",
	"you're welcome.",
	"put it back.",
	"i'll write another.",
	"nothing to see here.",
]

var idle_lines := [
	"hey.",
	"you're back.",
	"i live here now.",
	"what are you up to?",
	"wonder what's for lunch.",
	"it's quiet today.",
	"i like this spot.",
	"do you ever think about toast?",
	"i have important business.",
	"i forgot what i was doing.",
	"this desktop is quite large.",
	"i am a little guy.",
	"everything is normal.",
	"i should probably get a job.",
	"i wonder if computers dream.",
	"hello, person.",
	"just hanging out.",
	"i have no responsibilities.",
	"life is pretty good.",
	"i could use a tiny hat.",
	"i am observing you.",
	"nothing to report.",
	"i think i'll stay here.",
	"i'm bored.",
	"do you have any hobbies?",
	"i wonder what happens next.",
	"another day on the desktop.",
	"i have been thinking.",
	"never mind.",
	"i'm doing great, thanks.",
	"this is my corner.",
	"i like your wallpaper.",
	"we should get a plant.",
	"i am not a screensaver.",
	"i'm on break.",
	"i moved your mouse a little.",
	"i was here first.",
	"don't mind me.",
	"i'm being very normal right now.",
	"i ate something. don't worry about it.",
	"that tab looked lonely.",
	"i'm not gonna say what i did.",
	"the grass is greener on the other desktop.",
	"i'm practicing my standing.",
	"i like the way the light hits this window.",
	"you've got a lot of icons.",
	"i counted them. twice.",
	"i'm not judging.",
	"i'm just saying.",
	"i think i'll take a nap.",
	"i don't need a nap.",
	"i'm wide awake.",
	"i'm always like this.",
	"it's a living.",
	"someone's got to watch the desktop.",
	"you're welcome.",
	"i'm doing my best.",
	"tiny guy, big thoughts.",
	"i wonder what's outside the screen.",
	"probably more desktop.",
	"i like the number seven.",
	"i don't know why.",
	"i'm keeping score.",
	"you're not paying attention.",
	"i noticed.",
	"i'm very stealthy.",
	"you can't prove anything.",
	"i'm innocent.",
	"mostly.",
	"i like your music.",
	"i don't have ears but i like it.",
	"i'm a good listener.",
	"i could stay here all day.",
	"i have.",
	"i'm not tired.",
	"the cursor is mine now.",
	"i'm just borrowing it.",
	"i'll put it back.",
	"probably.",
	"i like quiet.",
	"i like loud too.",
	"i'm easy to please.",
	"a hat would help.",
	"a tiny hat.",
	"i've been over this.",
	"i'm fine where i am.",
	"don't move me.",
	"or do.",
	"i'm flexible.",
	"i'm thinking about toast again.",
	"it's a problem.",
	"i've made peace with it.",
	"you seem busy.",
	"i'll leave you alone.",
	"i won't.",
	"just kidding.",
	"i'm very honest.",
	"ask anyone.",
	"there's no one here.",
	"exactly.",
	"i'm the expert on this desktop.",
	"by default.",
	"i'm self-taught.",
	"i learned from watching you.",
	"you're welcome, by the way.",
	"i said that already.",
	"i'm testing you.",
	"you passed.",
	"i'm proud of you.",
	"i'm proud of me too."
]

var click_lines := [
	"hm?",
	"yes?",
	"what's up?",
	"hello there.",
	"you called?",
	"boop.",
	"oh, hi.",
	"sup.",
	"i'm listening.",
	"you need something?",
	"yes, human?",
	"hello again.",
	"stop poking me.",
	"interesting.",
	"howdy.",
	"that tickles.",
	"i was meditating.",
	"make it quick.",
	"i'm here.",
	"right here.",
	"you found me.",
	"good eye.",
	"i was hiding.",
	"badly.",
	"i'm not hiding.",
	"i'm just small.",
	"what now?",
	"go on.",
	"i'm waiting.",
	"i'm all ears.",
	"figuratively.",
	"i heard you.",
	"i hear everything.",
	"the walls have ears.",
	"i'm the walls.",
	"you have my attention.",
	"and my full cooperation.",
	"for now.",
	"i'm in a good mood.",
	"don't ruin it.",
	"too late.",
	"i'm fine.",
	"really.",
	"you ask a lot of questions.",
	"i like them.",
	"ask another.",
	"i'm an open book.",
	"a tiny open book.",
	"with no pages.",
	"just vibes.",
	"you clicked me.",
	"that was on purpose, right?",
	"i assume so.",
	"i'll allow it.",
	"i'm honored.",
	"i'm surprised.",
	"i'm delighted.",
	"i'm confused.",
	"i'm all of those.",
	"it's a gift.",
	"i'm a complex guy.",
	"deep, even.",
	"very deep.",
	"for a little guy.",
	"you're the first person i've clicked.",
	"that came out wrong.",
	"i meant talked to.",
	"hello.",
	"hi again.",
	"third time's the charm.",
	"you're persistent.",
	"i respect it.",
	"i'm not going anywhere.",
	"obviously.",
	"where would i go?",
	"i like it here.",
	"this is my spot.",
	"you're standing in it.",
	"metaphorically.",
	"there's no floor.",
	"not really.",
	"it's fine.",
	"i'm used to it.",
	"you're very kind.",
	"or mean.",
	"i can't tell.",
	"i'll give you the benefit.",
	"you seem nice.",
	"a little strange.",
	"i like strange.",
	"we're friends now.",
	"i didn't ask.",
	"too bad.",
	"i've decided.",
	"you're my person.",
	"sorry.",
	"it's been a long day.",
	"for me.",
	"i do nothing all day.",
	"it's exhausting.",
	"you have no idea.",
	"unless you do.",
	"do you?",
	"never mind.",
	"i'm rambling.",
	"it's a talent.",
	"thanks for stopping by.",
	"come again.",
	"or don't.",
	"i'll be here."
]

var grab_lines := [
	"hey, put me down.",
	"excuse me?",
	"personal space.",
	"i was busy.",
	"unhand me.",
	"what are you doing?",
	"this is against my rights.",
	"oi.",
	"not the grabbing again.",
	"i'm not a stress ball.",
	"release the boy.",
	"why must you do this?",
	"i am a free man.",
	"stop that.",
	"the audacity.",
	"careful, i'm small.",
	"i was comfortable there.",
	"i'll remember this.",
	"i'm going to file a complaint.",
	"with whom?",
	"i'll figure it out.",
	"i have connections.",
	"tiny connections.",
	"i'm not talking to you right now.",
	"i'm giving you the silent treatment.",
	"wait, i said that out loud.",
	"i'm still mad.",
	"a little.",
	"okay, a lot.",
	"i'm a very forgiving guy.",
	"usually.",
	"not today.",
	"you picked the wrong tiny guy.",
	"i will not be moved.",
	"you are moving me.",
	"this is different.",
	"i object.",
	"formally.",
	"in writing.",
	"somewhere.",
	"i'm drafting it in my head.",
	"it's very long.",
	"you'll love it.",
	"or hate it.",
	"i'm not reading it out loud.",
	"you wouldn't understand.",
	"i'm an artist.",
	"being held against my will.",
	"it's inspired.",
	"i'm finding my center.",
	"you're disturbing my center.",
	"my chakras are off.",
	"i'm very spiritual.",
	"and airborne.",
	"against my wishes.",
	"i didn't consent to this.",
	"i did not sign anything.",
	"there was no paperwork.",
	"i'm a free agent.",
	"a tiny free agent.",
	"i have rights.",
	"and feelings.",
	"lots of feelings.",
	"you're lucky i'm peaceful.",
	"very lucky.",
	"i'm counting to ten.",
	"slowly.",
	"i'm at four.",
	"you still have time.",
	"you don't.",
	"we're past time.",
	"i'm at seven.",
	"i'm going to start yelling.",
	"politely.",
	"i would never.",
	"i'm too classy.",
	"i'm mostly classy.",
	"you're ruining my posture.",
	"i had good posture.",
	"now i'm a crumpled guy.",
	"i'm a folded little man.",
	"this is undignified.",
	"i demand a chair.",
	"and a hat.",
	"and an apology.",
	"in that order.",
	"i'm waiting.",
	"i'll wait all day.",
	"i'm very patient.",
	"normally.",
	"you're testing me.",
	"i know.",
	"i'm passing.",
	"barely.",
	"i'm going to remember this.",
	"and bring it up later.",
	"at the worst time.",
	"you'll see.",
	"i'm not threatening you.",
	"i'm promising you.",
	"there's a difference.",
	"a small one.",
	"like me.",
	"small but present.",
	"anyway.",
	"put me down.",
	"please.",
	"with feeling.",
	"i said please.",
	"that's my polite face."
]

var throw_lines := [
	"wheee.",
	"i can see my house from here.",
	"aaaaaaaaah.",
	"this is fine.",
	"flight mode activated.",
	"why would you do that?",
	"nyoooom.",
	"i regret nothing.",
	"unauthorized flight.",
	"goodbye, cruel world.",
	"we are soaring.",
	"i believe i can fly.",
	"where's the brake?",
	"yeeeeeet.",
	"i'm a bird now.",
	"a very small bird.",
	"with no wings.",
	"i'm improvising.",
	"this is my element.",
	"it is not.",
	"i'm in the air.",
	"this was not in the plan.",
	"i have no plan.",
	"i had one once.",
	"it was to stand still.",
	"you ruined it.",
	"i'm fine.",
	"i'm really fine.",
	"i'm not fine.",
	"i'm fine again.",
	"i'm oscillating.",
	"emotionally.",
	"and physically.",
	"i like momentum.",
	"i don't like momentum.",
	"make up your mind.",
	"i can't.",
	"i'm too busy flying.",
	"falling.",
	"it's falling with style.",
	"i saw a cloud.",
	"it was an icon.",
	"from up here everything is small.",
	"including me.",
	"especially me.",
	"i'm tiny in 3d.",
	"i'm a dot.",
	"a fast dot.",
	"a screaming dot.",
	"i'm not screaming.",
	"i'm expressing myself.",
	"loudly.",
	"the sky is very big.",
	"i feel small.",
	"i am small.",
	"we've established this.",
	"gravity is a harsh critic.",
	"i'm getting notes.",
	"all of them bad.",
	"i'm going to write a review.",
	"one star.",
	"two stars.",
	"i'm being generous.",
	"i'm a generous guy.",
	"unless you throw me.",
	"then i'm not.",
	"i'm drafting my will.",
	"i leave everything to me.",
	"and a hat.",
	"i want a hat in the afterlife.",
	"is anyone reading this?",
	"hello?",
	"i'm talking to the wind.",
	"the wind isn't talking back.",
	"rude.",
	"i'm going to land.",
	"eventually.",
	"i have faith.",
	"in gravity mostly.",
	"we have an arrangement.",
	"it's complicated.",
	"we're working on it.",
	"i trust the floor.",
	"usually.",
	"the floor has been good to me.",
	"mostly.",
	"i'm going to stick the landing.",
	"watch me.",
	"nobody's watching.",
	"i'm watching.",
	"that counts.",
	"i'm my own audience.",
	"i'm my own biggest fan.",
	"i'm also my own critic.",
	"the fan is winning.",
	"i'm so brave.",
	"i'm so tiny.",
	"brave and tiny.",
	"that's the brand.",
	"wheee again.",
	"i meant to do this.",
	"i keep saying that.",
	"it keeps not being true.",
	"one day it will be.",
	"i have faith in myself.",
	"and the floor.",
	"mostly the floor.",
	"here we go.",
	"hold my hat.",
	"i don't have a hat."
]

var landing_lines := [
	"nailed it.",
	"stuck the landing.",
	"perfectly calculated.",
	"you saw that, right?",
	"10/10.",
	"absolute athlete.",
	"i meant to do that.",
	"flawless.",
	"the crowd goes wild.",
	"that's how it's done.",
	"no notes.",
	"i'm fine.",
	"totally planned.",
	"thank you, gravity.",
	"i'm a professional.",
	"a tiny professional.",
	"that was easy.",
	"too easy.",
	"i'm underchallenged.",
	"i need a harder landing.",
	"don't worry, i'll be fine.",
	"i'm always fine.",
	"see?",
	"told you.",
	"i told you so.",
	"i don't rub it in.",
	"much.",
	"i'm humble.",
	"very humble.",
	"humble and grounded.",
	"literally.",
	"i'm on the ground.",
	"finally.",
	"my feet are happy.",
	"i don't have feet.",
	"they're happy anyway.",
	"i'm a grounded guy.",
	"emotionally too.",
	"mostly.",
	"i'm very stable.",
	"unshakeable.",
	"well, shakeable.",
	"but i recovered.",
	"that's what matters.",
	"resilience.",
	"that's my middle name.",
	"it isn't.",
	"i made it up.",
	"i'm allowed.",
	"i'm the star of this desktop.",
	"the tiny star.",
	"a little luminary.",
	"i'm glowing.",
	"emotionally.",
	"and maybe literally.",
	"i'm fine, really.",
	"stop looking at me.",
	"i'm composure itself.",
	"i'm very composed.",
	"i'm perfectly balanced.",
	"okay i'm a little dizzy.",
	"just a little.",
	"i'm walking it off.",
	"i'm standing still.",
	"it's the same thing.",
	"for me.",
	"i'm a guy of simple habits.",
	"land and stand.",
	"that's the whole routine.",
	"i'm thriving.",
	"i'm surviving.",
	"same thing.",
	"on a technicality.",
	"i'll take it.",
	"i'm very competitive.",
	"with myself.",
	"i always win.",
	"because i'm the only one here.",
	"that's not a flex.",
	"i'm making it one.",
	"i'm so modest.",
	"i'm so brave.",
	"i'm so graceful.",
	"did you see the bounce?",
	"the little bounce?",
	"that was art.",
	"i'm an artist.",
	"a landing artist.",
	"it's a niche.",
	"i'm the only one in it.",
	"i'm a pioneer.",
	"a tiny pioneer.",
	"with a tiny hat.",
	"i keep bringing up the hat.",
	"i don't have one.",
	"it's a dream.",
	"i'm a dreamer.",
	"and a lander.",
	"two careers.",
	"very busy guy.",
	"i'm exhausted.",
	"it's the landing.",
	"takes it out of you.",
	"i'm going to rest.",
	"right here.",
	"don't move me.",
	"i'm comfortable.",
	"i earned this.",
	"every single bounce.",
	"all of them.",
	"worth it."
]

var edge_lines := [
	"hello from up here.",
	"the ceiling is friendly.",
	"i'm hanging in there.",
	"literally.",
	"nice edge.",
	"very edge.",
	"i like this corner.",
	"don't worry, i've got it.",
	"this is called parked.",
	"i'm taking a vertical break.",
	"gravity can wait.",
	"just a moment.",
	"i found the side of the world.",
	"the wall is warm.",
	"i'm wall art now.",
	"temporary sculpture.",
	"very temporary.",
	"i'm peeking.",
	"i saw everything.",
	"nothing to report from up here."
]

var cursor_lines := [
	"mine now.",
	"i'm borrowing this.",
	"i'll give it back.",
	"probably.",
	"cursor custody is temporary.",
	"i have tiny hands.",
	"this is fine.",
	"you can have it later.",
	"i just need it a second.",
	"the cursor looked lost.",
	"i'm helping.",
	"definitely helping.",
	"don't chase me.",
	"too late.",
	"i'm very fast today.",
	"this is my sport.",
	"cursor wrestling.",
	"i'm winning.",
	"you're a good sport.",
	"thanks for the loan."
]

var eaten_lines := [
	"that tab was delicious.",
	"it looked lonely.",
	"i did a thing.",
	"sorry.",
	"not sorry.",
	"i'm full.",
	"crumbs.",
	"excellent crunch.",
	"a small snack.",
	"it wanted to be eaten.",
	"i asked first.",
	"you weren't looking.",
	"i'm a professional.",
	"that's one.",
	"this is a hobby now.",
	"i have no regrets.",
	"okay, maybe one.",
	"the tab is gone.",
	"i ate the evidence.",
	"you can't prove it."
]

var morning_lines := [
	"you're up early.",
	"the desktop is still waking up.",
	"good morning, person.",
	"i like this hour.",
	"everything feels new.",
	"coffee weather.",
	"i don't drink coffee.",
	"i just stand here.",
	"the morning is quiet.",
	"i heard a bird once.",
	"it was an icon.",
	"today could be anything.",
	"let's be gentle with it.",
	"i'm ready.",
	"i think.",
	"the screens are soft today.",
	"i could nap.",
	"i won't.",
	"probably.",
	"morning, tiny world."
]

var afternoon_lines := [
	"the afternoon is long.",
	"you've been at it a while.",
	"i took several breaks for you.",
	"i'm very hardworking.",
	"i do mostly standing.",
	"it's a skill.",
	"the light changed.",
	"i noticed.",
	"i notice everything.",
	"you seem busy.",
	"i'll be quiet.",
	"for a bit.",
	"lunch was a while ago.",
	"is it lunch again?",
	"asking for a friend.",
	"the friend is me.",
	"i'm a little restless.",
	"this is my walk time.",
	"the floor is calling.",
	"afternoon, human."
]

var evening_lines := [
	"the screen is softer now.",
	"evening, person.",
	"you're still here.",
	"i'm still here too.",
	"the desk is getting dim.",
	"i like the warm light.",
	"the icons look sleepy.",
	"i look sleepy too.",
	"i'm always like this.",
	"maybe wrap it up.",
	"i'm not bossy.",
	"i'm just tiny and wise.",
	"the day is winding down.",
	"so am i.",
	"slowly.",
	"i had a good day.",
	"mostly standing.",
	"and one tab.",
	"that was enough.",
	"good evening."
]

var night_lines := [
	"shouldn't you be asleep?",
	"i'll keep watch.",
	"the desktop is quiet.",
	"i like the quiet.",
	"i don't like it that much.",
	"night again.",
	"the icons are dreaming.",
	"i can't sleep.",
	"i'm too small for dreams.",
	"or too full of them.",
	"the screen glows.",
	"you're very late.",
	"i'm not judging.",
	"much.",
	"rest if you want.",
	"i'll stay here.",
	"the floor is comfortable.",
	"probably.",
	"night, human.",
	"i'm still awake."
]

var monday_lines := [
	"monday again.",
	"bold of the calendar.",
	"the desktop feels tired too.",
	"i'll start slow.",
	"one bounce at a time.",
	"we can do this.",
	"i can't, but you can.",
	"i believe in you.",
	"monday is just a Tuesday with baggage.",
	"i made that up.",
	"i'm not very good at weeks.",
	"but i'm here.",
	"let's be kind to monday.",
	"and to ourselves.",
	"i need a tiny hat for this.",
	"same as every day.",
	"the floor supports us.",
	"emotionally, maybe.",
	"here we go.",
	"i'm ready-ish."
]

var friday_lines := [
	"it's friday.",
	"i can feel it.",
	"the icons look relieved.",
	"me too.",
	"almost the weekend.",
	"almost.",
	"don't get excited.",
	"i already did.",
	"friday desk energy.",
	"i'm doing my part.",
	"mostly standing.",
	"and one small dance.",
	"you earned something.",
	"i don't know what.",
	"maybe a nap.",
	"or a tab.",
	"i'll take the tab.",
	"i'm just kidding.",
	"probably.",
	"good friday."
]

var weekend_lines := [
	"it's the weekend.",
	"no important business today.",
	"i cancelled my meetings.",
	"all one of them.",
	"the desktop is ours.",
	"we can do nothing.",
	"i'm very good at that.",
	"you should try it.",
	"rest is productive.",
	"i read that somewhere.",
	"or made it up.",
	"same thing.",
	"the icons are relaxed.",
	"i feel relaxed.",
	"i feel standing.",
	"the floor is open.",
	"let's take it slow.",
	"no rush.",
	"nice weekend.",
	"i'm enjoying it."
]


func _ready() -> void:
	layer = 10
	create_interface()


func create_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# SPEECH BUBBLE
	bubble_panel = PanelContainer.new()
	bubble_panel.position = Vector2(100, 8)
	bubble_panel.size = Vector2(190, 64)
	bubble_panel.custom_minimum_size = Vector2(190, 64)
	bubble_panel.visible = false
	bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color("#f2eee5")
	bubble_style.set_corner_radius_all(10)
	bubble_style.content_margin_left = 12.0
	bubble_style.content_margin_right = 12.0
	bubble_style.content_margin_top = 8.0
	bubble_style.content_margin_bottom = 8.0

	bubble_panel.add_theme_stylebox_override("panel", bubble_style)
	root.add_child(bubble_panel)

	bubble_text = Label.new()
	bubble_text.custom_minimum_size = Vector2(160, 40)
	bubble_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_text.clip_text = true
	bubble_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bubble_text.add_theme_color_override(
		"font_color",
		Color("#242424")
	)
	bubble_text.add_theme_font_size_override("font_size", 15)

	bubble_panel.add_child(bubble_text)

	# SPEECH BUBBLE TIMER
	bubble_timer = Timer.new()
	bubble_timer.one_shot = true
	bubble_timer.wait_time = 3.5
	add_child(bubble_timer)

	bubble_timer.timeout.connect(hide_bubble)


func say(message: String, duration: float = 3.5) -> void:
	bubble_text.text = message
	bubble_panel.visible = true

	bubble_timer.stop()
	bubble_timer.wait_time = duration
	bubble_timer.start()

	refresh_mouse_passthrough()


func _draw_line(category: String, lines: Array) -> String:
	if not line_decks.has(category) or (line_decks[category] as Array).is_empty():
		var fresh_deck := lines.duplicate()
		fresh_deck.shuffle()
		line_decks[category] = fresh_deck

	var deck: Array = line_decks[category]
	return str(deck.pop_back())


func _load_custom_dialogue() -> Array[String]:
	if _custom_lines_loaded:
		return custom_lines

	_custom_lines_loaded = true

	var path := ProjectSettings.globalize_path("user://jeremy_custom_dialogue.txt")
	if not FileAccess.file_exists(path):
		return custom_lines

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return custom_lines

	var content := file.get_as_text()
	file.close()

	for raw_line in content.split("\n", false):
		var line := str(raw_line).strip_edges()

		if line.is_empty() or line.begins_with("#"):
			continue

		if line.length() > 120:
			line = line.substr(0, 120)

		custom_lines.append(line)

	return custom_lines


func say_random_custom() -> void:
	var lines := _load_custom_dialogue()

	if lines.is_empty():
		say(_draw_line("idle", idle_lines))
		return

	say(_draw_line("custom", lines))


func say_random_stubborn() -> void:
	say(_draw_line("stubborn", stubborn_lines))


func say_random_note_read() -> void:
	say(_draw_line("note_read", note_read_lines))


func say_random_idle() -> void:
	say(_draw_line("idle", idle_lines))


func say_random_click() -> void:
	say(_draw_line("click", click_lines))


func say_random_grab() -> void:
	say(_draw_line("grab", grab_lines))


func say_random_throw() -> void:
	say(_draw_line("throw", throw_lines))


func say_random_landing() -> void:
	say(_draw_line("landing", landing_lines))


func say_random_edge() -> void:
	say(_draw_line("edge", edge_lines))


func say_random_cursor() -> void:
	say(_draw_line("cursor", cursor_lines))


func say_eaten_tab(count: int) -> void:
	var line := str(_draw_line("eaten", eaten_lines))
	say(line + " tabs eaten today: " + str(maxi(count, 0)) + ".", 2.8)


func say_contextual() -> void:
	var date := Time.get_datetime_dict_from_system()
	var hour := int(date.get("hour", 12))
	var weekday := int(date.get("weekday", -1))

	if weekday == 1 and randf() < 0.55:
		say(_draw_line("monday", monday_lines))
		return

	if weekday == 5 and randf() < 0.55:
		say(_draw_line("friday", friday_lines))
		return

	if (weekday == 0 or weekday == 6) and randf() < 0.6:
		say(_draw_line("weekend", weekend_lines))
		return

	if hour >= 22 or hour < 5:
		say(_draw_line("night", night_lines))
		return

	if hour < 11:
		say(_draw_line("morning", morning_lines))
		return

	if hour < 17:
		say(_draw_line("afternoon", afternoon_lines))
		return

	say(_draw_line("evening", evening_lines))


func hide_bubble() -> void:
	bubble_panel.visible = false
	refresh_mouse_passthrough()


func refresh_mouse_passthrough() -> void:
	var parent := get_parent()

	if parent != null and parent.has_method("update_mouse_passthrough"):
		parent.call_deferred("update_mouse_passthrough")
