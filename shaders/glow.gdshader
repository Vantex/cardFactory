// shaders/glow.gdshader
shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec4 glow_color : source_color = vec4(0.0, 0.94, 1.0, 1.0);
uniform float time_scale : hint_range(0.1, 10.0) = 2.0;
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float glow = sin(TIME * time_scale * pulse_speed) * 0.5 + 0.5;
    vec4 final_color = mix(tex_color, glow_color, glow * glow_strength * tex_color.a);
    COLOR = final_color;
}
