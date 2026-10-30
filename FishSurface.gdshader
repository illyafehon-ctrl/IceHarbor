shader_type spatial;
render_mode diffuse_lambert_wrap, cull_disabled;
uniform vec4 body_color : source_color=vec4(0.4,0.75,0.85,1.0);
uniform vec4 belly_color : source_color=vec4(0.95,0.94,0.78,1.0);
uniform float markings=0.0;
varying vec3 fish_local;
void vertex(){fish_local=VERTEX;}
void fragment(){
 float belly=1.0-smoothstep(-0.04,0.12,fish_local.y);
 vec3 color=mix(body_color.rgb,belly_color.rgb,belly);
 float stripe=smoothstep(0.65,0.85,sin(fish_local.x*25.0))*smoothstep(0.02,0.15,fish_local.y);
 vec2 scales=vec2(fish_local.x*35.0,fish_local.z*28.0);
 scales.x+=mod(floor(scales.y),2.0)*0.5;
 float scale_edge=smoothstep(0.30,0.48,length(fract(scales)-vec2(0.5)));
 float gill=(1.0-smoothstep(0.012,0.025,abs(fish_local.x-0.36)))*smoothstep(0.04,0.13,abs(fish_local.z));
 ALBEDO=color*(1.0-stripe*markings*0.18-scale_edge*0.055-gill*0.22);
 ROUGHNESS=0.48;
 SPECULAR=0.35;
}
