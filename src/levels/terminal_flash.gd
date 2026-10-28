class_name TerminalFlash
extends Node2D
## 墙边一台登记终端:平时屏幕上滚着暗绿的行,Ryn 走近时闪几下、跳出一个词,然后灭掉。
##
## 叙事脚本.md 塔 3 出塔:「终端闪过『缓蚀者』字样又灭。」—— 字在**世界里**的屏幕上,不走字幕;
## 紧接着 Ryn 碰到出口,出塔句「缓蚀者？那是什么东西。」接住它。
## 不夺走操作。只演一次;回存档点后屏幕保持熄灭(看过就是看过)。
##
## 节点原点是 **脚下那一点**(终端支架落在地面的左端)。屏幕约 34×22px。
## 屏幕上的字按 2 倍字号画、再缩到一半,镜头放大 2 倍后正好一比一,不糊。
##
## ## 档案模式(2026-10-12,线索链)
##
## 设了 `lines` 就不闪一个词,而是一行行打出一页档案(塔3:工号 V-17、体质 缓蚀者、去向 坑底 ███),
## 停一会儿再闪灭。`highlight` 那个词用亮色,`█` 画成涂黑的方块。屏幕放大(`screen_size`),挂在
## 门禁前 —— 等绿灯的时候正好读。档案是信息,看漏了可以再看:走开再回来会重新打一遍。
##
## Usage (in a scene): 设 `position`、`word`、`trigger_rect`(相对原点,px)。
## 关卡由 `tools/level_builder` 生成时用 `lv.terminal(...)` 放。

## 屏幕上跳出来的词。
@export var word: String = "缓蚀者"
## 触发区,相对节点原点,px。
@export var trigger_rect: Rect2 = Rect2(-64.0, -48.0, 128.0, 48.0)
## 字体(与字幕同一套系统字体)。
@export var font_config: TowerSubtitleConfig
## 字号(画的时候按这个字号栅格化,再缩一半)。
@export var font_size: int = 16
## 闪烁多久后定住出字,秒。
@export var flicker_time: float = 0.45
## 字定住多久,秒。
@export var word_time: float = 1.1
## 灭掉前最后闪一下,秒。
@export var outro_time: float = 0.25
@export var screen_color: Color = Color("0E2A22")
@export var text_color: Color = Color("6BE0A8")
@export var word_color: Color = Color("E8F4E0")
@export var frame_color: Color = Color("2A3644")
@export_group("Record")
## 档案的几行。为空 = 老样子只闪 `word`。
@export var lines: PackedStringArray = PackedStringArray()
## 屏幕大小,px。默认是小终端;档案用大屏。
@export var screen_size: Vector2 = Vector2(34.0, 22.0)
## 打字速度,字/秒。
@export var type_speed: float = 14.0
## 打完之后停多久,秒。
@export var record_hold: float = 3.4
## 档案里要亮起来的词。
@export var highlight: String = "缓蚀者"

## 涂黑:档案里的这个字符画成实心方块。
const REDACT: String = "█"

enum State { IDLE, FLICKER, WORD, OUTRO, DARK }

var _state: State = State.IDLE
var _t: float = 0.0
## 屏幕在节点里的矩形(按 `screen_size` 算;默认 = 老终端的 34×22)。
var _screen: Rect2 = Rect2(2.0, -40.0, 34.0, 22.0)
var _time: float = 0.0
var _font: Font
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1
	var face := SystemFont.new()
	if font_config != null:
		face.font_names = font_config.font_names
	_font = face
	_rng.seed = 7
	_screen = Rect2(2.0, -18.0 - screen_size.y, screen_size.x, screen_size.y)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = PhysicsLayers.PLAYER
	area.monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = trigger_rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = trigger_rect.position + trigger_rect.size * 0.5
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


## 现在演到哪一步(给验证脚本看)。
func state() -> State:
	return _state


## 直接开演(验证脚本用;正常由触发区开演)。
func play() -> void:
	if _state != State.IDLE:
		return
	_state = State.FLICKER
	_t = 0.0
	Audio.play(&"subtitle", -18.0, 0.55)


func _process(delta: float) -> void:
	_time += delta
	_t += delta
	match _state:
		State.FLICKER:
			if _t >= flicker_time:
				_state = State.WORD
				_t = 0.0
		State.WORD:
			if _t >= _word_duration():
				_state = State.OUTRO
				_t = 0.0
		State.OUTRO:
			if _t >= outro_time:
				_state = State.DARK
				_t = 0.0
				Audio.play(&"subtitle", -22.0, 0.4)
	queue_redraw()


