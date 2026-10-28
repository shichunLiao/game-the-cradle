extends SceneTree
## DEV ONLY:剧情瞬间检查 + 截图(关中旁白、摔守卫那一句、工装布、终端闪字、格栅黑雾)。
## 2026-10-12 线索链:塔2 广播、叠好的工装(V-17)、塔3 档案终端(打字 → 灭 → 走开再回来重打)、
## 塔4 守卫停下来聊天(碰头 → 等 Ryn 靠近 → 三句 → 散开)。
##
##     godot --path . --windowed --resolution 1280x720 -s res://src/dev/story_check.gd
##
## 每项打印 PASS/FAIL,有失败时退出码 1。截图存到 user://story_shots/。
## 节点名跟着 tools/level_builder 走:`Story00`、`Pickup00`、`Terminal00`、`PitWind00`、`GuardFallLine`、
## `Hatch00/01`。守卫和灯都解除(`_disarm`),免得检查途中触发失败流程。
##
## 剧情节点一律不写类型(`StoryTrigger` 等):`-s` 模式下脚本里写了类名,那些类会在 autoload
## 注册之前编译,`Audio` 就找不到。用 `call()` 鸭子类型调用。

## TerminalFlash.State:IDLE 0 · FLICKER 1 · WORD 2 · OUTRO 3 · DARK 4
const TERM_IDLE := 0
const TERM_WORD := 2
const TERM_DARK := 4
## GuardChat.Phase:IDLE 0 · GATHER 1 · WAIT_EAR 2 · TALK 3 · DONE 4
const CHAT_WAIT_EAR := 2
const CHAT_TALK := 3
const CHAT_DONE := 4
const BROADCAST_LINE := "〔广播〕V-11 到 V-20 号，零点到坑口转运站集合。"

var level: Node
var ryn: Ryn
var fails := 0
var shot := 0


