extends Node2D

var profile: JellyProfile
var sound: JellySound
var art: JellyArt
var arena: JellyArena
var ui: Control
var screen = "menu"
var previous_screen = "menu"
var clock = 0.0
var title_label: Label
var hud_label: Label
var mass_label: Label
var status_label: Label
var banner_label: Label
var boss_label: Label
var time_label: Label
var settings_return = "menu"
var binding_wait = ""
var binding_label: Label
var gamepad = false
var smoke = false
var smoke_level = 0
var smoke_log: Array = []
var smoke_clock = 0.0
var capture_mode = ""
var capture_clock = 0.0
var result_won = false
var quitting = false
var joy_device = 0
var capture_tag = ""

func tr2(ru: String,en: String) -> String:
	return ru if profile.data.lang=="ru" else en

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_tree().auto_accept_quit = false
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--smoke": smoke = true
		if arg.begins_with("--capture="): capture_mode = arg.trim_prefix("--capture=")
		if arg.begins_with("--tag="): capture_tag=arg.trim_prefix("--tag=")
	profile = JellyProfile.new("user://test_profile.json" if smoke or capture_mode != "" else "")
	setup_inputs()
	art = JellyArt.new()
	sound = JellySound.new()
	add_child(sound)
	sound.setup(profile)
	ui = Control.new()
	ui.name = "Interface"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	apply_display()
	show_menu()
	if smoke:
		profile.data.assist = true
		start_level(0,false)
		arena.bot = true
	if capture_mode == "arena" or capture_mode == "boss":
		start_level(3 if capture_mode=="boss" else 0,false)
		arena.wave_wait = 0
		if capture_mode=="boss": arena.wave = 1
	if capture_mode == "map":
		profile.data.unlocked = 6
		show_map()
	if capture_mode == "final": show_final()
	if capture_mode == "settings": show_settings("menu")
	if capture_mode == "upgrades":
		start_level(0,false)
		arena.active = false
		show_upgrades()
	if capture_mode == "pause":
		start_level(0,false)
		show_pause()
	for arg in args:
		if arg=="--english":
			profile.data.lang="en"
			if capture_mode=="settings": show_settings("menu")
			elif capture_mode=="menu": show_menu()
		if arg.begins_with("--size="):
			var parts=arg.trim_prefix("--size=").split("x")
			if parts.size()==2:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_size(Vector2i(int(parts[0]),int(parts[1])))

