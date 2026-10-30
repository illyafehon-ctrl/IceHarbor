shader_type spatial;
render_mode diffuse_lambert_wrap;
void fragment(){
 float diagonal=UV.x+UV.y*0.6;
 float shine=smoothstep(0.55,0.59,diagonal)*(1.0-smoothstep(0.72,0.76,diagonal));
 ALBEDO=mix(vec3(0.31,0.61,0.66),vec3(0.72,0.89,0.86),shine*0.55+UV.y*0.12);
 ROUGHNESS=0.35;
 SPECULAR=0.3;
}
