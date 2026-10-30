shader_type spatial;
render_mode diffuse_lambert_wrap;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
void fragment(){
 float grain=sin(local_pos.x*19.0+sin(local_pos.z*8.0)*1.2);
 float streak=smoothstep(0.75,1.0,grain);
 ALBEDO=mix(vec3(0.66,0.36,0.16),vec3(0.80,0.51,0.25),0.65-streak*0.28);
 ROUGHNESS=0.86;
}
