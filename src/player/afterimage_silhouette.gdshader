// 残影剪影:只取精灵的形状(alpha),颜色整片换成绘制时传进来的颜色。
// Celeste 的冲刺尾迹就是这样 —— 纯色剪影比半透明的原图干净,不会和本体抢细节。
shader_type canvas_item;

varying vec4 v_tint;

void vertex() {
	// draw_texture_rect_region() 的 modulate 走的是顶点色
	v_tint = COLOR;
}

void fragment() {
	COLOR = vec4(v_tint.rgb, texture(TEXTURE, UV).a * v_tint.a);
}
