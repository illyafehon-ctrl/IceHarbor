extends Control
var item: Dictionary={}
func _ready() -> void:
 custom_minimum_size=Vector2(72,88)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
 if item.is_empty():return
 var ink := Color("142f3c")
 var color := Color(item.color)
 var trim := Color(item.trim)
 draw_style_box(card(),Rect2(Vector2.ZERO,size))
 var o := Vector2(size.x*0.5,46)
 var slot := str(item.slot)
 if slot=="hat":
  draw_circle(o+Vector2(0,-7),25,ink)
  draw_circle(o+Vector2(0,-9),22,color)
  draw_rect(Rect2(o+Vector2(-26,4),Vector2(52,13)),ink)
  draw_rect(Rect2(o+Vector2(-24,6),Vector2(48,9)),trim)
  if int(item.shape)==1:draw_circle(o+Vector2(0,-34),7,trim)
  if int(item.shape)==2:
   for side in [-1,1]:draw_rect(Rect2(o+Vector2(side*22-5,10),Vector2(10,18)),trim)
  if int(item.shape)==3:draw_rect(Rect2(o+Vector2(-20,16),Vector2(45,5)),color)
 elif slot=="coat":
  draw_colored_polygon(PackedVector2Array([o+Vector2(-16,-28),o+Vector2(-31,-13),o+Vector2(-27,18),o+Vector2(-17,15),o+Vector2(-18,31),o+Vector2(18,31),o+Vector2(17,15),o+Vector2(27,18),o+Vector2(31,-13),o+Vector2(16,-28)]),color)
  draw_line(o+Vector2(0,-23),o+Vector2(0,31),trim,3,true)
  draw_line(o+Vector2(-15,-25),o+Vector2(0,-14),trim,6,true)
  draw_line(o+Vector2(15,-25),o+Vector2(0,-14),trim,6,true)
  for side in [-1,1]:
   draw_rect(Rect2(o+Vector2(side*11-5,10),Vector2(10,8)),color.darkened(0.3))
   draw_line(o+Vector2(side*11-5,10),o+Vector2(side*11+5,10),trim,2)
 else:
  for x in [-17,13]:
   draw_rect(Rect2(o+Vector2(x-10,-24),Vector2(19,35)),color)
   draw_style_box(boot(color),Rect2(o+Vector2(x-10,0),Vector2(27,23)))
   draw_line(o+Vector2(x-10,24),o+Vector2(x+17,24),ink,5,true)
   for y in [-10,-3,4]:draw_line(o+Vector2(x-5,y),o+Vector2(x+5,y),trim,2,true)
func card() -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color=Color("203b47")
 style.set_corner_radius_all(13)
 return style
func boot(color: Color) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(7)
 return style
