# 拼音选中回改 · Pinyin Recall

> 输入法忘了切中文，打了一串拼音才发现？**选中它，单按一下 `Shift`** —— 拼音原地变成中文候选，数字选词、空格上屏，全程不用切输入法。

```
英文状态打出：   wo ming tian qu bei jing
选中它，按 Shift
得到候选：       1. 我明天去北京    2. …
```

适用 Windows 10/11，用 [AutoHotkey v2](https://www.autohotkey.com/) 写成，**不联网、不驻留窗口、不上传任何内容**。

## 它解决什么问题

中文输入法处于英文状态时，你打出的是一串拼音字母。传统做法是：删掉 → 切中文 → 重打。
本工具把这三步合成一步：**选中已打出的拼音 → 单按 `Shift`**。工具会把拼音"喂"回当前输入法，于是你得到和平时打字完全一样的中文候选（含你自己的词库、云候选、调频），然后照常数字选词/空格上屏。

核心思路不是"自己写一个拼音转汉字引擎"，而是**复用系统的输入法**——所以词库质量、多音字、联想能力都和你日常打字一致。

## 下载（免安装便携版）

不想折腾命令行？直接下载打包好的 zip：

**👉 [拼音选中回改 v0.2 便携版](https://github.com/yxddsg-art/pinyin-recall/releases/latest)**

解压后双击 `双击这里启动.vbs` 即可（zip 内已含 AutoHotkey 运行时，纯绿色、解压即用）。

> 部分杀毒软件可能对 AutoHotkey 运行时误报，可添加信任；或删除 `bin` 文件夹后运行 `安装.ps1` 从官网重新下载。

## 安装
**方式一：一键脚本（推荐）**

```powershell
# 在 PowerShell 中运行（会自动下载 AutoHotkey v2 便携版并创建快捷方式）
powershell -ExecutionPolicy Bypass -File .\安装.ps1
```

需要开机自启就加 `-AutoStart`：

```powershell
powershell -ExecutionPolicy Bypass -File .\安装.ps1 -AutoStart
```

**方式二：手动**

1. 下载 [AutoHotkey v2](https://www.autohotkey.com/download/ahk-v2.zip)，解压出 `AutoHotkey64.exe` 放到 `bin\AutoHotkey\`
2. 双击 `拼音选中回改.ahk`（或建个快捷方式，目标填 `AutoHotkey64.exe`，参数填脚本绝对路径）
3. 托盘出现图标即启动成功

## 开机自启 / 被关掉自动恢复

```powershell
powershell -ExecutionPolicy Bypass -File .\安装.ps1 -AutoStart
```

会注册计划任务 **「拼音回改-守护」**：登录时自动启动，之后**每 5 分钟自检一次**，进程不在了就静默拉起（无窗口、不打扰）。

> 为什么需要它：本工具是独立进程，DSH / 终端会话重启或手动关闭后不会自己回来。有了守护任务，重装/更新其他软件、重启电脑之后都不用再去手动双击。

管理：

```powershell
Get-ScheduledTask -TaskName '拼音回改-守护' | Select-Object TaskName, State   # 查看
Disable-ScheduledTask -TaskName '拼音回改-守护'                                # 暂停自检
Unregister-ScheduledTask -TaskName '拼音回改-守护' -Confirm:$false             # 彻底删除
```
## 使用

1. 在任意输入框里用英文状态打出拼音（空格/大小写/数字都没关系）
2. **选中这段拼音**
3. **单按一下 `Shift`**（不要长按，也不要按着 Shift 按别的键）
4. 出现中文候选后：`空格`/`回车` 上屏首选，`1`–`9` 选其它候选

托盘菜单：`暂停/启用`、`诊断当前窗口`、`打开设置.ini`、`打开日志`、`重新加载`、`退出`。

## 兼容性

> 本工具的原理是"**把拼音重新输入给当前输入法**"，所以要求：① 输入法是全拼方案；② 触发键能把你从英文状态切回中文。

| 输入法 | 预期可用性 | 说明 |
|---|---|---|
| 微软拼音（默认 Shift 切换） | ✅ 已验证 | Windows 10/11 自带，默认行为即符合 |
| 搜狗输入法 / 微信输入法 / QQ 拼音 / 百度输入法 | ✅ 预期可用 | 默认都是 Shift 切中英；关掉"按应用记住中英状态"更稳 |
| Rime 小狼毫（Shift 切 ASCII） | ✅ 预期可用 | 全拼方案 + 默认 Shift 切 ASCII 即可 |
| 微软拼音（Ctrl+Space 切换） | ⚙️ 需配置 | `设置.ini` 里 `ToggleKey=Ctrl+Space` |
| 中英是两套键盘布局（如美式键盘 + 中文输入法） | ⚙️ 需配置 | `ToggleKey=Win+Space` 或 `Ctrl+Shift`，`RequiredLangId=0x0804` |
| 双拼方案（小鹤/自然码等） | ❌ 不适用 | 回灌的是全拼字母串，双拼输入法会按声韵母键解析 → 乱码 |
| 五笔 / 形码输入法 | ❌ 不适用 | 回灌的是拼音字母，不是字根编码 |

遇到候选不对/不出候选时，先点托盘 → **诊断当前窗口**，把日志里那行 `IME探测[...]` 发到 Issue。

## 原理（三步）

1. **切换**：你按下的 `Shift` 本身就让输入法从英文切回中文（多数输入法默认如此）；若输入法切换键不是 Shift，工具会用 `ToggleKey` 补发一次。
2. **读取**：工具临时占用剪贴板，`Ctrl+C` 读出选中文本，校验它是拼音（内置 419 个音节 + 动态规划切分，所以 `hello world` 这种英文句子不会被误转），读完恢复你原来的剪贴板。
3. **回灌**：把拼音字母逐个按键发送给输入法（带可调延迟，避免吃键丢失）→ 输入法弹出候选，你数字选词/空格上屏。

安全防护：只有在「**单按**触发键、按住 <320ms、期间没有按其它键、没有 Ctrl/Alt、且当前有非空选区」时才会动作——所以 `Shift+方向键` 选字、`Shift+点击` 选字都不会被误触发。

## 设置项（`设置.ini`）

改完在托盘菜单点「重新加载」生效。

| 配置项 | 默认 | 说明 |
|---|---|---|
| `[trigger] Key` | `LShift` | 触发键：`LShift` / `RShift` |
| `[trigger] HoldMaxMs` | `320` | 按住超过这么久不触发（防长按） |
| `[trigger] SettleMs` | `180` | 抬起后等输入法切完的时间 |
| `[ime] ToggleKey` | `LShift` | 你输入法的"中英切换键"，用于工具补切。可用 `LShift` / `RShift` / `Ctrl+Space` / `Ctrl+Shift` / `Win+Space` / `Ctrl` / 任意 AHK 按键表达式 |
| `[ime] AssumeNative` | `1` | 读不到输入法状态时，是否假定"已经切回中文"（Shift 类输入法保持 1） |
| `[ime] RequiredLangId` | `0` | 中英是两套键盘布局时填 `0x0804`（简体中文）；同输入法内切换保持 0 |
| `[replay] PressMs` / `GapMs` | `22` / `26` | 回灌每个字母的按下时长 / 间隔。某程序吃键慢就加大 |
| `[ui] TipErrors` | `1` | 出错时鼠标旁弹提示 |

另有 `黑名单.txt`：每行一个进程名（如 `photoshop.exe`），这些程序里不会触发。

## 已知限制

- **管理员权限窗口**（以管理员身份运行的程序）收不到普通权限进程的模拟按键 → 需要把本工具也用管理员身份运行。
- 远程桌面、独占全屏游戏里通常无效。
- 读选区用 `Ctrl+C`：终端里正在跑程序时按 `Ctrl+C` 会发中断信号，建议把终端进程加入 `黑名单.txt`。
- 极少数老式 IMM32 控件里，回灌后的**数字选候选**不生效（用空格/回车仍可上屏）。
- 每次转换耗时约 1–3 秒（拼音越长越久），期间触发键不响应。
- 只处理全拼；双拼/五笔的输入法不适用（见上表）。

## 开发与验证

`tools/` 里是开发期用的验证脚本（Windows PowerShell 5.1）：

- `端到端验证.ps1`：自建一个真实可聚焦的文本框，模拟"英文态输入拼音 → 全选 → 单按 Shift → 空格上屏"，打印结果并带出工具日志
- `安全测试-Shift加方向键.ps1`：验证 `Shift+方向键` 选字不会被误触发

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\端到端验证.ps1 -Text "wo ming tian qu bei jing" -LogPath ".\日志\运行日志.log"
```

维护者打包：`powershell -ExecutionPolicy Bypass -File .\打包发布.ps1` 生成 `dist\拼音选中回改-v0.2.zip`（含运行时与无窗口启动器）。

## 常见问题

**Q：候选里没有我要的词？**
A：这是系统输入法的候选；多打几次或手动选一次，输入法会自己调频。工具不干预候选。

**Q：按了 Shift 但没反应？**
A：① 确认选中了文本；② 确认是在输入框里（有闪烁光标）；③ 看日志最后一行（托盘 → 打开日志）；④ 托盘 → 诊断当前窗口，把结果贴 Issue。

**Q：我的输入法不是 Shift 切换怎么办？**
A：改 `设置.ini`：`ToggleKey` 填你的切换键（如 `Ctrl+Space`）。物理按键仍用 Shift 触发，工具会在需要时补发你配置的切换键。

## License

MIT（见 [LICENSE](LICENSE)）。脚本不包含 AutoHotkey 运行时；`安装.ps1` 会从官网下载，AutoHotkey 本身使用 GPL-2.0 许可。
