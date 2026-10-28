shader_type canvas_item;
// 暗区的画法 —— The Cradle,2026-10-13 细致化(`design/ideas-backlog.md` H1,`ShadowZone` 用)。
// 目标:Forward+ / Compatibility 都能跑的 2D 画布着色器;每个像素只做几次比较和一次 4x4 查表,没有贴图采样。
//
// 第一版是一整块 82% 的墨色 + 虚线框 + 四角括号 —— 读得懂,但像调试框。现在:
//   - 中间是暗,但墙砖隐约透得出来(core_alpha 低一点);越靠地面越暗一点(bottom_extra);
//   - 边缘 edge_px 宽的一圈用 4x4 拜耳矩阵、三档抖点从亮过渡到暗(像素画的软边:抖点只用在交界);
//   - 和别的暗区相邻的那一边不软(soft.xyz = 左、右、上),免得一片连着的暗处中间出一道缝;
//   - floor_mode = 1 时画的是压在地板顶上的那一条(暗处脚下的地板也是暗的),由暗区的子节点画在实心块上面。
// 判定范围不变:规则仍然是整个矩形(`ShadowQuery`);最后的真相是 Ryn 自己变成剪影(`RynStealthVisual`)。

group_uniforms shape;
/** 暗区的尺寸,px(和 `ShadowZone.size` 一样)。 */
uniform vec2 size = vec2(64.0, 32.0);
/** 哪几边做软边:x 左、y 右、z 上(1 = 软,0 = 贴着别的暗区)。w 不用。 */
uniform vec4 soft = vec4(1.0, 1.0, 1.0, 0.0);
/** 0 = 暗区本身;1 = 压在地板顶上的那一条。 */
uniform int floor_mode : hint_range(0, 1) = 0;

group_uniforms look;
/** 暗的颜色(色板 ink-deep)。 */
uniform vec4 tint : source_color = vec4(0.043, 0.071, 0.125, 1.0);
/** 中间的暗有多深(0..1)。 */
uniform float core_alpha : hint_range(0.0, 1.0) = 0.64;
/** 越靠地面多暗多少(叠在 core_alpha 上)。 */
uniform float bottom_extra : hint_range(0.0, 0.5) = 0.12;
/** 边缘抖点渐暗的宽度,px。 */
uniform float edge_px : hint_range(1.0, 32.0) = 12.0;
/** 地板那一条有多厚,px。 */
uniform float floor_px : hint_range(1.0, 8.0) = 3.0;
/** 地板那一条最上面有多暗。 */
uniform float floor_alpha : hint_range(0.0, 1.0) = 0.5;
group_uniforms;

/** 不软的那一边用的「很远」,px。 */
const float FAR = 100000.0;
/** 抖点分几档。 */
const float LEVELS = 3.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

// 4x4 拜耳矩阵的阈值(0..1),按像素坐标循环。
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[x + y * 4] + 0.5) / 16.0;
}

// 0..1 的「有多暗」量化成三档抖点(0 → 1/3 → 2/3 → 全暗):每一档之间用拜耳阈值决定像素落哪一档。
// 第一版两档、6px 宽,在暗砖墙上几乎看不出过渡(2026-10-13 截图),改成三档、12px。
float dithered(float density, float full, vec2 p) {
	float level = clamp(density, 0.0, 1.0) * LEVELS;
	float base = floor(level);
	float up = step(bayer4(p), level - base);            // 这个像素要不要往上跳一档
	return full * min(base + up, LEVELS) / LEVELS;
}

void fragment() {
	vec2 p = floor(local);
	// 到三条软边的距离;不软的边算作「很远」
	float dl = mix(FAR, p.x, soft.x);
	float dr = mix(FAR, size.x - 1.0 - p.x, soft.y);
	float dt = mix(FAR, p.y, soft.z);
	// 暗区本身:三边渐暗,越往下越深
	float body_density = (min(min(dl, dr), dt) + 1.0) / edge_px;
	float body_full = core_alpha + bottom_extra * (p.y / max(size.y, 1.0));
	float body = dithered(body_density, body_full, p);
	// 地板那一条:左右跟着软边,从上往下淡掉
	float across = clamp((min(dl, dr) + 1.0) / edge_px, 0.0, 1.0);
	float down = 1.0 - p.y / max(floor_px, 1.0);
	float fl = dithered(across * down, floor_alpha, p);
	COLOR = vec4(tint.rgb, mix(body, fl, float(floor_mode)));
}
