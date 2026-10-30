shader_type spatial;
render_mode diffuse_burley, cull_disabled;
varying float blade_height;
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 blade_height=VERTEX.y;
 VERTEX.x+=sin(TIME*1.5+world.x*0.7+world.z)*VERTEX.y*0.25;
 VERTEX.z+=sin(TIME*0.9+world.z)*VERTEX.y*0.12;
}
void fragment(){ALBEDO=COLOR.rgb*mix(0.75,1.1,smoothstep(0.0,0.3,blade_height));ROUGHNESS=0.95;}