func _draw() -> void:
	# 支架 + 外壳(支架在屏幕正下方)
	var cx: float = _screen.get_center().x
	draw_rect(Rect2(cx - 2.0, -18.0, 4.0, 18.0), frame_color.darkened(0.2))
	draw_rect(Rect2(cx - 9.0, -2.0, 18.0, 2.0), frame_color.darkened(0.2))
	draw_rect(_screen.grow(2.0), frame_color)
	var lit: bool = true
	match _state:
		State.FLICKER, State.OUTRO:
			lit = _rng.randf() < 0.55
		State.DARK:
			lit = false
	if not lit:
		draw_rect(_screen, Color(0.02, 0.03, 0.03))
		# 待机小红点
		if _state == State.DARK and fmod(_time, 2.0) < 1.0:
			draw_rect(Rect2(_screen.end.x - 3.0, _screen.end.y + 0.0, 1.0, 1.0), Color("A0303A"))
		return
	# 屏幕光晕(画在外壳外面一圈,很淡)
	draw_rect(_screen.grow(5.0), Color(text_color, 0.06))
	draw_rect(_screen, screen_color)
	if not lines.is_empty():
		if _state == State.WORD or _state == State.OUTRO:
			_draw_record()
		else:
			_draw_rows()
	elif _state == State.WORD or (_state == State.FLICKER and _t > flicker_time * 0.6):
		_draw_word()
	else:
		_draw_rows()


## 平时:一行行往上滚的「登记记录」(短横线,长短不一)。
func _draw_rows() -> void:
	var scroll: float = fmod(_time * 6.0, 4.0)
	for i in 6:
		var y: float = _screen.position.y + 3.0 + i * 4.0 - scroll
		if y < _screen.position.y + 1.0 or y > _screen.end.y - 2.0:
			continue
		var n: int = int(_time * 1.5) + i
		var w: float = 8.0 + float((n * 7) % 17)
		draw_rect(Rect2(_screen.position.x + 3.0, y, w, 1.0), Color(text_color, 0.55))


## 出字:大一号、居中、偶尔横移一像素(信号不稳)。
func _draw_word() -> void:
	if _font == null:
		return
	var jitter: float = 1.0 if _rng.randf() < 0.12 else 0.0
	var half: float = 0.5
	var size: Vector2 = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) * half
	var at := Vector2(_screen.get_center().x - size.x * 0.5 + jitter, _screen.get_center().y + size.y * 0.32)
	draw_rect(Rect2(_screen.position.x + 2.0, _screen.get_center().y - 6.0, _screen.size.x - 4.0, 12.0),
			Color(word_color, 0.08))
	draw_set_transform(at, 0.0, Vector2(half, half))
	draw_string(_font, Vector2.ZERO, word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, word_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_body_entered(body: Node2D) -> void:
	if body is not Ryn:
		return
	# 档案看漏了可以再看:灭了之后走开再回来,重新打一遍
	if _state == State.DARK and not lines.is_empty():
		_state = State.IDLE
	play()


## WORD 这一段多长:闪字模式是 `word_time`;档案模式是打完所有字 + 停一会儿。
func _word_duration() -> float:
	if lines.is_empty():
		return word_time
	return _typing_time() + record_hold


func _typing_time() -> float:
	var n: int = 0
	for l in lines:
		n += l.length() + 4          # 每行末尾多停 4 个字的时间
	return float(n) / maxf(type_speed, 0.1)


## 档案:一行行打出来。`highlight` 用亮色,`█` 画成方块,正在打的那行末尾一个闪烁的光标。
func _draw_record() -> void:
	if _font == null:
		return
	var half: float = 0.5
	var budget: int = int(_t * type_speed) if _state == State.WORD else 1 << 20
	var line_h: float = float(font_size) * half + 3.0
	var y: float = _screen.position.y + 4.0 + float(font_size) * half * 0.85
	var cursor := Vector2(-1.0, -1.0)
	for l in lines:
		if budget <= 0:
			break
		var shown: String = l.substr(0, mini(budget, l.length()))
		budget -= l.length() + 4
		var x: float = _screen.position.x + 4.0
		x = _draw_segments(shown, x, y, half)
		cursor = Vector2(x, y)
		y += line_h
	if _state == State.WORD and _t < _typing_time() and fmod(_time, 0.5) < 0.3 and cursor.x >= 0.0:
		draw_rect(Rect2(cursor.x + 1.0, cursor.y - float(font_size) * half * 0.8, 3.0, float(font_size) * half * 0.9),
				Color(text_color, 0.8))


## 一行里的字:普通字用 `text_color`,`highlight` 用 `word_color`,`█` 画方块。返回画完之后的 x。
func _draw_segments(s: String, x: float, y: float, half: float) -> float:
	var i: int = 0
	while i < s.length():
		if s[i] == REDACT:
			draw_rect(Rect2(x, y - float(font_size) * half * 0.8, float(font_size) * half - 1.0, float(font_size) * half * 0.9),
					Color(text_color, 0.85))
			x += float(font_size) * half
			i += 1
			continue
		var hl: int = s.find(highlight, i) if not highlight.is_empty() else -1
		var rd: int = s.find(REDACT, i)
		var stop: int = s.length()
		if hl >= 0:
			stop = mini(stop, hl)
		if rd >= 0:
			stop = mini(stop, rd)
		if stop == i and hl == i:
			x = _text(highlight.substr(0, mini(highlight.length(), s.length() - i)), x, y, half, word_color)
			i += highlight.length()
			continue
		x = _text(s.substr(i, stop - i), x, y, half, text_color)
		i = stop
	return x


func _text(t: String, x: float, y: float, half: float, color: Color) -> float:
	if t.is_empty():
		return x
	draw_set_transform(Vector2(x, y), 0.0, Vector2(half, half))
	draw_string(_font, Vector2.ZERO, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return x + _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * half
