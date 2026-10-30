shader_type spatial;
render_mode diffuse_lambert_wrap;
void fragment(){
 float fleck=step(0.76,fract(sin(dot(floor(UV*12.0),vec2(12.7,31.1)))*437.58));
 ALBEDO=mix(vec3(0.59,0.64,0.62),vec3(0.76,0.79,0.71),fleck*0.3);
 ROUGHNESS=0.95;
}
