class_name PhotoDisplay
extends CanvasLayer
## 全屏静帧展示合影。序章「Ryn 看合影」与终局「举起合影」共用这一个。
##
## 叙事脚本.md 刻意不写:「照片只在序章持有 + 终局使用各一次」—— 所以这个节点
## 两处各出现一次,不是随时可开的图鉴。
##
## 展示时压暗背景并 **暂停游戏**:这是静帧,不是叠加 UI。照片本身与吊坠是
## `美术规格.md` §2 允许暖色的少数地方。
##
## ## 关闭由本节点自己负责
##
## 调用方只管 `show_photo()`。关闭的输入在这里处理 —— 第一版把关闭留给调用方,
## 结果谁都没接,玩家打开照片后直接卡死(2026-10-04)。任何"会暂停游戏的全屏物"
## 都必须自带退出路径。
##
## 打开后有一小段输入锁:否则按下 E 的同一次按键会立刻把刚打开的照片关掉。

signal closed

const PHOTO_LAYER: int = 105

@export var photo: Texture2D
@export var font: TowerSubtitleConfig
## 照片下方的一行字。留空则不显示。
@export_multiline var caption: String = ""
@export var fade_time: float = 0.7
## 打开后多久才接受关闭输入,秒。防止同一次按键既开又关。
@export var input_lock: float = 0.35
## 底部的关闭提示。留空则不显示。
@export var hint_text: String = "任意键继续"
## 照片占屏高的比例。
@export_range(0.2, 0.95) var height_ratio: float = 0.62
## 照片四周的暖光晕。`美术规格.md` §2:暖色只给照片/吊坠/旧屋/结局。
@export var warm_glow: Color = Color("C4A574")

var _veil: ColorRect
var _frame: TextureRect
var _glow: ColorRect
var _caption: Label
var _hint: Label
var _open: bool = false
var _lock_left: float = 0.0


func _ready() -> void:
	layer = PHOTO_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_veil = ColorRect.new()
	_veil.color = Color("06090F")
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_veil)

	# 暖光晕:比照片略大的一块暖色,衬在后面
	_glow = ColorRect.new()
	_glow.color = Color(warm_glow, 0.12)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_glow)

	_frame = TextureRect.new()
	_frame.texture = photo
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 过滤方式不在这里定死,见 `_layout()`:放大用最近邻,缩小用线性 + mipmap。
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_frame)

	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		var face := SystemFont.new()
		face.font_names = font.font_names
		_caption.add_theme_font_override(&"font", face)
		_caption.add_theme_font_size_override(&"font_size", font.font_size)
		_caption.add_theme_color_override(&"font_color", font.color)
		_caption.add_theme_constant_override(&"outline_size", font.outline_size)
		_caption.add_theme_color_override(&"font_outline_color", font.outline_color)
	_caption.text = caption
	root.add_child(_caption)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = hint_text
	if font != null:
		var hf := SystemFont.new()
		hf.font_names = font.font_names
		_hint.add_theme_font_override(&"font", hf)
		_hint.add_theme_font_size_override(&"font_size", maxi(font.font_size - 10, 12))
	_hint.add_theme_color_override(&"font_color", Color(0.6, 0.65, 0.72, 0.75))
	root.add_child(_hint)

	root.resized.connect(_layout)
	_layout.call_deferred()
	root.modulate.a = 0.0
	root.visible = false


func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ph: float = vp.y * height_ratio
	var pw: float = ph
	if photo != null and photo.get_height() > 0:
		pw = ph * float(photo.get_width()) / float(photo.get_height())
	var pos := Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5 - vp.y * 0.04)
	# 按「放大还是缩小」自动选过滤,换图时不用改代码:
	#   - 放大(小像素图,如 150px 的占位图):最近邻,像素保持方正;
	#   - 缩小(手绘插画,如 600x750 的合影):线性 + mipmap,否则线稿会闪烁、断线。
	#     mipmap 要在对应 .import 里开 `mipmaps/generate=true` 才生效。
	var downscaled: bool = photo != null and ph < float(photo.get_height())
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if downscaled \
			else CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.position = pos
	_frame.size = Vector2(pw, ph)
	var pad: float = vp.y * 0.02
	_glow.position = pos - Vector2(pad, pad)
	_glow.size = Vector2(pw + pad * 2.0, ph + pad * 2.0)
	_caption.position = Vector2(0.0, pos.y + ph + pad * 2.0)
	_caption.size = Vector2(vp.x, vp.y * 0.1)
	_hint.position = Vector2(0.0, vp.y - vp.y * 0.09)
	_hint.size = Vector2(vp.x, vp.y * 0.06)


## 打开静帧。暂停游戏 —— 这是演出,不是 HUD。
func show_photo() -> void:
	if _open:
		return
	_open = true
	_lock_left = input_lock
	set_process(true)
	var root := get_child(0) as Control
	root.visible = true
	_layout()
	get_tree().paused = true
	await _fade(root, 0.0, 1.0)


## 关闭并恢复游戏。
func hide_photo() -> void:
	if not _open:
		return
	_open = false
	set_process(false)
	var root := get_child(0) as Control
	await _fade(root, 1.0, 0.0)
	root.visible = false
	get_tree().paused = false
	closed.emit()


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	# 游戏已暂停,这里拿到的是真实时间 —— 正是想要的。
	if _lock_left > 0.0:
		_lock_left = maxf(_lock_left - delta, 0.0)


## 任意键关闭。用 `_input` 而不是 `_unhandled_input`:暂停菜单也在听 ESC,
## 这里要先一步消费掉,否则关照片的同时会弹出暂停菜单。
func _input(event: InputEvent) -> void:
	if not _open or _lock_left > 0.0:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		hide_photo()


func _fade(node: CanvasItem, from: float, to: float) -> void:
	var t: float = 0.0
	var d: float = maxf(fade_time, 0.0001)
	node.modulate.a = from
	while t < d:
		# 游戏被暂停了,用真实时间推进,否则永远淡不完。
		t += get_process_delta_time()
		node.modulate.a = lerpf(from, to, clampf(t / d, 0.0, 1.0))
		await get_tree().process_frame
	node.modulate.a = to
