class_name JellyMeter
extends Control

var value=0.0:
	set(v): value=v;queue_redraw()
var max_value=100.0:
	set(v): max_value=maxf(.001,v);queue_redraw()
var color=Color("74d9ef")

func _draw():
	paint(self,Rect2(Vector2.ZERO,size),value,max_value,color)

static func paint(canvas:CanvasItem,rect:Rect2,current:float,maximum:float,fill_color:Color):
	var track=StyleBoxFlat.new()
	track.bg_color=Color("382c40")
	track.set_corner_radius_all(int(rect.size.y*.5))
	track.anti_aliasing=true
	canvas.draw_style_box(track,rect)
	var width=rect.size.x*clampf(current/maxf(.001,maximum),0,1)
	if width<=0: return
	var fill=StyleBoxFlat.new()
	fill.bg_color=fill_color
	fill.set_corner_radius_all(int(minf(width,rect.size.y)*.5))
	fill.anti_aliasing=true
	canvas.draw_style_box(fill,Rect2(rect.position,Vector2(width,rect.size.y)))
	if rect.size.y>=8 and width>=8:
		var shine=StyleBoxFlat.new();shine.bg_color=Color(1,1,1,.22);shine.set_corner_radius_all(2)
		canvas.draw_style_box(shine,Rect2(rect.position+Vector2(3,2),Vector2(width-6,2)))
