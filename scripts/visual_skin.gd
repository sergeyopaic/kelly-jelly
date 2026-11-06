class_name VisualSkin
extends RefCounted

var body:Font
var heading:Font
var panel_texture:Texture2D
var button_texture:Texture2D
var icons:Array[Texture2D]=[]
var menu:Texture2D

func _init():
	var variation=FontVariation.new()
	variation.base_font=load("res://assets/fonts/Nunito.ttf")
	# Godot expects the numeric OpenType axis tag, not a string key.
	variation.variation_opentype={2003265652:750.0}
	body=variation
	heading=load("res://assets/fonts/LilitaOne-Regular.ttf")
	panel_texture=load("res://assets/visuals/panel.png")
	button_texture=load("res://assets/visuals/button.png")
	menu=load("res://assets/visuals/menu.png")
	for i in 16: icons.append(load("res://assets/visuals/icons_%d.png"%i))
	for i in 3: icons.append(load("res://assets/emotions/sprint_icon_%d.png"%i))

func hud_style() -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=Color(.105,.075,.14,.88)
	style.border_color=Color(1,.85,.93,.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.anti_aliasing=true
	return style

func style_slider(slider:HSlider):
	for state in ["slider","grabber_area","grabber_area_highlight"]:
		var style=StyleBoxFlat.new()
		style.bg_color=Color("332937") if state=="slider" else Color("c57da0")
		style.set_corner_radius_all(3)
		style.content_margin_top=3;style.content_margin_bottom=3
		slider.add_theme_stylebox_override(state,style)
	var knob=load("res://assets/ui/slider_knob.svg")
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		slider.add_theme_icon_override(state,knob)
	slider.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func panel_style() -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=Color("3a273c");style.border_color=Color("d1a18e")
	style.set_border_width_all(2);style.set_corner_radius_all(20)
	style.corner_radius_top_left=8;style.corner_radius_bottom_right=8
	style.shadow_color=Color("201728",.55);style.shadow_size=5;style.shadow_offset=Vector2(0,6)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_content_margin(side,12)
	return style

func button_style(state:String,primary:bool) -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=Color("e792af") if primary else Color("5a3e54")
	style.border_color=Color("ffd9d2") if primary else Color("b48699")
	style.set_border_width_all(2);style.set_corner_radius_all(13)
	style.corner_radius_top_left=18;style.corner_radius_bottom_right=18
	style.shadow_color=Color("713c58") if primary else Color("271e30")
	style.shadow_size=1;style.shadow_offset=Vector2(0,4)
	if state=="hover": style.bg_color=Color("f3abc1") if primary else Color("74516a")
	if state=="focus":
		style.bg_color=Color.TRANSPARENT;style.border_color=Color("fff0bd")
		style.shadow_size=0;style.shadow_color=Color.TRANSPARENT
	if state=="pressed":
		style.bg_color=Color("cb7396") if primary else Color("483248")
		style.shadow_offset=Vector2(0,1)
	if state=="disabled": style.bg_color=Color("4e404f");style.border_color=Color("756271")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_content_margin(side,6)
	return style

func add_button_fill(button:Button,primary:bool):
	# A subtle icing highlight belongs to the button, so it follows resizing.
	var glint=ColorRect.new();glint.color=Color(1,.9,.8,.18 if primary else .07)
	glint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	glint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	glint.offset_left=18;glint.offset_right=-18;glint.offset_top=5;glint.offset_bottom=6
	button.add_child(glint)

func icon_rect(index:int,rect:Rect2,parent:Control) -> TextureRect:
	var icon=TextureRect.new()
	icon.texture=icons[index]
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position=rect.position;icon.size=rect.size
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon
