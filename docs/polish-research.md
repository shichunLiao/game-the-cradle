# 精装修：参考的游戏、文献与做法

> 2026-10-13。用户：「我要开始精装修整个游戏的细节：Ryn 和姐姐的房间应该更温馨；塔内的装潢可以加灯或者蜡烛；
> 巡逻守卫应该要有 2D 建模，而不是现在的方块人。去学同类型、已上市游戏的表现风格，读开发文献、论文、开发者平台和论坛。」
>
> 这份是研究笔记 + 方案草案。**还没动手**:方案里每一项都要用户先选。
> 现状截图:旧屋(褐色、空荡,只有窗、一块板子、一道冷光)、结局门口(一扇亮门 + 两个小剪影)、
> 守卫(深蓝方块剪影 + 视野锥)、塔内(深色砖墙,道具少)。

## 1. 参考了什么

| 来源 | 学到的 | 用在哪 |
|---|---|---|
| **Mark of the Ninja**(Klei,2012)· Nels Anderson 的 GDC 2013 演讲与访谈([GameCritics 访谈](https://gamecritics.com/brad-gallaway/interview-with-mark-of-the-ninjas-nels-anderson/)、[PC Gamer 五条规则](https://pcgamer.com/stealth-game-design-mark-of-the-ninja)、[GDC Vault](https://gdcvault.com/play/1017791/Of-Choice-and-Breaking-New)) | 光暗是**二元的**,角色外观直接说明「我现在被看不看得见」;声音画成波纹;守卫的警觉变化一定有信号。关卡要「看起来暗,但不能真的是一片黑」—— 地面、可攀爬面仍然要读得出来 | 塔内加灯的**第一条规矩**:画面上的光必须和玩法上的光一致(§3.3);守卫状态靠姿势 + 头顶记号(§3.4) |
| **《武士零》Katana ZERO**(Justin Stander,2019;[GameRevolution 访谈](https://www.gamerevolution.com/features/520685-katana-zero-interview)、[Red Bull 访谈](https://www.redbull.com/int-en/katana-zero-developer-justin-stander-interview)) | 美术规格本来就点名的参考。脏暗的城市底层 + 局部霓虹灯光,灯光效果和细节是它的招牌 | 塔内灯具:暗底上**少量、有来源的光**,而不是整体调亮 |
| **Inside / Limbo**(Playdead;[GDC 2016 渲染演讲整理](https://80.lv/articles/the-rendering-of-inside-low-complexity-high-fidelity/)、[GDC Europe 报道](https://gdconf.com/news/limbo-devs-share-tips-on-creating-games-with-striking-visuals-at-gdc-europe)、[Wikipedia](https://en.wikipedia.org/wiki/Inside_(video_game))) | 色板极简,画面像「会动的剪影画」;光是分开调的(漫射 / 高光 / 反弹分开)。敌人是**戴面罩、拿手电的无脸人**,车上架探照灯 —— 无脸 = 体制的冷漠 | 守卫造型方向 A;探照灯 / 手电和视野锥同源 |
| **Planet of Lana**(Wishfully;[GamingBolt 访谈](https://gamingbolt.com/planet-of-lana-2-children-of-the-leaf-interview-art-direction-varied-environments-hybrid-robots-and-more)) | 小小的女孩对比压迫的大环境;二代重做光照,是为了在明亮场景之外做出「情绪化的暗场景」 | 旧屋(安全、暖)和塔(冷、压迫)的对比 |
| **Project Horseshoe 2017 报告《游戏中的温馨感:安全、柔软与被满足的需求》**(Daniel Cook、Tanya X. Short 等;[报告原文](https://www.projecthorseshoe.com/reports/featured/ph17r3.htm)、[Game Developer 整理](https://www.gamedeveloper.com/design/designing-for-coziness)) | 温馨 = **安全**(危险被降到最低)+ **富足**(基本需求都满足了)+ **柔软**(刺激温和)。具体做法:暖色、**有明确来源**的光、低环境光、柔和的阴影;**窗外的冷雨反衬屋里的暖**(危险在外面,但进不来);清楚的门槛;木头、布、毛线这类手作材料;朴素、用旧了的东西;听得出来源的小声音(火、水、呼吸) | 旧屋精装的全部规则(§3.1) |
| **《What Happened Here?》环境叙事**(Harvey Smith & Matthias Worch,GDC 2010;[GDC Vault](https://gdcvault.com/play/1012647/What-Happened-Here-Environmental)、[Nieman Storyboard 访谈](https://niemanstoryboard.org/2011/01/14/harvey-smith-on-environmental-storytelling-and-embedding-narrative/)) | 场景要有「历史感」:让玩家从道具的摆放**自己拼出发生过什么**。工具:道具、贴图、灯光、构图,还有系统对玩家的反应 | 旧屋里每件道具都讲一句两姐妹的生活(§3.2) |
| **TF2《Stylization with a Purpose》**(Valve,NPAR 2007;[论文](https://www.cs.princeton.edu/courses/archive/fall07/cos597B/papers/mitchell-team-fortress.pdf)、[GDC 2008 幻灯片](https://cdn.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf)) | 角色可读性靠**剪影、身体比例、武器**区分;明暗从脚(暗)到胸口(亮),**对比最强的地方放在胸口持枪处**;用**轮廓光(rim light)**在各种光照下把人和背景分开 | 守卫:胸口 / 手电最亮,背光一圈冷青轮廓 |
| 像素角色可读性的通行做法([Bugnet:清楚胜过细节](https://bugnet.io/blog/readable-game-art-why-clarity-beats-detail)、[Wayline 像素课](https://www.wayline.io/learn/pixel-art/4)) | 先画**纯色剪影**,剪影本身要认得出;每种敌人的剪影要不一样;状态变化靠**姿势**而不是只换颜色;角色和背景要在**不同的明度带**;常用灰度截图自检 | 守卫类型靠配件区分剪影;灰度检查 |
| **Magy Seif El-Nasr 的光照研究**([Expressive Lighting](https://summit.sfu.ca/_flysystem/fedora/sfu_migrate/40/SeifEl-Nasr_Expressive-Lighting-For-Interactive.pdf)、[Intelligent Lighting](https://summit.sfu.ca/_flysystem/fedora/sfu_migrate/596/SeifEl-Nasr_IntelligentLighting.pdf)) | 游戏里的光有五个作用:**引导视线**、保证动作看得清、唤起情绪、营造气氛、给出纵深 | 塔内灯的摆法:引导到梯子 / 出口,不往危险处引 |
| **《Measuring Risk in Stealth Games》**(Tremblay、Torres、Verbrugge,FDG 2014;[论文](https://www.cs.mcgill.ca/~jtremb59/Papers/fdg2014_paper_33.pdf)) | 比较了三种「潜行路线有多危险」的量法,**最简单的「离守卫多远」和玩家的感受最吻合** | 以后给体检工具加一项「路线离守卫的距离」(backlog K6) |
| **Dead Cells 的 3D 转像素管线**(Thomas Vasseur;[80.lv 案例](https://80.lv/articles/case-study-dead-cells-character-art-pipeline/)) | 一个美术撑不起手绘大量动画时,用 3D 模型 + 骨骼动画批量转成像素帧 | 守卫的出图方法之一(§4.2,本作不推荐:量太小,不值得) |
| **Godot 4 官方:2D 灯光与阴影 / 2D 骨骼**([2D lights and shadows](https://docs.godotengine.org/en/4.4/tutorials/2d/2d_lights_and_shadows.html)、[2D skeletons](https://docs.godotengine.org/de/4.5/tutorials/animation/2d_skeletons.html)、[GDQuest 法线贴图](https://gdquest.com/tutorial/godot/2d/lighting-with-normal-maps/)) | `PointLight2D` 要配 `CanvasModulate` 先把场景压暗;阴影过滤用「None」最快、最适合像素;灯可以用剔除遮罩只照某些层;**比灯便宜的做法是叠加混合的光晕贴图**(没有阴影) | 灯具做法(§4.1) |

## 2. 和美术规格的冲突(要用户决定)

`美术规格.md` §2:「关卡内 90% 用冷色;**暖色只出现在照片 / 吊坠 / 贫民窟旧屋 / 结局门口**。」

- 旧屋要温馨 → **完全符合**:暖色本来就留给旧屋。
- 塔里点蜡烛 → **冲突**:蜡烛是暖光。可选:
  1. 塔里只用冷光(荧光灯管、笼罩灯泡、应急灯),蜡烛只在旧屋 —— 守规格,也让旧屋的暖更珍贵。
  2. 塔里破例放极少的蜡烛,而且每一支都**有故事**(例:守卫休息室里给死去同伴点的蜡烛、缓蚀者被押走前留下的一截),
     例外记在 `design/ideas-backlog.md`,规格文件不动(用户锁定)。

## 3. 研究要点 → 本作的规矩

### 3.1 温馨(旧屋 + 结局门口)

- **安全**:屋里没有任何威胁;窗外是塔的惨白光(叙事脚本:「窗外高塔惨白光」)—— 冷光在外面,进不来。
- **富足**:看得出两个人一起过日子:两只杯子、一条一起盖的毯子、修好的东西比坏的多。
- **柔软**:一盏暖光有明确来源(油灯 / 蜡烛),轻轻闪;环境光很低;阴影柔和;只有一处最亮。
- **门槛**:门口地上一条暖光,和外面的冷夜分开;结局门口就是同一条光。
- **小声音**:灯芯的嗞嗞声、水壶、风从窗缝(环境声系统已经有,换一套旧屋的)。

### 3.2 环境叙事:旧屋里的东西(每件说一句两姐妹的生活)

| 道具 | 说的事 |
|---|---|
| 门框上两排身高刻痕,「V」和「R」,R 的最后一道停在去年 | 一起长大;Vera 不在了,没人再给 Ryn 量 |
| Vera 的工作台:拆开的收音机、螺丝分格盒、一盏改装过的台灯 | 她是机械师,「这种扣件……她教过我」的来处 |
| 针线盒 + 一件袖子改长了的外套 | 美术规格:Ryn 穿的是「姐姐改过的旧外套,袖口偏长」 |
| 两只杯子,一只有缺口 | 两个人;穷,但不缺 |
| 墙上一个空钩子 | 吊坠原来挂在这里 —— 现在在 Vera 脖子上 |
| 照片的位置(合影) | 已有;暖光打在照片上(规格:暖色给照片) |
| 窗台上偷来的小玩意儿 | Ryn 是小贼 |

### 3.3 光与可读性(塔内灯具)

- **画面上的光 = 玩法上的光**(Mark of the Ninja):灯光不能照进暗区(`ShadowZone`),否则玩家以为暗处被照亮了;
  看起来暗的地方必须真的是暗区。生成器可以像存档点那样检查:灯的光圈不碰暗区。
- 光有来源:灯管、灯泡、应急灯都画出灯具本身;光晕只是叠加在附近。
- 用光**引路**(El-Nasr):梯子口、出口、可拆的东西附近一盏灯;危险的地方不打「邀请」的光。
- 灯接在电路上:配电室断电时整片灯一起灭(和现有的 `FuseBox` 一致)。
- 每座塔一种灯:塔1 坏掉一半的走廊灯(破路后更暗)、塔2 管道上的锈红警示灯、塔3 荧光灯管(嗡鸣,和叙事脚本「灯管嗡鸣」对上)、
  塔4 惨白的探照灯 + 少量红色应急灯。

### 3.4 守卫的 2D 造型

- **剪影优先**:纯色剪影要认得出是「士兵」,而且和 Ryn 的剪影差很多(更高、更方、拿着东西)。
- **类型 = 配件**:巡逻(步枪)、扫视(头灯 / 望远镜)、哨兵(重甲、站桩)、技工(工具包、软帽)—— 剪影不同,玩家一眼知道这人会怎么动。
- **状态 = 姿势**(已有规则,沿用):起疑前倾侧耳 + 黄「?」;发现举枪 + 红「!」。
- **明度带**:守卫是中暗的钢蓝,背景是更暗的墨蓝砖;背光一圈 1px 冷青轮廓(TF2 的 rim light)。
- **视野锥从眼睛 / 手电出来**:锥的起点和画出来的护目镜、手电对齐,读起来「是他在看」。

## 4. 做法(Godot 4.6)

### 4.1 灯

| 做法 | 优点 | 缺点 |
|---|---|---|
| **叠加混合的光晕贴图**(`CanvasItemMaterial` 的 Add 模式 + 渐变贴图)**推荐** | 不改现有画面的颜色;便宜;和暗区规则完全分开 | 没有真实阴影 |
| `PointLight2D` + `CanvasModulate` | 真的照亮周围物体 | 要先把整个场景压暗,现有所有程序画的颜色都要重调;灯多了吃性能 |

闪烁:能量按低频噪声抖 5–15%,灯管偶尔断一下;旧屋的油灯慢慢呼吸。

### 4.2 守卫出图

| 做法 | 说明 |
|---|---|
| **A. 像素部件表**(和 Ryn 同一套管线)**推荐** | 先画一张守卫原图(像 `ryn_source.png`),切成部件,每帧整像素平移拼出所有动作。原图可以先由我按色板画像素,画师之后重画原图、重新出表即可 |
| B. 等画师画原图 | 质量最好,但要等(拥抱合影的插画还在画) |
| C. Godot 骨骼(`Skeleton2D` + `Polygon2D`) | 动作顺,但和 Ryn 的像素风格对不上 |
| D. 3D 转像素(Dead Cells) | 适合几十种敌人;本作只有一种守卫,不值得 |

守卫要的动作:待机呼吸、走、转身、扫视(左右看)、驻足、起疑(前倾侧耳)、发现(举枪)、跑去查看、拉开柜门、
摔下去(塔1 拆地板)、修电闸(技工)。

## 5. 待决定

1. 塔内的灯:只用冷光,还是破例放几支有故事的蜡烛(§2)。
2. 守卫造型方向(剪影对比图 `docs/polish-research-guards.png`:A 面罩头盔 / B 防毒面具 / C 军帽制服,
   和 Ryn 同一比例;只是剪影草稿,不是成品)。
   B 有一层剧情:守卫怕「蚀」所以戴面具,缓蚀者 Ryn 和 Vera 不用 —— 不说破,玩家自己看出来。
3. 守卫出图:我先画像素原图(A),还是等画师(B)。
4. 先做哪一包:旧屋精装 / 守卫造型 / 塔内灯具。