func setup_inputs():
	var keys = {"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"push":[KEY_SPACE],"pause":[KEY_ESCAPE],"dash":[]}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action,0.2)
		InputMap.action_erase_events(action)
		for code in keys[action]:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)
		if profile.data.bindings.has(action):
			InputMap.action_erase_events(action)
			var event = InputEventKey.new()
			event.physical_keycode = int(profile.data.bindings[action])
			InputMap.action_add_event(action,event)
	for info in [["dash",MOUSE_BUTTON_LEFT],["push",MOUSE_BUTTON_RIGHT]]:
		var event = InputEventMouseButton.new()
		event.button_index = info[1]
		InputMap.action_add_event(info[0],event)
	for info in [["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0],["up",JOY_AXIS_LEFT_Y,-1.0],["down",JOY_AXIS_LEFT_Y,1.0],["dash",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		var event = InputEventJoypadMotion.new()
		event.axis = info[1]
		event.axis_value = info[2]
		InputMap.action_add_event(info[0],event)
	for info in [["push",JOY_BUTTON_A],["pause",JOY_BUTTON_START]]:
		var event = InputEventJoypadButton.new()
		event.button_index = info[1]
		InputMap.action_add_event(info[0],event)

func apply_display():
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if profile.data.vsync else DisplayServer.VSYNC_DISABLED)
	if not profile.data.fullscreen:
		DisplayServer.window_set_size([Vector2i(1440,810),Vector2i(1280,720),Vector2i(1920,1080)][clampi(profile.data.resolution,0,2)])

func clear_ui():
	for node in ui.get_children():
		ui.remove_child(node)
		node.queue_free()
	hud_label = null
	mass_label = null
	status_label = null
	banner_label = null
	boss_label = null
	time_label = null

func label_at(value: String,rect: Rect2,size: int = 18,color: Color = JellyArt.CREAM,center: bool = false) -> Label:
	var label = Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(label)
	return label

func box(rect: Rect2,color: Color = Color("302239")):
	var panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	style.set_border_width_all(1)
	style.border_color = Color("705168")
	panel.add_theme_stylebox_override("panel",style)
	ui.add_child(panel)

func button(value: String,rect: Rect2,callback: Callable,primary: bool = false,disabled: bool = false) -> Button:
	var b = Button.new()
	b.text = value
	b.position = rect.position
	b.size = rect.size
	b.disabled = disabled
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",Color("302139") if primary else JellyArt.CREAM)
	b.add_theme_color_override("font_hover_color",Color("302139"))
	b.add_theme_color_override("font_focus_color",Color("302139"))
	b.add_theme_color_override("font_pressed_color",Color("302139"))
	b.add_theme_color_override("font_disabled_color",Color("79647f"))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.bg_color = Color("ef9db7") if primary else Color("493247")
		if state in ["hover","focus"]: style.bg_color = Color("ffe3bb")
		if state == "pressed": style.bg_color = Color("c888a6")
		if state == "disabled": style.bg_color = Color("2d2635")
		style.set_border_width_all(2 if state=="focus" else 1)
		style.border_color = Color("fff0c7") if state=="focus" else Color("81566e")
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(func():
		sound.play("click")
		callback.call())
	b.mouse_entered.connect(func(): sound.play("hover"))
	ui.add_child(b)
	return b

func focus_first():
	for child in ui.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break

func stop_arena():
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
		arena = null

func show_menu():
	stop_arena()
	screen = "menu"
	clear_ui()
	sound.song("menu")
	button(tr2("Продолжить","Continue") if profile.data.unlocked>1 else tr2("Начать приключение","Let's get wobbly"),Rect2(50,278,325,48),func():
		if profile.data.finished: show_map()
		else: start_level(profile.data.unlocked-1,not profile.data.tutorial),true)
	button(tr2("Карта десертов","Dessert map"),Rect2(50,337,157,40),show_map)
	button(tr2("Настройки","Settings"),Rect2(218,337,157,40),func(): show_settings("menu"))
	button(tr2("Как играть","How to play"),Rect2(50,388,157,40),func(): show_help("menu"))
	button(tr2("Авторы","Credits"),Rect2(218,388,157,40),show_credits)
	button(tr2("Выход","Quit"),Rect2(50,439,325,36),quit_game)
	label_at(tr2("Собирай. Раздувайся. Рикошеть.","Gobble. Grow. Ricochet."),Rect2(50,485,500,24),15,Color("bfa5b9"))
	label_at("v1.0  /  OFFLINE ARCADE",Rect2(748,507,190,20),11,Color("8f7894"))
	if profile.recovered: label_at(tr2("Профиль восстановлен из резервной копии.","Profile recovered from backup."),Rect2(400,480,530,30),14)
	focus_first()

func show_map():
	stop_arena()
	screen = "map"
	clear_ui()
	sound.song("menu")
	label_at(tr2("КАРТА ДЕСЕРТОВ","THE DESSERT TRAIL"),Rect2(50,35,700,40),30)
	label_at(tr2("Шесть маленьких приключений. Большой желейный финал.","Six little adventures. One glorious jelly finale."),Rect2(50,80,800,28),16,Color("bfa5b9"))
	var themes_ru = ["МАЛИНОВАЯ КОНДИТЕРСКА","КАРАМЕЛЬНАЯ МАСТЕРСКАЯ","МЯТНЫЙ ХОЛОДИЛЬНИК"]
	var themes_en = ["RASPBERRY PATISSERIE","CARAMEL WORKSHOP","MINT REFRIGERATOR"]
	for i in 6:
		var col = i/2
		var row = i%2
		var x = 50+col*292
		var y = 150+row*103
		if row==0: label_at((themes_ru if profile.data.lang=="ru" else themes_en)[col],Rect2(x,120,280,24),12,Color("a6d5c8"))
		box(Rect2(x,y,275,89))
		var open = i < profile.data.unlocked
		var name_text = str(i+1)+"  "+GameData.LEVELS[i][profile.data.lang] if open else tr2("Закрыто","Locked")
		button(name_text,Rect2(x+9,y+8,257,40),func(): start_level(i,false),false,not open)
		var stars = ""
		for bit in [1,2,4]: stars += "★ " if int(profile.data.medals[i]) & bit else "☆ "
		label_at(stars+"   "+str(int(profile.data.scores[i])),Rect2(x+15,y+54,245,25),16,Color("eac48b"))
	label_at(tr2("Медали: ","Medals: ")+str(profile.medals())+" / 18",Rect2(50,371,280,28),19)
	label_at(tr2("Победа  /  Без урона  /  Цепочка ×4","Victory  /  No damage  /  Chain ×4"),Rect2(50,402,550,23),14,Color("bfa5b9"))
	var skins = [tr2("Малина","Raspberry"),tr2("Лайм · 6 ★","Lime · 6 ★"),tr2("Черника · 12 ★","Blueberry · 12 ★"),tr2("Золотая · финал","Golden · finale")]
	for i in 4:
		var locked = (i==1 and profile.medals()<6) or (i==2 and profile.medals()<12) or (i==3 and not profile.data.finished)
		button(skins[i],Rect2(50+i*217,444,205,38),func(): profile.data.skin=i;profile.save();show_map(),profile.data.skin==i,locked)
	button(tr2("Назад","Back"),Rect2(755,36,155,40),show_menu)
	focus_first()

func start_level(index: int,training: bool):
	stop_arena()
	screen = "play"
	clear_ui()
	arena = JellyArena.new()
	arena.name = "Arena"
	add_child(arena)
	move_child(arena,0)
	arena.setup(index,profile,sound,art,training)
	arena.gamepad = gamepad
	arena.joy_device = joy_device
	arena.finished.connect(show_result)
	arena.choose_upgrade.connect(show_upgrades)
	arena.tutorial_complete.connect(show_hud)
	show_hud()

func show_hud():
	screen = "play"
	clear_ui()
	box(Rect2(40,18,235,67))
	hud_label = label_at("",Rect2(54,23,215,28),23,Color("f997b6"))
	mass_label = label_at("",Rect2(54,56,215,23),13,Color("d5bdcb"))
	status_label = label_at("",Rect2(292,22,410,30),19,JellyArt.CREAM,true)
	time_label = label_at("",Rect2(300,55,390,24),13,Color("af98b5"),true)
	button("Ⅱ",Rect2(864,25,45,40),show_pause)
	banner_label = label_at("",Rect2(90,155,780,45),27,JellyArt.CREAM,true)
	boss_label = label_at("",Rect2(250,455,460,25),15,JellyArt.CREAM,true)
	if arena.tutorial>=0: button(tr2("Пропустить обучение","Skip tutorial"),Rect2(710,493,205,32),func(): arena.skip_tutorial())

func show_pause():
	if not is_instance_valid(arena) or arena.ended: return
	arena.active = false
	arena.charging = false
	arena.charge = 0
	screen = "pause"
	clear_ui()
	box(Rect2(275,95,410,360),Color(.15,.1,.2,.98))
	label_at(tr2("МИНУТКА НА ДЕСЕРТ","A LITTLE BREATHER"),Rect2(280,120,400,40),25,JellyArt.CREAM,true)
	button(tr2("Продолжить","Keep wobbling"),Rect2(320,185,320,43),resume,true)
	button(tr2("Настройки","Settings"),Rect2(320,240,155,38),func(): show_settings("pause"))
	button(tr2("Управление","Controls"),Rect2(485,240,155,38),func(): show_help("pause"))
	button(tr2("Повторить","Retry"),Rect2(320,290,320,38),func(): confirm_exit(true))
	button(tr2("На карту","Dessert map"),Rect2(320,338,320,38),func(): confirm_exit(false))
	var upgrade_text = ""
	for id in arena.upgrades: upgrade_text += (GameData.UP_RU if profile.data.lang=="ru" else GameData.UP_EN)[id]+"  "
	var l = label_at(upgrade_text,Rect2(300,395,360,45),13,Color("bfa5b9"),true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_first()

func resume():
	show_hud()
	arena.active = true

func confirm_exit(retry: bool):
	screen = "confirm"
	clear_ui()
	box(Rect2(250,155,460,230))
	label_at(tr2("Завершить эту попытку?","Leave this attempt?"),Rect2(270,180,420,40),25,JellyArt.CREAM,true)
	label_at(tr2("Открытые уровни и медали сохранятся.","Unlocked levels and medals are safe."),Rect2(270,237,420,30),16,JellyArt.CREAM,true)
	button(tr2("Остаться","Stay"),Rect2(285,305,185,42),show_pause,true)
	button(tr2("Повторить","Retry") if retry else tr2("На карту","Map"),Rect2(490,305,185,42),func():
		if retry: start_level(arena.level,false)
		else: show_map())
	focus_first()

func show_upgrades():
	screen = "upgrades"
	clear_ui()
	box(Rect2(36,100,888,335),Color(.13,.09,.17,.98))
	label_at(tr2("ЩЕПОТКА ВОЛШЕБСТВА","A PINCH OF MAGIC"),Rect2(50,125,860,40),29,JellyArt.CREAM,true)
	label_at(tr2("Выбери один вкус. Действует до конца уровня.","Pick one flavour. Lasts until the end of this level."),Rect2(50,175,860,30),16,Color("c5a9be"),true)
	var choices = arena.choices()
	for i in 3:
		var id: int = choices[i]
		var x = 60+i*286
		box(Rect2(x,220,268,185),Color("493044"))
		label_at(["↗","✦","◆","◌","♥","≈","∞","◈","✧"][id],Rect2(x,231,268,35),30,Color("a7ddc9"),true)
		label_at((GameData.UP_RU if profile.data.lang=="ru" else GameData.UP_EN)[id],Rect2(x+8,276,252,30),18,JellyArt.CREAM,true)
		var desc = label_at((GameData.DESC_RU if profile.data.lang=="ru" else GameData.DESC_EN)[id],Rect2(x+14,312,240,42),14,Color("cdb3c3"),true)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button(tr2("Добавить!","Mix it in!"),Rect2(x+20,359,228,34),func(): arena.grant_upgrade(id);show_hud(),i==0)
	focus_first()
	if smoke:
		arena.grant_upgrade(choices[0])
		show_hud()

func show_result(won: bool):
	result_won = won
	screen = "result"
	clear_ui()
	box(Rect2(245,108,470,325),Color(.14,.09,.18,.97))
	label_at(tr2("СЛАДКАЯ ПОБЕДА!","SWEET VICTORY!") if won else tr2("БЫВАЕТ. МЫ ЖЕ ЖЕЛЕ!","A LITTLE WOBBLE."),Rect2(255,130,450,40),27,JellyArt.CREAM,true)
	label_at(tr2("Очки","Score")+"  "+str(arena.score)+"     "+tr2("Цепочка","Chain")+"  ×"+str(arena.best_chain),Rect2(270,186,420,30),19,Color("a7ddc9"),true)
	if won:
		var stars = "★   "+("★" if arena.hurt_count==0 else "☆")+"   "+("★" if arena.best_chain>=4 else "☆")
		label_at(stars,Rect2(270,225,420,40),32,Color("efc782"),true)
		button(tr2("Праздновать!","Let's celebrate!") if arena.level==5 else tr2("Следующий десерт","Next dessert"),Rect2(290,285,380,44),func():
			if arena.level==5: show_final()
			else: start_level(arena.level+1,false),true)
	else:
		label_at(tr2("Келли собралась. Соберёмся и мы.","Kelly bounced back. So can you."),Rect2(270,230,420,35),17,Color("c5a9be"),true)
		button(tr2("Ещё раз!","One more wobble!"),Rect2(290,285,380,44),func(): start_level(arena.level,false),true)
	button(tr2("Повторить","Retry"),Rect2(290,344,183,40),func(): start_level(arena.level,false))
	button(tr2("Карта","Map"),Rect2(487,344,183,40),show_map)
	focus_first()
	if smoke:
		smoke_log.append({"level":arena.level+1,"won":won,"hp":arena.hp,"time":arena.elapsed,"score":arena.score,"chain":arena.best_chain})
		call_deferred("next_smoke")

func next_smoke():
	smoke_level += 1
	if smoke_level >= 6:
		var report_path = "res://docs/bot_run.json" if OS.has_feature("editor") else "user://bot_run.json"
		var file = FileAccess.open(report_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(smoke_log,"\t"))
		print("BOT_RUN_COMPLETE ",JSON.stringify(smoke_log))
		get_tree().quit()
	else:
		start_level(smoke_level,false)
		arena.bot = true

func show_final():
	stop_arena()
	screen = "final"
	clear_ui()
	sound.song("menu")
	sound.play("win")
	label_at(tr2("ПРАВО БЫТЬ ЖЕЛЕ","BORN TO WOBBLE"),Rect2(40,40,880,60),38,JellyArt.CREAM,true)
	label_at(tr2("Праздник спасён. Венчик взбивает только сливки.","The party is saved. The whisk only whips cream now."),Rect2(60,109,840,30),18,Color("bce1cd"),true)
	label_at(tr2("«Идеальная форма? Моя — счастливая!» — Келли","“The perfect shape? Mine is happy!” — Kelly"),Rect2(60,365,840,40),22,JellyArt.CREAM,true)
	label_at(tr2("Открыта золотая посыпка. Спасибо за игру!","Golden sprinkles unlocked. Thank you for playing!"),Rect2(60,415,840,28),16,Color("c3a8ba"),true)
	button(tr2("Авторы","Credits"),Rect2(285,465,185,43),show_credits)
	button(tr2("Ещё десерт?","Another dessert?"),Rect2(490,465,185,43),show_map,true)
	focus_first()

func show_credits():
	stop_arena()
	screen = "credits"
	clear_ui()
	label_at("KELLY JELLY",Rect2(100,55,760,60),44,JellyArt.CREAM,true)
	label_at("S W E E T   R I C O C H E T",Rect2(100,120,760,35),20,Color("f49ebd"),true)
	var body = tr2("Игра из одного задания\n\nИдея и продюсирование — автор челленджа\nДизайн, код, интерфейс и оригинальная музыка — Codex\nПерсонажи — PixelLab, анимация и оформление — Codex\nДвижок — Godot Engine (MIT)\n\nНикаких желешек при разработке не пострадало.\nОни просто стали немного шире.","A game from one brief\n\nIdea and production — the challenge creator\nDesign, code, interface & original music — Codex\nCharacters — PixelLab; animation & scenery — Codex\nEngine — Godot Engine (MIT)\n\nNo jellies were harmed in the making of this game.\nThey just got a little wider.")
	label_at(body,Rect2(90,180,780,260),18,Color("ccb6c8"),true)
	button(tr2("В меню","Main menu"),Rect2(355,460,250,44),show_menu,true)
	focus_first()

func show_help(back: String):
	screen = "help"
	clear_ui()
	box(Rect2(100,50,760,440))
	label_at(tr2("МЯГКАЯ СНАРУЖИ. МОЩНАЯ ВНУТРИ.","SOFT OUTSIDE. POWER INSIDE."),Rect2(120,70,720,40),25,JellyArt.CREAM,true)
	var body = tr2("WASD / стрелки — движение. Мышь — прицел.\nУдерживай ЛКМ: сожмись. Отпусти: выстрели собой!\nПКМ / Пробел — бесплатный толчок. Esc — пауза.\n\nГеймпад: левый стик — ходьба, правый — прицел.\nRT — заряд и рывок, A — толчок, Start — пауза.\n\nСладости растят Келли. Рывок оставляет капли массы.\nСобери их снова! Оглушённых врагов можно поглотить.\nСталкивай врагов друг с другом: цепочка умножает очки.\nБоссов бей, когда они устали и над ними кружатся звёзды.","WASD / arrows move. Mouse aims.\nHold left mouse: squash. Release: launch yourself!\nRight mouse / Space: free push. Esc: pause.\n\nController: left stick moves, right stick aims.\nRT charges and dashes. A pushes. Start pauses.\n\nSweets grow Kelly. Dashing leaves drops of your mass.\nPick them up again! Absorb stunned enemies on contact.\nKnock enemies into each other to multiply your score.\nHit bosses while they rest with stars above their heads.")
	label_at(body,Rect2(145,130,680,270),17,Color("d6bfce"))
	button(tr2("Пройти обучение","Play tutorial"),Rect2(150,426,310,42),func(): start_level(0,true))
	button(tr2("Назад","Back"),Rect2(490,426,310,42),func():
		if back=="pause": show_pause()
		else: show_menu(),true)
	focus_first()

func show_settings(back: String):
	settings_return = back
	screen = "settings"
	clear_ui()
	box(Rect2(60,25,840,490),Color(.15,.10,.19,.98))
	label_at(tr2("НАСТРОЙКИ РЕЦЕПТА","RECIPE SETTINGS"),Rect2(90,40,760,40),28)
	button("RU / EN",Rect2(720,43,145,34),func(): profile.data.lang="en" if profile.data.lang=="ru" else "ru";profile.save();show_settings(back))
	var names = [tr2("Общая громкость","Master volume"),tr2("Музыка","Music"),tr2("Эффекты","Sound effects"),tr2("Тряска камеры","Camera shake")]
	var keys = ["master","music","sfx","shake"]
	for i in 4:
		label_at(names[i],Rect2(90,100+i*49,200,25),16)
		var slider = HSlider.new()
		slider.position = Vector2(300,104+i*49)
		slider.size = Vector2(215,22)
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = profile.data[keys[i]]
		slider.value_changed.connect(func(value): profile.data[keys[i]]=value;sound.update_volume();profile.save())
		ui.add_child(slider)
	var toggles = [["flashes",tr2("Вспышки","Flashes")],["assist",tr2("Помощь: блок каждого 2-го удара","Assist: block every second hit")],["aim_help",tr2("Помощь в прицеливании","Aim assistance")],["fullscreen",tr2("Полный экран","Fullscreen")],["vsync","VSync"]]
	for i in toggles.size():
		var key: String = toggles[i][0]
		button(toggles[i][1]+": "+("✓" if profile.data[key] else "—"),Rect2(555,100+i*42,310,34),func(): profile.data[key]=not profile.data[key];profile.save();apply_display();show_settings(back))
	button(tr2("Окно: ","Window: ")+["1440 × 810","1280 × 720","1920 × 1080"][profile.data.resolution],Rect2(90,307,425,36),func(): profile.data.resolution=(profile.data.resolution+1)%3;profile.save();apply_display();show_settings(back))
	label_at(tr2("ПЕРЕНАЗНАЧЕНИЕ КЛАВИШ","KEY BINDINGS"),Rect2(90,359,500,25),13,Color("a7ddc9"))
	var actions = ["left","right","up","down","push","dash","pause"]
	var labels = ["←","→","↑","↓",tr2("Толчок","Push"),tr2("Рывок","Dash"),"Ⅱ"]
	for i in actions.size():
		var act: String = actions[i]
		button(labels[i],Rect2(90+i*111,391,101,33),func(): binding_wait=act;binding_label.text=tr2("Нажми новую клавишу. Esc — отмена.","Press a new key. Esc cancels."))
	binding_label = label_at(tr2("Мышь и геймпад остаются доступны при переназначении.","Mouse and controller remain available when rebinding."),Rect2(90,432,600,25),13,Color("bda6bb"))
	button(tr2("Сброс клавиш","Reset keys"),Rect2(90,470,220,32),func(): profile.data.bindings={};profile.save();setup_inputs();show_settings(back))
	button(tr2("Готово","Done"),Rect2(655,464,210,38),func():
		binding_wait=""
		if back=="pause": show_pause()
		else: show_menu(),true)
	focus_first()

func _input(event):
	if binding_wait != "" and event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_ESCAPE:
			binding_wait=""
			return
		for action in ["left","right","up","down","push","dash","pause"]:
			if action==binding_wait: continue
			for binding in InputMap.action_get_events(action):
				if binding is InputEventKey and binding.physical_keycode==event.physical_keycode:
					binding_label.text=tr2("Клавиша занята: ","Key already bound: ")+action
					get_viewport().set_input_as_handled()
					return
		profile.data.bindings[binding_wait]=event.physical_keycode
		profile.save()
		setup_inputs()
		binding_wait=""
		binding_label.text=tr2("Сохранено","Saved")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value)>.3):
		gamepad=true
		joy_device=event.device
	elif event is InputEventMouseMotion or event is InputEventKey: gamepad=false
	if is_instance_valid(arena):
		arena.gamepad=gamepad
		arena.joy_device=joy_device
	if event.is_action_pressed("pause"):
		if screen=="play": show_pause()
		elif screen=="pause": resume()
		elif screen=="settings":
			if settings_return=="pause": show_pause()
			else: show_menu()
		elif screen in ["help","credits","map"]: show_menu()
		get_viewport().set_input_as_handled()
	if screen=="play" and is_instance_valid(arena):
		if event.is_action_pressed("dash"): arena.begin_charge()
		if event.is_action_released("dash"): arena.release_dash()
		if event.is_action_pressed("push"): arena.push()
		if event is InputEventKey and event.pressed and event.keycode==KEY_F12: capture("manual")

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen=="play" and not smoke and capture_mode=="": show_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func quit_game():
	if quitting: return
	quitting = true
	sound.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _process(dt: float):
	clock += dt
	queue_redraw()
	if is_instance_valid(arena):
		arena.position = Vector2(sin(clock*95),cos(clock*81))*arena.shake*profile.data.shake if profile.data.shake>0 else Vector2.ZERO
	if screen=="play" and is_instance_valid(arena) and is_instance_valid(hud_label):
		hud_label.text = "♥".repeat(maxi(0,arena.hp))+"♡".repeat(maxi(0,arena.max_hp-arena.hp))
		mass_label.text = tr2("МАССА  ","MASS  ")+str(int(arena.mass))+" / 100"+("   ◈" if arena.shield else "")
		status_label.text = GameData.LEVELS[arena.level][profile.data.lang]
		time_label.text = tr2("ВОЛНА ","WAVE ")+str(maxi(1,arena.wave+1))+" / 3    ·    "+str(arena.score)+"    ·    "+str(int(arena.elapsed)/60)+":"+str(int(arena.elapsed)%60).pad_zeros(2)
		banner_label.text = arena.banner if arena.banner_time>0 else ""
		boss_label.text = ""
		for e in arena.enemies:
			if e.kind>=5 and e.hp>0: boss_label.text = (GameData.NAMES_RU if profile.data.lang=="ru" else GameData.NAMES_EN)[e.kind]+"   "+str(e.hp)+" / "+str(e.max_hp)
	if capture_mode!="":
		capture_clock += dt
		if capture_clock > (2.6 if capture_mode in ["arena","boss"] else 0.8):
			var which = capture_mode
			capture_mode=""
			capture(which)
			get_tree().create_timer(.4).timeout.connect(quit_game)
	if smoke:
		smoke_clock += dt
		if smoke_clock > 1000:
			print("BOT_TIMEOUT")
			get_tree().quit(2)

