class_name SkylineBackdrop
extends Node2D
## 塔外的夜景:破碎的大陆、四座发光的塔和中央高塔、地平线上坑口的紫光、贫民窟的屋顶。
##
## 2026-10-12 用户:「塔外的部分,让玩家感受游戏中的美景和艺术风格」。三处共用这一个节点:
##  - 贫民窟屋顶那一关的整片背景(`as_background = true`);
##  - 塔里墙上的破口 / 窗(`SkylineWindow` 把它裁成一块);
##  - 塔顶、坑口的远景镜头(镜头拉远时看到的就是它)。
##
## ## 颜色只用 美术规格.md 的色板
## 墨蓝夜空、钢蓝塔体、冷青环境光、紫雾(坑口的蚀)、锈红(精炼塔的灯)、惨白荧光(塔的窗)。
## 暖色(`ACCENT_WARM`)全图只有一处:远处贫民窟里旧屋的那扇窗 —— 规格:暖色只给照片、吊坠、旧屋、结局门口。
## 月亮是冷白的(用户 2026-10-12 要求加一轮月亮;不用暖色)。坑口的紫光按用户要求加强:
## 地平线一大团紫、附近的天带一点紫、一道往天上去的紫柱 —— 一路都在提醒终点在那儿。
##
## ## 视差
## 每层按「离镜头多远」跟镜头走:夜空和星星不动(无限远),大陆断崖 0.03,塔群 0.08,城 0.22,近处屋顶 0.45。
## 竖直方向:地平线永远在视线高度(画面的 `horizon` 处)—— 远处的大陆、塔群、坑口一直看得见;
## 往上爬,近处的城和屋顶往下沉(`climb_drop`),塔顶上就只剩远处的塔和天。
## (第一版让地平线跟着爬升往下沉,塔顶上窗里只剩天,看不见塔群和坑口 —— 2026-10-12 改。)
## 同一关里所有实例按同一个 `level_rect` 算,所以每扇窗看出去是同一片连续的景。
##
## ## 一次生成,之后只画贴图
## 和 `TowerBackdrop` 一样:各层剪影在 `_ready` 生成 `ImageTexture`(同一关同一种子只生成一次,静态缓存),
## 每帧只画贴图,再加几样会动的:星星闪、坑口紫光呼吸、军事塔的探照灯扫天、精炼塔冒的烟。
##
## Usage (in a scene): 放在关卡根下,设 `level_rect`(整关的世界矩形)。当窗里的景时 `as_background = false`,
## 作为 `SkylineWindow` 的子节点(那边会自动建好)。

const INK_DEEP: Color = Color("0B1220")
const STEEL_BLUE: Color = Color("1A2A44")
const COLD_CYAN: Color = Color("3D6B8A")
const VIOLET_HAZE: Color = Color("4A3F6B")
const RUST_RED: Color = Color("8B3A2F")
const TOWER_WHITE: Color = Color("C8D4E0")
const SLIME_BLACK: Color = Color("121018")
const ACCENT_WARM: Color = Color("C4A574")

## 视差系数(0 = 无限远,1 = 和世界一起)。
const P_CLIFFS: float = 0.03
const P_TOWERS: float = 0.08
const P_CITY: float = 0.22
const P_NEAR: float = 0.45
## 镜头最大可视宽度(拉远到 zoom 1 时 1280 世界像素),贴图按它留余量。
const VIEW_W_MAX: float = 1400.0
## 塔群在全景里的位置(0..1)和高度:出生地、精炼、登记、军事、中央(坑口上方)。
const TOWER_U: Array[float] = [0.13, 0.30, 0.46, 0.62, 0.80]
const TOWER_H: Array[int] = [168, 190, 180, 200, 250]
const CRATER_U: float = 0.80

## 当整关背景用(z = -100,和 `TowerBackdrop` 同层);false = 在窗里(跟窗的 z 走)。
@export var as_background: bool = true
## 整关的世界矩形。视差按它算。
@export var level_rect: Rect2 = Rect2(0, 0, 1920, 1080)
@export var seed_value: int = 7
## 地平线在画面高度的哪里(0 = 顶,1 = 底)。
@export_range(0.0, 1.0) var horizon: float = 0.62
## 往上爬一像素,近处的城往下沉多少像素(最近的屋顶沉得更多)。
@export var climb_drop: float = 0.06
## 全景转多少(0..1):塔群和坑口在全景里的位置整体平移、绕回。让「要去的那座塔」出现在前方
## (屋顶关往东走,出生地塔就该在东边)。同一关所有实例要一样。
@export var pan: float = 0.0
## 要走去的那座塔(0..4),窗灯更亮、塔顶灯闪;-1 = 不强调。
@export_range(-1, 4) var focus_tower: int = 0
## 月亮在天上的位置(视野比例,0..1)。
@export var moon_at: Vector2 = Vector2(0.24, 0.16)
## 月亮半径,世界像素。
@export var moon_radius: float = 11.0
## 画不画近处屋顶(屋顶关自己有前景屋顶时也可以关)。
@export var show_near: bool = true
## 远处贫民窟里那扇暖窗(旧屋)。
@export var show_home_light: bool = true
## 城里一列列车灯往坑口开(高空栈桥,2026-10-12 线索链:「他们就是这样被送下去的」)。
@export var convoy: bool = false

## 每座塔的灯亮多少(0..1):出生地、精炼、登记、军事、中央。结局「高塔灯灭」时一座一座调到 0。
## 探照灯、塔顶灯、精炼塔的烟跟着各自那座塔的灯走。
var tower_light: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0])
## 坑口的紫光和紫柱亮多少(0..1)。结局切断方舟后熄掉。
var crater_level: float = 1.0


## 第 `t` 座塔的灯调到 `v`(0..1)。
func set_tower_light(t: int, v: float) -> void:
	if t >= 0 and t < tower_light.size():
		tower_light[t] = clampf(v, 0.0, 1.0)

static var _cache: Dictionary = {}

var _tex: Dictionary = {}
var _time: float = 0.0
var _stars: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	if as_background:
		z_index = -100
		z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 5
	for i in 140:
		# 星星钉在「天」上:x 0..1、y 0..0.7 的视野比例,z = 亮度(大于 0.85 的会闪)
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.7, rng.randf()))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ---------------------------------------------------------------- 生成

func _key(layer: String) -> String:
	return "%s:%d:%d:%d:%d:%s:%.3f" % [layer, seed_value, int(level_rect.size.x), focus_tower, int(show_home_light), str(show_near), pan]


func _build() -> void:
	_tex["cliffs"] = _cached("cliffs", P_CLIFFS, 220, _paint_cliffs)
	# 塔身和塔灯分两张:灯要能一座一座关(结局)。两张用同一个种子画,窗的位置对得上
	_tex["towers"] = _cached("towers", P_TOWERS, 480, _paint_towers.bind(false))
	_tex["tower_lights"] = _cached("tower_lights", P_TOWERS, 480, _paint_towers.bind(true), "towers")
	_tex["city"] = _cached("city", P_CITY, 200, _paint_city)
	if show_near:
		_tex["near"] = _cached("near", P_NEAR, 160, _paint_near)


func _cached(layer: String, p: float, h: int, painter: Callable, seed_layer: String = "") -> ImageTexture:
	var k := _key(layer)
	if _cache.has(k):
		return _cache[k]
	var w: int = int(VIEW_W_MAX + p * level_rect.size.x + 64.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_key(seed_layer if not seed_layer.is_empty() else layer))
	painter.call(img, rng)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex


## 破碎的大陆:一道锯齿的远山,上缘一线冷青的反光;天上几块浮着的碎陆,底下拖着掉落的碎屑。
func _paint_cliffs(img: Image, rng: RandomNumberGenerator) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var body := INK_DEEP.lerp(STEEL_BLUE, 0.35)
	var rim := Color(COLD_CYAN, 0.55)
	var y: float = h - 40.0
	for x in w:
		y = clampf(y + rng.randf_range(-2.2, 2.2) + (h - 46.0 - y) * 0.02, h - 90.0, h - 14.0)
		# 断口:偶尔一段陡降,像大陆被掰断的地方
		if rng.randf() < 0.006:
			y = minf(y + rng.randf_range(18.0, 34.0), h - 10.0)
		var top: int = int(y)
		img.fill_rect(Rect2i(x, top, 1, h - top), body)
		img.set_pixel(x, top, rim)
	# 浮着的碎陆
	for i in 7:
		var cx: int = rng.randi_range(40, w - 60)
		var cy: int = rng.randi_range(20, h - 120)
		var rw: int = rng.randi_range(14, 40)
		var rh: int = rng.randi_range(5, 12)
		for k in rh:
			var inset: int = int(float(k) * float(rw) / float(rh * 2) + rng.randf_range(0.0, 2.0))
			img.fill_rect(Rect2i(cx + inset, cy + k, maxi(rw - inset * 2, 2), 1), body)
		img.fill_rect(Rect2i(cx + 1, cy, rw - 2, 1), rim)
		for d in rng.randi_range(2, 4):
			var dx: int = cx + rng.randi_range(2, rw - 3)
			var dl: int = rng.randi_range(4, 14)
			for k in dl:
				if k % 3 != 2:
					img.set_pixel(dx, cy + rh + 2 + k, Color(body, 0.8 - float(k) / dl * 0.6))


## 全景位置(0..1)转过 `pan` 之后在哪儿;留出两边各 6% 不放东西(免得一座塔被贴图边切开)。
func _u(u: float) -> float:
	return 0.06 + fposmod(u + pan, 1.0) * 0.88


## 塔群:五座塔的剪影,惨白的窗,各有各的样子。`lights` = false 只画塔身,true 只画灯(窗、锈红灯、
## 中央塔的紫环、塔顶灯)。两种都按同样的顺序取随机数,所以两张贴图的窗位置一模一样。
func _paint_towers(img: Image, rng: RandomNumberGenerator, lights: bool) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for t in TOWER_U.size():
		var cx: int = int(_u(TOWER_U[t]) * w)
		var th: int = TOWER_H[t]
		var bw: int = 28 if t < 4 else 20
		var body := INK_DEEP.darkened(0.35) if t < 4 else SLIME_BLACK
		var lit: float = 1.0 if t == focus_tower else 0.6
		# 塔身:往上收窄,中间两道腰带
		for y in th:
			var k: float = float(y) / float(th)
			var half: int = int(bw * 0.5 * lerpf(1.0, 0.62, k))
			if t == 4:
				half = int(bw * 0.5 * lerpf(1.0, 0.25, pow(k, 0.7)))
			if not lights:
				img.fill_rect(Rect2i(cx - half, h - 1 - y, half * 2, 1), body)
				if y % 44 == 26 and t < 4:
					img.fill_rect(Rect2i(cx - half - 2, h - 1 - y, half * 2 + 4, 2), body)
		# 窗
		var rows: int = th / 6
		for r in range(2, rows):
			var y: int = h - 1 - r * 6
			var k: float = float(r * 6) / float(th)
			var half: int = int(bw * 0.5 * lerpf(1.0, 0.62, k)) - 3
			if t == 4:
				continue
			var step: int = 3 if t == 2 else 4
			var x: int = cx - half
			while x < cx + half:
				var dense: float = 0.75 if t == 2 else 0.45
				if rng.randf() < dense:
					var a: float = lit * rng.randf_range(0.35, 0.95)
					if lights:
						img.fill_rect(Rect2i(x, y, 1, 2), Color(TOWER_WHITE, a))
				x += step
		# 精炼塔:外挂管道 + 锈红灯
		if t == 1:
			for side in [-1, 1]:
				var px: int = cx + side * (bw / 2 + 2)
				if not lights:
					img.fill_rect(Rect2i(px - 1, h - th + 20, 2, th - 26), INK_DEEP.darkened(0.2))
			for i in 6:
				var r := Rect2i(cx + rng.randi_range(-bw / 2, bw / 2), h - rng.randi_range(40, th - 20), 2, 2)
				if lights:
					img.fill_rect(r, RUST_RED)
		# 军事塔:顶上天线
		if t == 3 and not lights:
			img.fill_rect(Rect2i(cx, h - th - 24, 1, 24), body)
			img.fill_rect(Rect2i(cx - 5, h - th - 13, 11, 1), body)
		# 中央高塔:细尖,几道环
		if t == 4 and lights:
			for ring in [0.3, 0.55, 0.78]:
				var ry: int = h - 1 - int(th * ring)
				var rh: int = int(bw * 0.5 * lerpf(1.0, 0.25, pow(ring, 0.7))) + 4
				img.fill_rect(Rect2i(cx - rh, ry, rh * 2, 1), Color(VIOLET_HAZE.lightened(0.15), 0.95))
		# 塔顶灯
		if lights:
			img.fill_rect(Rect2i(cx - 1, h - th - 3, 2, 2), TOWER_WHITE)


## 贫民窟:一片高低不齐的屋顶剪影,稀稀拉拉几扇冷光窗;很远的地方一扇暖窗(旧屋)。
func _paint_city(img: Image, rng: RandomNumberGenerator) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var body := INK_DEEP.darkened(0.15)
	var x: int = 0
	var home_x: int = int(w * 0.06)
	while x < w:
		var bw: int = rng.randi_range(18, 64)
		var bh: int = rng.randi_range(24, 110)
		var top: int = h - bh
		img.fill_rect(Rect2i(x, top, bw, bh), body)
		# 斜屋顶 / 水塔 / 天线
		var roll: float = rng.randf()
		if roll < 0.35:
			for k in mini(bw / 2, 10):
				img.fill_rect(Rect2i(x + k, top - k, bw - k * 2, 1), body)
		elif roll < 0.5:
			img.fill_rect(Rect2i(x + bw / 2 - 5, top - 14, 10, 9), body)
			img.fill_rect(Rect2i(x + bw / 2 - 4, top - 5, 1, 5), body)
			img.fill_rect(Rect2i(x + bw / 2 + 3, top - 5, 1, 5), body)
		elif roll < 0.62:
			img.fill_rect(Rect2i(x + rng.randi_range(2, bw - 3), top - 18, 1, 18), body)
		# 窗:大多黑着
		var wy: int = top + 6
		while wy < h - 6:
			var wx: int = x + 3
			while wx < x + bw - 4:
				if rng.randf() < 0.07:
					img.fill_rect(Rect2i(wx, wy, 2, 3), Color(COLD_CYAN, rng.randf_range(0.5, 0.9)))
				wx += 6
			wy += 9
		if show_home_light and x <= home_x and home_x < x + bw:
			img.fill_rect(Rect2i(home_x, top + 10, 3, 4), ACCENT_WARM)
		x += bw + rng.randi_range(-4, 3)


## 近处屋顶:更大、更暗,烟囱、晾衣绳、水管。只在屋顶关这种开阔的地方看得到。
func _paint_near(img: Image, rng: RandomNumberGenerator) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var body := Color("070B14")
	var x: int = 0
	var prev_top: int = h - 60
	while x < w:
		var bw: int = rng.randi_range(50, 140)
		var top: int = h - rng.randi_range(40, 120)
		img.fill_rect(Rect2i(x, top, bw, h - top), body)
		img.fill_rect(Rect2i(x, top, bw, 1), Color(STEEL_BLUE, 0.9))
		if rng.randf() < 0.6:
			var cx: int = x + rng.randi_range(6, bw - 12)
			img.fill_rect(Rect2i(cx, top - 16, 6, 16), body)
			img.fill_rect(Rect2i(cx - 1, top - 17, 8, 2), body)
		# 晾衣绳:从上一栋垂到这一栋
		if rng.randf() < 0.5 and x > 0:
			var a := Vector2(x - 6, prev_top - 10)
			var b := Vector2(x + 10, top - 12)
			for k in 20:
				var t: float = float(k) / 19.0
				var p: Vector2 = a.lerp(b, t) + Vector2(0.0, sin(t * PI) * 6.0)
				img.set_pixel(int(p.x), int(p.y), Color(STEEL_BLUE, 0.8))
		prev_top = top
		x += bw + rng.randi_range(0, 30)


# ---------------------------------------------------------------- 画

func _view() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var vp: Vector2 = get_viewport_rect().size
	if cam == null:
		return Rect2(level_rect.position, vp * 0.5)
	var size: Vector2 = vp / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)


## 地平线的世界 y:永远在视线高度。
func _horizon_y(view: Rect2) -> float:
	return view.position.y + view.size.y * horizon


## 从关卡底下往上爬了多高(世界像素)。
func _climbed(view: Rect2) -> float:
	return maxf(level_rect.end.y - view.get_center().y, 0.0)


## 一层贴图的左上角(世界坐标)。底边贴在地平线往下 `drop` 的地方。
func _layer_pos(tex: Texture2D, p: float, view: Rect2, drop: float) -> Vector2:
	var cx: float = view.get_center().x
	var x: float = cx - VIEW_W_MAX * 0.5 - 32.0 - p * (cx - level_rect.position.x)
	return Vector2(x, _horizon_y(view) + drop - tex.get_height())


func _draw() -> void:
	# 一律按世界坐标画:在窗里时本节点挂在窗下面、原点跟着窗走,不抵消的话整片景会平移出窗外、
	# 被遮罩裁光(2026-10-12:塔里的窗看到的全是砖墙;坑口那个破口刚好贴着原点才没露馅)
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	var view := _view().grow(4.0)
	var hy: float = _horizon_y(view)
	_draw_sky(view, hy)
	_draw_stars(view, hy)
	_draw_moon(view, hy)
	var towers: Texture2D = _tex["towers"]
	var tpos: Vector2 = _layer_pos(towers, P_TOWERS, view, 6.0)
	_draw_crater(view, hy, tpos, towers.get_width())
	var cliffs: Texture2D = _tex["cliffs"]
	draw_texture(cliffs, _layer_pos(cliffs, P_CLIFFS, view, 10.0))
	_draw_searchlights(tpos, towers)
	draw_texture(towers, tpos)
	_draw_tower_lights(tpos)
	_draw_beacons(tpos, towers)
	_draw_smoke(tpos, towers)
	# 近处的城和屋顶:爬得越高沉得越低
	var climbed: float = _climbed(view)
	var city: Texture2D = _tex["city"]
	var city_drop: float = 34.0 + climbed * climb_drop * 1.6
	var cpos: Vector2 = _layer_pos(city, P_CITY, view, city_drop)
	draw_texture(city, cpos)
	if convoy:
		_draw_convoy(cpos, city.get_width(), city.get_height())
	var below: float = hy + city_drop
	if show_near and _tex.has("near"):
		var near: Texture2D = _tex["near"]
		var near_drop: float = 80.0 + climbed * climb_drop * 4.0
		draw_texture(near, _layer_pos(near, P_NEAR, view, near_drop))
		below = hy + near_drop
	# 最低那层贴图的底边以下:城下面的暗
	if below < view.end.y:
		draw_rect(Rect2(view.position.x, below, view.size.x, view.end.y - below), Color("070B14"))
	# 城沉下去以后,地平线和城之间露出的是远处的大地(比天暗一点)
	if city_drop > 34.0 + 1.0:
		var gap_top: float = hy + 10.0
		var gap_bot: float = hy + city_drop - city.get_height()
		if gap_bot > gap_top:
			draw_rect(Rect2(view.position.x, gap_top, view.size.x, gap_bot - gap_top), Color("0A111E"))


## 夜空:顶上近黑,往地平线渐亮成钢蓝;坑口那边透一点紫。
func _draw_sky(view: Rect2, hy: float) -> void:
	var bands: int = 24
	var top: float = view.position.y
	var span: float = maxf(hy - top, 1.0)
	for i in bands:
		var k: float = float(i) / float(bands)
		var c := Color("04070D").lerp(INK_DEEP, smoothstep(0.0, 0.6, k)).lerp(STEEL_BLUE.darkened(0.25), smoothstep(0.55, 1.0, k))
		draw_rect(Rect2(view.position.x, top + span * k, view.size.x, span / bands + 1.0), c)
	draw_rect(Rect2(view.position.x, hy, view.size.x, maxf(view.end.y - hy, 0.0)), STEEL_BLUE.darkened(0.25))


## 塔灯:全亮时整张画;有塔在关灯时按塔分块画,各用各的亮度。
func _draw_tower_lights(tpos: Vector2) -> void:
	var lights: Texture2D = _tex["tower_lights"]
	var all_on: bool = true
	for v in tower_light:
		if v < 0.999:
			all_on = false
	if all_on:
		draw_texture(lights, tpos)
		return
	var h: float = lights.get_height()
	for t in TOWER_U.size():
		if tower_light[t] <= 0.001:
			continue
		var cx: float = floorf(_u(TOWER_U[t]) * lights.get_width())
		var src := Rect2(cx - 24.0, 0.0, 48.0, h)
		draw_texture_rect_region(lights, Rect2(tpos + src.position, src.size), src, Color(1, 1, 1, tower_light[t]))


## 灯全灭时星星亮一些(没了光害)。
func _lights_off() -> float:
	var sum: float = 0.0
	for v in tower_light:
		sum += v
	return clampf(1.0 - sum / float(tower_light.size()), 0.0, 1.0) * 0.5 + (1.0 - crater_level) * 0.5


func _draw_stars(view: Rect2, hy: float) -> void:
	var boost: float = 1.0 + 0.8 * _lights_off()
	for s in _stars:
		var p := Vector2(view.position.x + s.x * view.size.x, view.position.y + s.y * (hy - view.position.y))
		var a: float = minf((0.25 + 0.5 * s.z) * boost, 1.0)
		if s.z > 0.85:
			a *= 0.6 + 0.4 * sin(_time * (1.5 + s.z * 3.0) + s.x * 40.0)
		draw_rect(Rect2(p.round(), Vector2.ONE), Color(TOWER_WHITE, a))


## 月亮:冷白的满月,几块暗斑,一圈淡淡的冷青光晕。钉在天上(和星星一样不随镜头走)。
func _draw_moon(view: Rect2, hy: float) -> void:
	var c := Vector2(view.position.x + moon_at.x * view.size.x, view.position.y + moon_at.y * (hy - view.position.y)).round()
	var r: float = moon_radius
	for i in 4:
		var hr: float = r + 6.0 + i * 7.0
		_disc(c, hr, Color(COLD_CYAN, 0.05 - i * 0.01))
	_disc(c, r, TOWER_WHITE.darkened(0.05))
	_disc(c + Vector2(2.0, 1.0), r - 1.0, TOWER_WHITE)          # 受光的一侧亮一点
	for spot in [Vector3(-4, -3, 2.5), Vector3(3, 2, 2), Vector3(-1, 5, 1.5), Vector3(5, -5, 1.2)]:
		_disc(c + Vector2(spot.x, spot.y), spot.z, Color(STEEL_BLUE.lightened(0.45), 0.55))


## 像素圆(一行一行画,不画抗锯齿的圆)。
func _disc(c: Vector2, r: float, col: Color) -> void:
	var ri: int = int(ceil(r))
	for dy in range(-ri, ri + 1):
		var half: float = sqrt(maxf(r * r - float(dy * dy), 0.0))
		if half < 0.5:
			continue
		draw_rect(Rect2(c.x - round(half), c.y + dy, round(half) * 2.0, 1.0), col)


## 坑口:地平线上一大团紫光,慢慢呼吸;附近的天带一点紫;一道紫柱往天上去(方舟的强制信号)。
func _draw_crater(view: Rect2, hy: float, tpos: Vector2, tw: int) -> void:
	var cx: float = tpos.x + _u(CRATER_U) * tw
	if crater_level <= 0.001:
		return
	var breathe: float = (0.85 + 0.15 * sin(_time * 0.6)) * crater_level
	# 一个椭圆的紫色穹顶:一行一行画(每 2px 一行),宽度按椭圆收、透明度往上平滑减 ——
	# 用几块叠起来的矩形会看到一格一格的硬边
	var dome_h: float = 230.0
	var dome_w: float = 560.0
	var y: float = hy - dome_h
	while y < hy + 2.0:
		var t: float = clampf((hy - y) / dome_h, 0.0, 1.0)
		var half: float = dome_w * 0.5 * sqrt(maxf(1.0 - t * t, 0.0))
		var a: float = 0.24 * pow(1.0 - t, 2.2) * breathe
		# 外圈一半亮、里面 60% 再叠一半:椭圆的边缘不会是一道硬线
		draw_rect(Rect2(cx - half, y, half * 2.0, 2.0), Color(VIOLET_HAZE, a * 0.5))
		draw_rect(Rect2(cx - half * 0.6, y, half * 1.2, 2.0), Color(VIOLET_HAZE, a * 0.5))
		y += 2.0
	draw_rect(Rect2(cx - 40.0, hy - 6.0, 80.0, 8.0), Color(VIOLET_HAZE.lightened(0.3), 0.35 * breathe))
	# 光柱
	var beam_a: float = (0.1 + 0.04 * sin(_time * 0.4)) * crater_level
	draw_rect(Rect2(cx - 5.0, view.position.y, 10.0, hy - view.position.y), Color(VIOLET_HAZE, beam_a))
	draw_rect(Rect2(cx - 1.0, view.position.y, 2.0, hy - view.position.y), Color(VIOLET_HAZE.lightened(0.35), beam_a * 2.2))


## 军事塔的两盏探照灯扫天(冷白,很淡)。
func _draw_searchlights(tpos: Vector2, towers: Texture2D) -> void:
	var cx: float = tpos.x + _u(TOWER_U[3]) * towers.get_width()
	var top: float = tpos.y + towers.get_height() - TOWER_H[3] - 24.0
	var on: float = tower_light[3]
	if on <= 0.001:
		return
	for i in 2:
		var ang: float = -PI * 0.5 + sin(_time * (0.35 + i * 0.13) + i * 2.0) * 0.7
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		var o := Vector2(cx, top)
		var far: float = 300.0
		draw_colored_polygon(PackedVector2Array([o, o + dir * far + side * 18.0, o + dir * far - side * 18.0]),
				Color(TOWER_WHITE, 0.05 * on))
		draw_colored_polygon(PackedVector2Array([o, o + dir * far + side * 6.0, o + dir * far - side * 6.0]),
				Color(TOWER_WHITE, 0.05 * on))


## 塔顶灯:要去的那座一闪一闪,别的常亮很淡。
func _draw_beacons(tpos: Vector2, towers: Texture2D) -> void:
	for t in TOWER_U.size():
		var p := Vector2(tpos.x + _u(TOWER_U[t]) * towers.get_width(), tpos.y + towers.get_height() - TOWER_H[t] - 3.0)
		if t == focus_tower and tower_light[t] > 0.001:
			var on: float = (0.5 + 0.5 * sin(_time * 2.4)) * tower_light[t]
			draw_rect(Rect2(p - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(TOWER_WHITE, 0.15 * on))
			draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(TOWER_WHITE, 0.6 + 0.4 * on))


## 精炼塔顶上冒的烟(往右飘)。
func _draw_smoke(tpos: Vector2, towers: Texture2D) -> void:
	var p := Vector2(tpos.x + _u(TOWER_U[1]) * towers.get_width(), tpos.y + towers.get_height() - TOWER_H[1])
	for i in 8:
		var life: float = fposmod(_time * 0.12 + float(i) / 8.0, 1.0)
		var q: Vector2 = p + Vector2(life * 40.0, -life * 34.0 - 3.0)
		var r: float = 2.0 + life * 7.0
		draw_rect(Rect2(q - Vector2(r, r * 0.6), Vector2(r * 2.0, r * 1.2)), Color(STEEL_BLUE.lightened(0.1), 0.35 * (1.0 - life) * tower_light[1]))


## 车队:城里的街面上,三队车一队五辆往右开(坑口在右边),车头两点冷白、车尾一点锈红,队伍首尾淡入淡出。
## 跟城一起按 P_CITY 的视差走、画在城的底边 —— 从高处往下看,一列车灯穿过整座城开向坑口。
func _draw_convoy(cpos: Vector2, cw: int, ch: int) -> void:
	var y: float = cpos.y + float(ch) - 4.0
	var length: float = float(cw)
	for group in 3:
		var head: float = fposmod(_time * 16.0 + float(group) * length / 3.0, length)
		for k in 5:
			var d: float = head - float(k) * 20.0
			if d < 0.0:
				continue
			var x: float = roundf(cpos.x + d)
			var fade: float = clampf(d / 60.0, 0.0, 1.0) * clampf((length - d) / 60.0, 0.0, 1.0)
			draw_rect(Rect2(x - 8.0, y, 9.0, 3.0), Color(INK_DEEP.darkened(0.2), fade))          # 车身
			draw_rect(Rect2(x + 1.0, y, 2.0, 2.0), Color(TOWER_WHITE, 0.95 * fade))               # 车头灯
			draw_rect(Rect2(x + 3.0, y, 10.0, 2.0), Color(TOWER_WHITE, 0.16 * fade))              # 灯照出去的一抹
			draw_rect(Rect2(x - 9.0, y + 1.0, 2.0, 1.0), Color(RUST_RED.lightened(0.25), 0.85 * fade))  # 尾灯
