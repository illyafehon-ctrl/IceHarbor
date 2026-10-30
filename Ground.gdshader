shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform sampler2D terrain_atlas : source_color, filter_linear_mipmap;
uniform vec4 base_tint : source_color = vec4(0.85,0.7,0.5,1.0);
uniform float zone_origin=0.0;
uniform float grass_amount=0.3;
uniform float snow_amount=0.4;
uniform float owned=1.0;
varying vec3 ground_position;
void vertex(){ground_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=ground_position.xz;
 float z=p.y-zone_origin;
 float bank=mix(-0.5,-3.0,smoothstep(3.2,3.7,z));
 float edge=min(min(p.x-bank,10.5-p.x),min(z+7.0,13.0-z));
 float broad=sin(p.x*0.65+sin(p.y*0.3))+sin(p.y*0.55)*0.5;
 vec2 quadrant=vec2(1.0,1.0);
 if(edge<0.7+snow_amount*0.25)quadrant=vec2(0.0,0.0);
 else if(edge<1.7 && broad<-1.0+grass_amount)quadrant=vec2(0.0,1.0);
 else if(edge<1.4 && broad>0.9)quadrant=vec2(1.0,0.0);
 vec2 tile_uv=abs(fract(p*0.09)*2.0-1.0);
 vec3 color=texture(terrain_atlas,quadrant*0.5+vec2(0.02)+tile_uv*0.46).rgb;
 if(quadrant==vec2(1.0,1.0))color=mix(color,base_tint.rgb,0.72);
 float mottling=sin(p.x*2.7+sin(p.y*1.9))*sin(p.y*3.1);
 color*=1.0+mottling*0.025;
 ALBEDO=mix(color*0.7,color,owned);
 ROUGHNESS=0.9;
 SPECULAR=0.12;
}
