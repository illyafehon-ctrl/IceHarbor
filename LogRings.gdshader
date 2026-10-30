shader_type spatial;
render_mode diffuse_lambert_wrap;
void fragment(){
 float rings=smoothstep(0.65,0.9,sin(length(UV-vec2(0.5))*62.0));
 ALBEDO=mix(vec3(0.87,0.65,0.40),vec3(0.65,0.42,0.22),rings*0.35);
 ROUGHNESS=0.9;
}
