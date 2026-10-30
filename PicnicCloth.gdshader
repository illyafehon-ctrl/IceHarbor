shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform vec4 tint : source_color=vec4(0.7,0.5,0.4,1);
void fragment(){
 vec2 tile=fract(UV*8.0);
 float stripe=max(1.0-smoothstep(0.10,0.18,tile.x),1.0-smoothstep(0.10,0.18,tile.y));
 ALBEDO=mix(tint.rgb,vec3(0.94,0.88,0.70),stripe*0.55);
 ROUGHNESS=0.94;
}
