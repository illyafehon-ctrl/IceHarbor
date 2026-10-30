shader_type spatial;
render_mode diffuse_lambert_wrap;
void fragment(){
 float seam=smoothstep(0.90,0.98,fract(UV.x*12.0));
 float grain=sin(UV.y*28.0+UV.x*81.0)*0.022;
 ALBEDO=mix(vec3(0.66,0.43,0.23),vec3(0.40,0.27,0.16),seam)+grain;
 ROUGHNESS=0.88;
}
