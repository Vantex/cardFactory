// shaders/particle_flow.gdshader
shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float particle_size : hint_range(0.01, 0.5) = 0.1;
uniform vec4 particle_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float flow_direction : hint_range(-1.0, 1.0) = 1.0;

void fragment() {
    vec2 uv = UV;
    float progress = fract(uv.x * flow_direction - TIME * speed);
    float particle = smoothstep(1.0 - particle_size, 1.0, progress);
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = mix(tex_color, particle_color, particle * tex_color.a);
}
