shader_type spatial;
render_mode diffuse_burley;
varying vec3 water_position;
void vertex() {
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(world.z*1.7-TIME*1.5+sin(world.x))*0.023+sin(world.x*3.0+TIME*0.7)*0.008;
 water_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 float local_z=mod(water_position.z+15.0,30.0)-15.0;
 float island_shore=mix(-0.5,-3.0,step(3.5,local_z)*step(local_z,13.0));
 float shore_distance=min(abs(water_position.x+10.0),abs(water_position.x-island_shore));
 float edge=exp(-shore_distance*1.8);
 float flow_z=water_position.z-TIME*1.35;
 float wave=sin(flow_z*2.5+sin(water_position.x*1.2));
 float ripple=sin(flow_z*6.5+sin(water_position.x*3.1)*1.5);
 float ribbon=pow(max(0.0,sin(water_position.x*4.0+sin(flow_z*0.75)*0.35)),22.0);
 float streak=ribbon*smoothstep(0.35,0.85,sin(flow_z*1.2+water_position.x*2.0));
 float foam=smoothstep(0.82,1.0,edge)*(0.75+0.15*wave);
 ALBEDO=mix(vec3(0.06,0.47,0.66),vec3(0.36,0.80,0.87),pow(edge,3.0))+wave*0.022+ripple*0.006;
 ALBEDO=mix(ALBEDO,vec3(0.49,0.80,0.91),streak*0.19);
 ALBEDO=mix(ALBEDO,vec3(0.79,0.94,0.97),foam*0.7);
 float eddy=sin(flow_z*2.0+water_position.x*3.0);
 ALBEDO=mix(ALBEDO,vec3(0.62,0.89,0.91),smoothstep(0.96,1.0,eddy)*edge*0.12);
 NORMAL_MAP=normalize(vec3(cos(water_position.x+flow_z)*0.10,cos(flow_z*2.5)*0.13,1.0))*0.5+0.5;
 ROUGHNESS=0.48;
 SPECULAR=0.25;
}