func _check(ok: bool, what: String) -> void:
	print("[story] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


## 按物理帧(固定 60/秒)等,不按渲染帧 —— 120Hz 屏幕上渲染帧是两倍快。
func _wait(sec: float) -> void:
	for _i in int(sec * 60.0):
		await physics_frame


func _snap(name: String) -> void:
	var dir := OS.get_user_data_dir() + "/story_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png("%s/%02d-%s.png" % [dir, shot, name])
	shot += 1


func _load(path: String) -> void:
	if level != null:
		level.queue_free()
		await process_frame
	level = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	ryn = level.get_node("Ryn") as Ryn
	_disarm(level)
	await _wait(3.4)   # 入塔句演完


func _subtitle_text() -> String:
	var sub := level.get_node("TowerSubtitle") as TowerSubtitle
	return (sub.get("_label") as Label).text


## 把 Ryn 放进一块旁白触发区(脚踩在触发区底边那一行的地面上)。
func _check_story(node: String, line: String) -> void:
	var st: Area2D = level.get_node(node)
	var size: Vector2 = st.get("size")
	ryn.global_position = Vector2(st.global_position.x + size.x * 0.5, st.global_position.y + size.y)
	await _wait(1.2)
	_check(st.call("is_done") and _subtitle_text() == line, "%s 出字:%s" % [node, line])
	_snap(level.name.to_lower() + "-" + node.to_lower())
	# 再走进去一次不会再出
	ryn.global_position += Vector2(0.0, -400.0)
	await _wait(0.3)
	(level.get_node("TowerSubtitle") as TowerSubtitle).show_line("x")
	ryn.global_position = Vector2(st.global_position.x + size.x * 0.5, st.global_position.y + size.y)
	await _wait(1.0)
	_check(_subtitle_text() == "x", "%s 只出一次" % node)


func _hatch_under(g: Guard) -> Dismantlable:
	var best: Dismantlable = null
	var best_d := INF
	for n in level.get_children():
		var p := n as Dismantlable
		if p == null or p.kind != Dismantlable.Kind.FLOOR_HATCH:
			continue
		var d: float = absf(p.global_position.y - g.global_position.y) * 10.0 \
				+ absf(p.global_position.x - g.global_position.x)
		if d < best_d:
			best_d = d
			best = p
	return best


## 守卫和灯都不抓人。只设 `darkness_veto` 不够:`ShadowRegistry` 开场后会把它改回暗区判定。
## 守卫整个停掉;探照灯、门禁跟路线机器人一样把 `ryn` 置空。
func _disarm(node: Node) -> void:
	for c in node.get_children():
		if c is Guard:
			(c as Guard).process_mode = Node.PROCESS_MODE_DISABLED
		elif c.get(&"ryn") != null and c.get(&"detection_reset") != null:
			c.set(&"ryn", null)
		_disarm(c)


## 塔4 守卫聊天:C、D 照常走(但永远看不见人),Ryn 进军械库那一段 → 两人碰头;Ryn 爬进货箱下的暗缝 → 开口。
func _check_chat() -> void:
	await _load("res://src/levels/tower_4_military.tscn")
	var gc := level.get_node("GuardC") as Guard
	var gd := level.get_node("GuardD") as Guard
	for g in [gc, gd]:
		g.process_mode = Node.PROCESS_MODE_INHERIT
		g.darkness_veto = func(_p: Vector2) -> bool: return true   # 开场之后设的 veto 会留着
	var chat: Node2D = level.get_node("GuardChat00")
	chat.set(&"ryn", ryn)   # `_disarm` 把有 ryn + detection_reset 的节点都置空了,聊天要认得 Ryn
	ryn.global_position = Vector2(10 * 16 + 8, 118 * 16)            # 军械库西头的存档点:在靠近区里,离两人还远
	var waited := 0.0
	while chat.call("phase") != CHAT_WAIT_EAR and waited < 60.0:
		await _wait(0.5)
		waited += 0.5
	_check(chat.call("phase") == CHAT_WAIT_EAR, "两人走到碰头点停下(%.1f 秒)" % waited)
	_check(gc.facing == 1 and gd.facing == -1, "面对面")
	_snap("tower4-chat-waiting")
	await _wait(1.0)
	_check(chat.call("phase") == CHAT_WAIT_EAR, "Ryn 还远:不开口,只冒「……」")
	ryn.global_position = Vector2(56 * 16 + 8, 118 * 16)            # 货箱下面的暗缝里
	await _wait(1.2)
	_check(chat.call("phase") == CHAT_TALK and chat.call("current_line") == 0, "Ryn 爬近了:开口说第一句")
	_snap("tower4-chat-line0")
	await _wait(4.2)
	_check(chat.call("current_line") == 1, "第二句")
	_snap("tower4-chat-line1")
	await _wait(5.0)
	_check(chat.call("phase") == CHAT_DONE, "说完了")
	var xc := gc.global_position.x
	await _wait(1.5)
	_check(gc.facing == -1 and gc.global_position.x < xc - 10.0, "说完各走各的(C 往西走了 %.0f px)" % (xc - gc.global_position.x))


func _initialize() -> void:
	# 看门狗:中途脚本出错会让这个协程停住、窗口一直开着 —— 到点就带错误码退出
	create_timer(260.0).timeout.connect(func() -> void:
		print("[story] TIMEOUT (a step errored or hung)")
		quit(2))
	# ---- 塔1:三楼关中一句、顶楼第一个「听」的守卫
	await _load("res://src/levels/tower_1_birthplace.tscn")
	await _check_story("Story00", "「这个塔这么高，我要怎么找到她啊」")
	# G4:顶楼第一个「听」的守卫
	await _check_story("Story02", "「他的头盔怎么连条缝都没有。」")

	# ---- 塔2:拆没人站的盖板不说;守卫站在盖板上掉下去才说
	await _load("res://src/levels/tower_2_refinery.tscn")
	var fall: Node = level.get_node("GuardFallLine")
	var gc := level.get_node("GuardC") as Guard
	var gg := level.get_node("GuardG") as Guard
	var hc := _hatch_under(gc)
	var hg := _hatch_under(gg)
	_check(hc != null and hg != null and hc != hg, "找得到守卫 C、G 各自的盖板")
	# C 定住、挪开 → 拆 C 的盖板 → 没人掉 → 不说
	gc.process_mode = Node.PROCESS_MODE_DISABLED
	gc.global_position = Vector2(hc.global_position.x - 200.0, hc.global_position.y)
	hc.force_dismantle()
	await _wait(1.4)
	_check(not fall.call("is_done"), "拆没人站的盖板:不说")
	# G 站到他的盖板中间 → 拆 → 掉下去 → 说。G 要受重力,得重新启用;
	# 这时 ShadowRegistry 早已接过线(只接一次),这里设的「全黑」不会再被改回去
	gg.darkness_veto = func(_p: Vector2) -> bool: return true
	gg.process_mode = Node.PROCESS_MODE_INHERIT
	ryn.global_position = Vector2(hg.global_position.x - 120.0, hg.global_position.y)
	gg.global_position = Vector2(hg.global_position.x + hg.size.x * 0.5, hg.global_position.y)
	var y0 := gg.global_position.y
	await _wait(0.1)
	hg.force_dismantle()
	await _wait(0.6)
	_snap("tower2-guard-falling")
	await _wait(0.8)
	_check(gg.global_position.y - y0 > 24.0, "守卫 G 掉下去了(%.0f px)" % (gg.global_position.y - y0))
	_check(fall.call("is_done") and _subtitle_text() == "「啊，对不起。……不对，我干嘛道歉呢。」", "守卫掉下去:「啊，对不起。……不对，我干嘛道歉呢。」")
	_snap("tower2-fall-line")
	# 广播:上到第 3 段,墙上的喇叭
	var pa: Node2D = level.get_node("Broadcast00")
	_check(not pa.call("is_done"), "广播开场没播")
	ryn.global_position = Vector2(16 * 16 + 8, 139 * 16)   # 塔2 S2(2026-10-15 加高后是 139)
	await _wait(1.6)
	var sub := level.get_node("TowerSubtitle") as TowerSubtitle
	var lbl := sub.get("_label") as Label
	_check(pa.call("is_done") and _subtitle_text() == BROADCAST_LINE, "广播:" + BROADCAST_LINE)
	_check(lbl.get_theme_color(&"font_color").is_equal_approx(TowerSubtitle.BROADCAST_COLOR), "广播字幕是冷青色(不是 Ryn 的话)")
	_snap("tower2-broadcast")
	# 工装布:放在脚下
	var pick: Area2D = level.get_node("Pickup00")
	ryn.global_position = pick.global_position + Vector2(-40.0, 0.0)
	await _wait(1.0)
	_snap("tower2-pickup-before")
	ryn.global_position = pick.global_position
	await _wait(0.3)
	_check(pick.call("is_taken") and _subtitle_text() == "「这不是她的工装V-17吗。」", "捡到工装:「这不是她的工装V-17吗。」")
	_check(lbl.get_theme_color(&"font_color").is_equal_approx(Color(0.784314, 0.831373, 0.878431, 1)), "Ryn 的话换回原来的颜色")
	_snap("tower2-pickup")
	await _wait(0.8)
	_check(not pick.visible, "捡起来后布片消失")

	# ---- 塔3:第一个「追」的守卫、档案架一句;出口前终端闪「缓蚀者」再灭
	await _load("res://src/levels/tower_3_registry.tscn")
	# G4:档案架那层第一个「追」的守卫(梯子上来那一刻,比书架那句低,所以排在前面)
	await _check_story("Story00", "「他怎么盯着地上看。不对，他是在找我的脚印吗？」")
	await _check_story("Story01", "「让我看看，不过上面应该没写我的名字。」")
	var term: Node2D = level.get_node("Terminal00")
	_check(term.call("state") == TERM_IDLE, "终端开场是待机")
	_check((term.get("lines") as PackedStringArray).size() == 3, "终端是档案模式(三行)")
	ryn.global_position = Vector2(term.global_position.x - 112.0, term.global_position.y)   # 触发区从 62 列起,这里在它外面
	await _wait(1.0)
	_snap("tower3-terminal-idle")
	ryn.global_position = Vector2(term.global_position.x - 40.0, term.global_position.y)
	await _wait(0.3)
	_check(term.call("state") != TERM_IDLE, "走近终端开演")
	await _wait(1.6)
	_check(term.call("state") == TERM_WORD, "终端在打档案")
	_snap("tower3-record-typing")
	await _wait(2.4)
	_check(term.call("state") == TERM_WORD, "打完停着,读得到")
	_snap("tower3-record-full")
	await _wait(4.0)
	_check(term.call("state") == TERM_DARK, "终端灭了")
	_snap("tower3-terminal-dark")
	ryn.global_position = Vector2(term.global_position.x - 112.0, term.global_position.y)
	await _wait(0.4)
	ryn.global_position = Vector2(term.global_position.x - 40.0, term.global_position.y)
	await _wait(0.6)
	_check(term.call("state") != TERM_DARK and term.call("state") != TERM_IDLE, "走开再回来:档案重新打一遍")

	# ---- 塔4:城垛一句;出口前格栅冒黑雾
	await _load("res://src/levels/tower_4_military.tscn")
	await _check_story("Story00", "「她之前经过过这里吗，貌似有点她留下的痕迹？」")
	var wind: Node2D = level.get_node("PitWind00")
	ryn.global_position = Vector2(wind.global_position.x - 24.0, wind.global_position.y)
	await _wait(1.5)
	_snap("tower4-pit-wind")
	_check(true, "格栅黑雾截图")
	await _check_chat()

	print("[story] done, %d fail(s). shots: %s/story_shots" % [fails, OS.get_user_data_dir()])
	quit(1 if fails > 0 else 0)
