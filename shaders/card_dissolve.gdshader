shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform float edge_width : hint_range(0.01, 0.25) = 0.10;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float n = noise(UV * 10.0) * 0.65 + noise(UV * 22.0) * 0.35;
	float threshold = progress * (1.0 + edge_width);
	if (n < threshold - edge_width) {
		discard;
	}
	float edge_mask = smoothstep(threshold - edge_width, threshold, n);
	vec3 col = mix(edge_color.rgb * 1.45, tex.rgb, edge_mask);
	float alpha = tex.a * (1.0 - smoothstep(0.86, 1.0, progress));
	COLOR = vec4(col, alpha);
}
