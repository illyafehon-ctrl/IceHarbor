shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.18,0.37,0.34,1.0);
uniform bool textured = false;
uniform float strength = 0.19;
void vertex() {
 float phase=MODEL_MATRIX[3].x*0.31+MODEL_MATRIX[3].z*0.17;
 float gust=0.65+0.35*sin(TIME*0.43);
 float bend=sin(TIME*1.05+phase)*gust;
 float height=max(VERTEX.y+0.7,0.0);
 VERTEX.x+=bend*height*height*strength;
 VERTEX.z+=cos(TIME*0.8+phase)*height*strength*0.35;
}
void fragment() {
 ALBEDO=textured ? texture(surface_texture,UV).rgb : base_color.rgb;
 float needles=sin(UV.x*36.0+UV.y*12.0)*sin(UV.y*24.0);
 ALBEDO*=0.96+needles*0.04;
 ROUGHNESS=0.9;
}
