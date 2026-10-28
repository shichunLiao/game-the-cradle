shader_type canvas_item;
// canvas_post_corrosion_haze —— 坑口·下行关「蚀的恍惚」全屏后处理(The Cradle,2026-10-11)。
// 重影 + 轻微水波 + 往紫黑里压的暗角。strength 0 = 原样,1 = 最重。
// 由 corrosion_haze.gd 驱动;strength 为 0 时节点隐藏,不跑这个着色器。
// 目标:Forward+(project.godot)。全屏两次屏幕采样、无循环无分支;只在恍惚的 1~3 秒里跑。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
group_uniforms drive;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float time_s = 0.0;
group_uniforms look;
uniform vec4 tint : source_color = vec4(0.10, 0.06, 0.16, 1.0);
// 重影错开多少(屏幕宽度的比例)
uniform float ghost_offset : hint_range(0.0, 0.05) = 0.014;
// 水波幅度(屏幕宽度的比例)
uniform float wave_amp : hint_range(0.0, 0.02) = 0.003;
// 水波沿屏幕竖直方向的频率、随时间的速度
uniform float wave_freq = 22.0;
uniform float wave_speed = 2.6;
// 最重时的模糊(mip 级)
uniform float max_blur_lod : hint_range(0.0, 3.0) = 0.55;
// 暗角从离中心多远开始、到多远压满
uniform float vignette_start : hint_range(0.0, 1.0) = 0.22;
uniform float vignette_end : hint_range(0.0, 1.0) = 0.72;
group_uniforms;

void fragment() {
	vec2 uv = SCREEN_UV;
	float s = clamp(strength, 0.0, 1.0);
	float wave = sin(uv.y * wave_freq + time_s * wave_speed) * wave_amp * s;
	float lod = max_blur_lod * s;
	vec3 a = textureLod(screen_tex, uv + vec2(wave, 0.0), lod).rgb;
	vec3 b = textureLod(screen_tex, uv + vec2(wave + ghost_offset * s * (0.6 + 0.4 * sin(time_s * 1.7)), 0.0), lod).rgb;
	vec3 col = mix(a, 0.5 * (a + b) + 0.25 * max(b - a, vec3(0.0)), 0.8 * s);
	// 去色、往紫里偏
	float l = dot(col, vec3(0.30, 0.59, 0.11));
	col = mix(col, vec3(l) * (vec3(0.7) + tint.rgb * 2.0), 0.35 * s);
	// 暗角:边上压成紫黑
	float d = distance(uv, vec2(0.5));
	float v = smoothstep(vignette_start, vignette_end, d);
	col = mix(col, tint.rgb * 0.4, v * 0.85 * s);
	COLOR = vec4(col, 1.0);
}
