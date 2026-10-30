shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D ice_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool low_detail=false;
uniform float variation=0.0;
uniform float damage : hint_range(0.0,1.0)=0.0;
uniform float impact : hint_range(0.0,1.0)=0.0;
// Three fixed fracture origins. Damage extends existing cracks without rerolling them.
float fracture(vec2 uv,vec2 origin,float reach,float branches,float phase){
 vec2 p=uv-origin;
 float radius=length(p);
 float angle=atan(p.y,p.x);
 float jag=sin(radius*27.0+phase)*0.12+sin(radius*53.0)*0.035;
 float ray=abs(sin(angle*branches+jag+phase))*max(radius,0.025);
 float extent=1.0-smoothstep(reach,reach+0.06,radius);
 return (1.0-smoothstep(0.004,0.014,ray))*extent;
}
void fragment(){
 vec3 detail=texture(ice_texture,vec2(0.52,0.02)+UV*0.46).rgb;
 float progress=pow(clamp(damage,0.0,1.0),0.65);
 float first=fracture(UV,vec2(0.44,0.54),progress*0.9,3.0,0.2)*smoothstep(0.0,0.035,damage);
 float second=low_detail ? 0.0 : fracture(UV,vec2(0.76,0.28),max(0.0,progress-0.18)*0.8,4.0,0.75)*smoothstep(0.12,0.38,damage);
 float third=low_detail ? 0.0 : fracture(UV,vec2(0.22,0.22),max(0.0,progress-0.4)*1.1,3.0,1.4)*smoothstep(0.35,0.7,damage);
 float crack=max(first,max(second,third));
 float edge=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
 float frost=(1.0-smoothstep(0.015,0.16,edge))*(0.88+0.12*sin(UV.x*31.0+UV.y*17.0));
 float bubble=1.0-smoothstep(0.03,0.09,length(fract(UV*vec2(7.0,9.0)+vec2(sin(floor(UV.y*9.0)*7.1),cos(floor(UV.x*7.0)*5.3))*0.28)-vec2(0.5)));
 float sheen=pow(max(0.0,1.0-abs(UV.x+UV.y*0.5-0.8)*6.0),6.0);
 float rim=pow(1.0-abs(dot(NORMAL,VIEW)),2.0);
 float grain=smoothstep(0.66,0.92,detail.r)*0.16;
 float strata=sin(UV.y*35.0+sin(UV.x*12.0+variation)*0.8);
 float trapped=low_detail ? 0.0 : (1.0-smoothstep(0.02,0.07,length(fract(UV*vec2(13.0,17.0)+variation)-vec2(0.5))))*0.06;
 float facets=abs(sin(UV.x*8.0+UV.y*5.0+variation));
 vec3 normal_detail=vec3(sin(UV.x*18.0+variation)*0.018,cos(UV.y*21.0)*0.018,1.0);
 if(!low_detail)NORMAL_MAP=normal_detail*0.5+0.5;
 float plates=abs(sin(UV.x*15.0+UV.y*9.0));
 float shards=(1.0-smoothstep(0.025,0.10,plates))*smoothstep(0.65,1.0,damage);
 vec3 blue=mix(vec3(0.18,0.61,0.77)*(0.94+facets*0.06),vec3(0.73,0.91,0.96),frost*0.65+rim*0.3);
 ALBEDO=mix(blue,vec3(0.93,0.99,1.0),clamp(crack*0.96+grain+shards*0.6+bubble*0.09+sheen*0.1+trapped+max(0.0,strata)*0.018,0.0,1.0));
 ALPHA=clamp(0.24+bubble*0.06+sheen*0.07+frost*0.22+rim*0.12+grain+crack*0.68+shards*0.25,0.0,0.94);
 ROUGHNESS=0.18+frost*0.22+crack*0.2;
 SPECULAR=0.6;
 EMISSION=vec3(0.12,0.19,0.2)*crack*(0.15+impact*0.8);
}
