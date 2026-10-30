shader_type spatial;
render_mode unshaded, cull_front;
uniform float width=0.012;
void vertex(){VERTEX+=NORMAL*width;}
void fragment(){ALBEDO=vec3(0.07,0.12,0.15);}
