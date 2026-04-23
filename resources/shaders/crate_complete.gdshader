// crate_complete.gdshader
// 用于推箱归位时的视觉反馈。
// - complete: 0.0 = 原始外观；1.0 = 完成态
// - 完成态在原始贴图上叠加绿色调、轻微提亮，并通过 alpha 边缘做柔和外发光（脉冲）
// - 不修改原贴图 alpha 形状，仅在像素颜色域处理
shader_type canvas_item;

uniform float complete : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.35, 0.85, 0.45, 1.0); // 完成绿
uniform float tint_strength : hint_range(0.0, 1.0) = 0.55;
uniform float brightness_boost : hint_range(0.0, 1.0) = 0.18;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.5;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base_rgb = tex.rgb;

	// 完成态颜色处理：先按 tint_strength 在原色和绿色之间混合，再加亮度
	vec3 tinted = mix(base_rgb, base_rgb * tint_color.rgb, tint_strength);
	tinted += brightness_boost;

	// 脉冲（柔和呼吸）
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	tinted += vec3(pulse * pulse_amount) * complete;

	vec3 final_rgb = mix(base_rgb, tinted, complete);
	COLOR = vec4(final_rgb, tex.a);
}
