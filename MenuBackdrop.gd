extends Control
var time := 0.0
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(delta: float) -> void:
 if not is_visible_in_tree():return
 time+=minf(delta,0.1)
 queue_redraw()
func _draw() -> void:
 var w := size.x
 var h := size.y
 for i in range(64):
  var t := float(i)/63
  draw_rect(Rect2(0,h*t,w,h/63+1),Color("0b2739").lerp(Color("48838b"),t))
 for ridge in range(3):
  var points := PackedVector2Array([Vector2(0,h),Vector2(0,h*(0.45+ridge*0.1))])
  for i in range(13):
   points.append(Vector2(float(i)*w/12,h*(0.40+ridge*0.12)-sin(i*1.7+ridge)*h*0.10))
  points.append(Vector2(w,h))
  draw_colored_polygon(points,[Color("345d70"),Color("668c99"),Color("a1bbc3")][ridge])
 var river := PackedVector2Array([Vector2(w*0.52,h*0.57),Vector2(w*0.68,h*0.57),Vector2(w*0.78,h*0.75),Vector2(w*0.46,h),Vector2(0,h),Vector2(w*0.50,h*0.76)])
 draw_colored_polygon(river,Color("27677b"))
 for i in range(20):
  var z := fmod(float(i)*0.057+time*0.018,1.0)
  var y := h*(0.60+z*0.4)
  var x := w*(0.6-z*0.28)+sin(i*4.0)*w*0.09
  draw_line(Vector2(x,y),Vector2(x+12+z*30,y),Color(0.65,0.88,0.92,0.16),2,true)
 for i in range(18):
  var x := fmod(float(i)*w*0.177,w)
  var y := h*(0.77+fmod(i*0.137,0.2))
  if x>w*0.27 and x<w*0.66:continue
  var tall := 38.0+fmod(i*27.0,60.0)
  var sway := sin(time*0.9+i)*3
  draw_rect(Rect2(x-2,y-tall*0.3,4,tall*0.4),Color("3e6569"))
  for tier in range(3):
   var top := Vector2(x+sway,y-tall+float(tier)*tall*0.2)
   var half := tall*(0.25-float(tier)*0.035)
   draw_colored_polygon(PackedVector2Array([top,top+Vector2(-half,tall*0.55),top+Vector2(half,tall*0.55)]),Color("d5e6e5") if tier%2==0 else Color("bdd7d8"))
 for i in range(65):
  var x := fmod(i*79.0+time*(10+float(i%3)*6),w+20)-10
  var y := fmod(i*137.0+time*(15+float(i%5)*4),h+20)-10
  draw_circle(Vector2(x,y),1+float(i%3)*0.6,Color(0.95,0.99,1.0,0.25+float(i%4)*0.12))
