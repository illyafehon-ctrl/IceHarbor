shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform vec4 tint : source_color=vec4(0.45,0.65,0.57,1);
void fragment(){
 float seam=smoothstep(0.91,0.98,fract(UV.y*9.0));
 float grain=sin(UV.x*57.0+sin(UV.y*18.0)*2.0)*0.018;
 ALBEDO=tint.rgb*(1.0-seam*0.18)+grain;
 ROUGHNESS=0.85;
}
