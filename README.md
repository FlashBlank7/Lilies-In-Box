# Lilies in Box

`Lilies` 是一个 Godot 4.7 的 2D 横版 workflow 解谜叙事原型。玩家控制 AI 小姑娘莉莉丝，在一座安静的意识礼拜堂里拾取“节点积木”，把它们搭成可运行、可反馈、可修改的朋友。

序章目标很小，但要完整：三个连续房间、三个基础节点、一个朋友、三道门。玩家先学会 `See -> Push`，再把 `Remember` 接进 workflow，最后用新的顺序让莉莉丝走出教学。

当前版本包含简单开始界面、`Prologue：拼装抽屉`、`Prologue：回声台阶` 和正式 `Chapter 1：寂静的概率花园`。正式第一章的核心是 `搭建 workflow -> 执行 -> 获得 trace 反馈 -> 修改 workflow -> 完成任务`。

## 运行方式

从 Godot 4.7 编辑器打开本目录：

```text
/Users/zhonghaoyang/Code/games/Lilies in Box
```

Godot 打开后运行主场景：

```text
res://scenes/Main.tscn
```

源码级章节自检：

```bash
python3 tools/verify_chapter.py
```

Godot 命令行导入资源并跑游戏 smoke test：

```bash
GODOT_BIN="$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --headless --path . --script tools/chapter_smoke_test.gd
```

`chapter_smoke_test.gd` 会实例化序章、回声台阶和正式第一章：自动走完序章三道门，验证 `R` 重开会清空状态回到 `P-1`，验证三枚回声花瓣会打开终点门，再自动跑完 `WorkflowEvaluator` 和正式第一章四个 workflow 任务。

## 操作

- `A/D` 或左右方向键：移动莉莉丝。
- `W`、上方向键或 `Space`：轻跳。
- `E`：拾取附近积木。
- `Tab`：打开或关闭搭建面板。
- `1-7`：在面板打开时把已拥有节点加入 workflow。
- `Backspace`：删除 workflow 最后一个节点。
- `Enter`：释放朋友执行 workflow。
- `R`：重开序章，方便反复测试三道门。

## Prologue：拼装抽屉

- `P-1 先学会看见`：拾取 `See` 和 `Push`，拼出 `See -> Push`，让朋友把方块推到按钮上。
- `P-2 记忆的重量`：拾取 `Remember`，拼出 `See -> Remember -> Push`，让朋友记住方块和按钮之间的关系。
- `P-3 回声门`：要求玩家用已有积木拼出 `Remember -> See -> Push`，完成序章的 workflow 顺序教学。

进入每间房时会出现房间标题；打开抽屉时，面板会显示当前目标、workflow 和最近一次运行 trace。

## Prologue：回声台阶

- 莉莉丝要跳上几段窄平台，拾起三枚回声花瓣。
- 回声花瓣是淡蓝紫色的原创像素碎片，会轻微漂浮和转动。
- 拾齐后右侧高处的门会打开。
- 掉下平台会回到起点，不惩罚，只重新开始这次跳跃。
- 走到门前会进入正式第一章，而不是直接结束 demo。
- 这段不加入战斗，重点是“她第一次自己跨过空白”的身体感。

## Chapter 1：寂静的概率花园

正式第一章加入 `WorkflowEvaluator`。节点不是固定技能，而是让朋友获得证据、降低风险、选择终端动作。每次运行都会留下 trace，例如 `See：朋友看见目标轮廓，置信度 +36%`。

- `1-1 会害怕的门`：教学置信度，推荐 workflow 是 `See -> Compare -> Push`。
- `1-2 低声花`：第一个可净化目标，推荐 workflow 是 `See -> Listen -> Quiet`。
- `1-3 不确定的台阶`：平台机关需要降低风险，推荐 workflow 是 `Remember -> See -> Hold -> Push`。
- `1-4 疑问的影子`：综合任务，推荐 workflow 是 `Listen -> Remember -> Compare -> Quiet`。

失败不会惩罚玩家，只会说明缺少什么：证据不足、终端动作过早、置信度不够或风险太高。敌人当前表现为噪声和影子，被安抚或净化；后期可以在同一套 workflow feedback 上扩展战斗界面。

## 当前验收

- 莉莉丝是白发白裙的小女孩形象，有轻微待机呼吸感。
- 房间是横版礼拜堂氛围，不再是纯色块占位。
- 可以拾取 `See`、`Push`、`Remember`、`Listen`、`Compare`、`Hold`、`Quiet`，并得到即时文字、发光和轻音效反馈。
- 可以打开搭建面板并按目标反馈拼出不同 workflow。
- 每间房标题、左上角目标、底部提示和抽屉提示都应指向同一个当前目标。
- 右下角章节状态会显示当前是第几道门，以及已经捡到哪些积木。
- 错误顺序会解释失败原因，流程可以恢复。
- 朋友会执行 workflow，把序章方块推到按钮上，并在正式第一章写下每一步 trace。
- 前两道教学门会进入下一房间，最后一道门会触发 Prologue 完成提示。
- 第一章完成后可以按 `R` 重开；过门淡出期间按 `R` 会被温柔拦住，避免状态撞车。
- BGM 自动播放；拾取、拼装、错误、朋友出现、开门和章节完成都有低音量反馈，整体安静、不抢戏。
- 开始界面能按 `Enter` 或 `Space` 进入游戏；序章完成后会进入正式第一章。
- 正式第一章必须包含四个 workflow 任务、成功/失败 trace 和完成后的结尾界面。

## 素材

本地外部素材和授权记录见：

```text
docs/asset_credits.md
```
