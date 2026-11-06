class_name SweetHUD
extends Control

var kind="health"

func slab(rect:Rect2,color:Color,border:Color,radius:int=14):
	var style=StyleBoxFlat.new()
	style.bg_color=color;style.border_color=border
	style.set_border_width_all(2);style.set_corner_radius_all(radius)
	style.shadow_color=Color("271d32",.35);style.shadow_size=2;style.shadow_offset=Vector2(0,3)
	draw_style_box(style,rect)

func _draw():
	var cocoa=Color("3f2b40")
	var cream=Color("f3d9ba")
	if kind=="health":
		slab(Rect2(18,4,size.x-18,49),cocoa,Color("b77891"),18)
		slab(Rect2(0,0,54,54),Color("9e4b70"),Color("f3b1c3"),22)
		draw_line(Vector2(63,9),Vector2(size.x-20,9),Color("b97991",.35),1.5,true)
	elif kind=="growth":
		# Candy-wrapper folds frame the experience track, with a level seal above it.
		for flip in [-1,1]:
			var x=size.x*.5+flip*(size.x*.5-16)
			draw_colored_polygon(PackedVector2Array([Vector2(x,35),Vector2(x+flip*16,29),Vector2(x+flip*12,43),Vector2(x+flip*16,57),Vector2(x,53)]),Color("a6cebb"))
		slab(Rect2(12,31,size.x-24,25),cocoa,Color("bce3cf"),12)
		slab(Rect2(size.x*.5-61,0,122,34),Color("bce3cf"),cream,15)
		draw_circle(Vector2(size.x*.5-48,16),2,cocoa)
		draw_circle(Vector2(size.x*.5+48,16),2,cocoa)
	else:
		slab(Rect2(0,0,size.x,50),cocoa,cream,18)
		draw_line(Vector2(16,6),Vector2(size.x-16,6),Color("f3d9ba",.18),1.5,true)