func capture(which: String):
	var image = get_viewport().get_texture().get_image()
	var directory = "res://docs/screenshots" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()+"/screenshots"
	DirAccess.make_dir_recursive_absolute(directory)
	image.save_png(directory+"/"+which+capture_tag+".png")
	print("SCREENSHOT ",which)

func _draw():
	if not art or not profile: return
	if screen=="menu": art.draw_menu(self,clock,profile.data.skin)
	elif not is_instance_valid(arena): art.backdrop(self,clock)
	if screen=="final":
		for i in 55:
			var p = Vector2(fmod(i*137.7,960),145+fmod(i*73.2+clock*18,200))
			art.star(self,p,3+i%3,[JellyArt.PINK,JellyArt.CREAM,Color("9de2c5")][i%3])
		art.kelly(self,Vector2(480,330),180,clock,"victory",Vector2.RIGHT,3)
		for i in 3: art.sprite(self,["pudding","rolling","whisk"][i],Vector2(230+i*250,340),Vector2(74,74),sin(clock*2+i)*.1)
	if false and screen=="play" and is_instance_valid(arena):
		if arena.chain>1: art.centered(self,Vector2(785,66),"×"+str(mini(4,arena.chain))+"  "+tr2("ЦЕПОЧКА","CHAIN"),19,Color("e5c58a"))
		var hint = tr2("WASD  ходьба     ЛКМ  заряд → рывок     ПКМ / Пробел  толчок", "WASD  move     LMB  charge → dash     RMB / Space  push")
		if gamepad: hint = tr2("L  ходьба     R  прицел     RT  заряд → рывок     A  толчок", "L  move     R  aim     RT  charge → dash     A  push")
		if arena.tutorial>=0:
			var ru = ["Подвигайся: WASD или стрелки","Подбери сладость — Келли станет больше","Зажми ЛКМ, прицелься и отпусти! Стены отражают рывок.","Нажми ПКМ / Пробел: бесплатный толчок. Оглушённых съешь!"]
			var en = ["Move around with WASD or arrows","Pick up a sweet — Kelly will grow","Hold LMB, aim, release! Walls reflect your dash.","Press RMB / Space for a free push. Absorb stunned foes!"]
			hint = (ru if profile.data.lang=="ru" else en)[arena.tutorial]
		art.text(self,Vector2(50,519),hint,14,Color("cdb7c9"))
		if profile.data.assist: art.text(self,Vector2(765,86),tr2("ПОМОЩЬ ВКЛ.","ASSIST ON"),11,Color("a7ddc9"))
