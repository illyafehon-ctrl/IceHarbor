shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform vec4 tint : source_color=vec4(0.7,0.8,0.7,1);
void fragment(){
 vec2 cell=UV*vec2(12.0,5.0);
 cell.x+=mod(floor(cell.y),2.0)*0.5;
 vec2 edge=fract(cell);
 float seam=max(smoothstep(0.94,0.99,edge.x),smoothstep(0.86,0.99,edge.y));
 ALBEDO=tint.rgb*(1.0-seam*0.14);
 ROUGHNESS=0.88;
}
