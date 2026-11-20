#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; ============================================================
;  拼音选中回改 v0.2
;  用途：输入法处于英文状态时打了一串拼音，选中它，单按一下触发键（默认 Shift），
;        工具把拼音重新"喂"回当前中文输入法 → 弹出中文候选（数字选/空格上屏）。
;  原理：触发键本身会切换中英（或由工具补发切换键）→ 读选区 → 回灌字母 → 输入法出候选。
;  通用性：全拼方案 + 任意"英文状态下可切回中文"的输入法（微软拼音/搜狗/微信/QQ拼音/Rime…）。
;  只依赖本机输入法，不联网、不开窗口、不上传任何内容。
; ============================================================

; ---------------- 默认参数（可用 设置.ini 覆盖） ----------------
CFG_TRIGGER   := "LShift"   ; 触发键：LShift / RShift（不建议单键字母）
CFG_HOLD_MAX  := 320        ; 按下超过这么久不触发（防长按）
CFG_SETTLE    := 180        ; 抬起后等输入法切完再动作(ms)
CFG_TOGGLE    := "LShift"   ; 输入法的"中英切换键"：LShift/RShift/Ctrl+Space/Ctrl+Shift/Win+Space/自定义AHK表达式
CFG_ASSUME    := true       ; 读不到输入法状态时，假定触发键已把输入法切到中文
CFG_REQLANG   := 0          ; 需要中文键盘布局时填 0x0804，0=不检查（"中英是两套键盘布局"的用户用）
CFG_PRESS     := 22         ; 回灌每个字母按下时长(ms)
CFG_GAP       := 26         ; 回灌字母之间间隔(ms)
CFG_TIP       := true       ; 出错时鼠标旁弹一行提示
; 这些编辑器"没有选区时 Ctrl+C = 复制整行并选中该行"。读到非拼音时用 Esc 把误选中清掉。
; 默认 JetBrains 全家桶；用逗号分隔，可自行增加。
CFG_LINECOPY  := "pycharm64.exe,idea64.exe,webstorm64.exe,goland64.exe,clion64.exe,rider64.exe,datagrip64.exe,phpstorm64.exe,rubymine64.exe,studio64.exe"
CFG_BLACKLIST := ["mstsc.exe", "rdpclip.exe", "vmware-vmx.exe"]
CFG_BLFILE    := A_ScriptDir "\黑名单.txt"
CFG_FILE      := A_ScriptDir "\设置.ini"

; ---------------- 常量 ----------------
LOG_DIR  := A_ScriptDir "\日志"
LOG_FILE := LOG_DIR "\运行日志.log"
SYL_TEXT := "a ai an ang ao ba bai ban bang bao bei ben beng bi bian biang biao bie bin bing bo bong bu ca cai can cang cao ce cei cen ceng cha chai chan chang chao che chen cheng chi chong chou chu chua chuai chuan chuang chui chun chuo ci cong cou cu cuan cui cun cuo da dai dan dang dao de den deng di dian diao die din ding diu dong dou du duan dui dun duo e ei en eng er fa fan fang fei fen feng fiao fo fou fu ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo ha hai han hang hao he hei hen heng hm hng hong hou hu hua huai huan huang hui hun huo ji jia jian jiang jiao jie jin jing jiong jiu ju juan jue jun ka kai kan kang kao ke ken keng kong kou ku kua kuai kuan kuang kui kun kuo la lai lan lang lao le lei leng li lia lian liang liao lie lin ling liu lo long lou lu luan lue lun luo lv lve m ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu n na nai nan nang nao ne nei nen neng ng ni nian niang niao nie nin ning niu nong nou nu nuan nue nun nuo nv nve o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun ran rang rao re ren reng ri rong rou ru rua ruan rui run ruo sa sai san sang sao se sen seng sha shai shan shang shao she shen sheng shi shou shu shua shuai shuan shuang shui shun shuo si song sou su suan sui sun suo ta tai tan tang tao te teng ti tian tiao tie ting tong tou tu tuan tui tun tuo wa wai wan wang wei wen weng wo wong wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun ya yan yang yao ye yi yin ying yo yong you yu yuan yue yun za zai zan zang zao ze zei zen zeng zha zhai zhan zhang zhao zhe zhen zheng zhi zhong zhou zhu zhua zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo"

; ---------------- 全局状态 ----------------
global g_busy := false
global g_paused := false
global g_triggerDown := 0
global g_otherKey := false
global g_mouseDuring := false
global g_savedClip := ""
global g_hasClip := false
global g_syl := Map()
global g_blackExtra := Map()
global g_convDebug := ""
global g_lineCopyApps := Map()

DirCreate LOG_DIR
LoadConfig()
BuildLineCopyMap(CFG_LINECOPY)
Log("===== 启动 v0.2.3 =====")
Log("触发键=" CFG_TRIGGER " | 切换键=" CFG_TOGGLE " | 假定中文=" CFG_ASSUME " | 要求语言=" (CFG_REQLANG ? Format("{:#x}", CFG_REQLANG) : "不检查"))
BuildSyllables(SYL_TEXT)
LoadBlacklistFile()
RegisterHotkeys()

; ================= 配置读取 =================
LoadConfig() {
    global CFG_FILE
    if !FileExist(CFG_FILE)
        return
    global CFG_TRIGGER, CFG_HOLD_MAX, CFG_SETTLE, CFG_TOGGLE, CFG_ASSUME, CFG_REQLANG, CFG_PRESS, CFG_GAP, CFG_TIP, CFG_LINECOPY
    try {
        v := Trim(IniRead(CFG_FILE, "trigger", "Key", CFG_TRIGGER))
        if (v != "")
            CFG_TRIGGER := v
        CFG_HOLD_MAX := Number(IniRead(CFG_FILE, "trigger", "HoldMaxMs", CFG_HOLD_MAX))
        CFG_SETTLE := Number(IniRead(CFG_FILE, "trigger", "SettleMs", CFG_SETTLE))
        v := Trim(IniRead(CFG_FILE, "ime", "ToggleKey", CFG_TOGGLE))
        if (v != "")
            CFG_TOGGLE := v
        CFG_ASSUME := IniRead(CFG_FILE, "ime", "AssumeNative", CFG_ASSUME ? 1 : 0) = 1
        langStr := Trim(IniRead(CFG_FILE, "ime", "RequiredLangId", CFG_REQLANG ? Format("{:#x}", CFG_REQLANG) : "0"))
        CFG_REQLANG := (SubStr(langStr, 1, 2) = "0x" || SubStr(langStr, 1, 2) = "0X") ? Integer("0x" SubStr(langStr, 3)) : Number(langStr)
        CFG_PRESS := Number(IniRead(CFG_FILE, "replay", "PressMs", CFG_PRESS))
        CFG_GAP := Number(IniRead(CFG_FILE, "replay", "GapMs", CFG_GAP))
        CFG_TIP := IniRead(CFG_FILE, "ui", "TipErrors", CFG_TIP ? 1 : 0) = 1
        v := Trim(IniRead(CFG_FILE, "apps", "LineCopyApps", CFG_LINECOPY))
        if (v != "")
            CFG_LINECOPY := v
    } catch as e {
        Log("读设置.ini 失败，使用默认值: " e.Message)
    }
}

; ================= 热键注册 =================
RegisterHotkeys() {
    global CFG_TRIGGER
    Hotkey("~" CFG_TRIGGER, OnTriggerDown)
    Hotkey("~" CFG_TRIGGER " Up", OnTriggerUp)

    ; 记录"触发键按住期间是否按过其它键"，用于区分 单按 与 Shift+方向键/Shift+点击
    keyList := "a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z"
             . ",0,1,2,3,4,5,6,7,8,9"
             . ",Space,Enter,Tab,Backspace,Delete,Escape"
             . ",Left,Right,Up,Down,Home,End,PgUp,PgDn"
    ; 不要给鼠标键注册热键：全局鼠标钩子会插进点击链路，部分系统上会让任务栏"点击激活窗口"失效。
    ; 改为 WatchMouse 定时采样（同样能识别 Shift+点击）。
    for k in StrSplit(keyList, ",")
        Hotkey("~*" k, TrackOtherKey)
    return true
}

OnTriggerDown(*) {
    global g_triggerDown, g_otherKey, g_busy, g_mouseDuring
    if (g_busy)
        return
    g_triggerDown := A_TickCount
    g_otherKey := false
    g_mouseDuring := false
    SetTimer(WatchMouse, 20)
}

OnTriggerUp(*) {
    global g_triggerDown, g_otherKey, g_busy, g_paused, CFG_HOLD_MAX, CFG_TRIGGER, g_mouseDuring
    SetTimer(WatchMouse, 0)
    if (g_busy || g_paused)
        return
    held := A_TickCount - g_triggerDown
    if (held > CFG_HOLD_MAX)
        return
    if (g_otherKey || g_mouseDuring)
        return
    if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P"))
        return
    if (CFG_TRIGGER = "LShift" && GetKeyState("RShift", "P"))
        return
    if (CFG_TRIGGER = "RShift" && GetKeyState("LShift", "P"))
        return
    g_busy := true
    SetTimer(DoConvert, -10)
}

TrackOtherKey(*) {
    global g_otherKey, g_busy
    if (g_busy)
        return
    if (GetKeyState("LShift", "P") || GetKeyState("RShift", "P"))
        g_otherKey := true
}

; 触发键按住期间是否点过鼠标（不挂鼠标钩子，改用采样）
WatchMouse() {
    global g_mouseDuring
    if (GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P"))
        g_mouseDuring := true
}

; JetBrains 系编辑器：无选区时 Ctrl+C 会"复制整行并选中该行"。
; 读到非拼音/空内容时，发 Esc 把误选中清掉（Esc 不会移动光标）。
CleanupLineSelection(proc) {
    global g_lineCopyApps
    if !g_lineCopyApps.Has(proc)
        return
    Send("{Esc}")
    Sleep 70
    Log("已清理整行误选中(Esc): " proc)
}

BuildLineCopyMap(text) {
    global g_lineCopyApps
    for item in StrSplit(RegExReplace(text, "\s+", ""), ",")
        if (item != "")
            g_lineCopyApps[StrLower(item)] := true
}

; ================= 主流程 =================
DoConvert() {
    global g_busy, g_paused, CFG_SETTLE, CFG_PRESS, CFG_GAP, CFG_ASSUME, CFG_TIP, CFG_REQLANG
    try {
        if (g_paused)
            return
        t0 := A_TickCount
        proc := ""
        try proc := StrLower(ProcessGetName(WinGetPID("A")))
        catch
            proc := ""
        if IsBlacklisted(proc) {
            Log("跳过·黑名单: " proc)
            return
        }

        ; 1) 读选区（剪贴板哨兵）
        sel := ReadSelection()
        if (sel = "") {
            CleanupLineSelection(proc)
            Log("跳过·读不到选区: " proc)
            return
        }

        ; 2) 必须是拼音
        pinyin := NormalizePinyin(sel)
        if (pinyin = "") {
            CleanupLineSelection(proc)
            Log("跳过·不是拼音: " proc " | " Abbrev(sel))
            if CFG_TIP
                Tip("选区不像拼音，已忽略")
            return
        }

        ; 3) 等输入法完成切换，并确认现在确实是中文态
        Sleep CFG_SETTLE

        ; 3a) 可选：中英是两套键盘布局的用户
        if (CFG_REQLANG) {
            lang := GetFgLangId()
            if (lang && lang != CFG_REQLANG) {
                Log("当前键盘语言=" Format("{:#x}", lang) " 需要=" Format("{:#x}", CFG_REQLANG) "，补切")
                SendToggle()
                Sleep 300
                if (GetFgLangId() != CFG_REQLANG) {
                    Log("切换键盘语言失败")
                    if CFG_TIP
                        Tip("没能切到中文键盘，请检查 设置.ini 的 ToggleKey")
                    return
                }
            }
        }

        ; 3b) 中英是同一输入法内两种状态（大多数情况）
        state := GetConvStatus()
        Log("IME探测[" g_convDebug "] -> " state " | " proc)
        if (state = -1) {
            Log("输入法状态读不到（TSF/无 IMM 窗口），按 AssumeNative 继续: " proc)
            if !CFG_ASSUME {
                if CFG_TIP
                    Tip("读不到输入法状态，已跳过（可改 设置.ini: AssumeNative=1）")
                return
            }
        } else if !(state & 1) {
            Log("当前英文态，补切: " proc)
            SendToggle()
            state := GetConvStatus()
            if (state != -1 && !(state & 1)) {
                if !ForceNative() {
                    Log("切中文失败: conv=" state)
                    if CFG_TIP
                        Tip("没切到中文：检查 设置.ini 的 ToggleKey 是否等于你输入法的中英切换键")
                    return
                }
            }
        }

        ; 4) 回灌拼音字母（去空格，交给输入法分词）
        SendMode("Event")
        SetKeyDelay(CFG_GAP, CFG_PRESS)
        Send(pinyin)
        SetKeyDelay(-1, -1)
        SendMode("Input")

        Log("转换OK: " proc " | '" Abbrev(sel) "' -> 回灌" StrLen(pinyin) "字母 | " (A_TickCount - t0) "ms")
    } catch as e {
        Log("异常: " e.Message " @ " e.What " line " e.Line)
        if CFG_TIP
            Tip("拼音回改出错，详见日志")
    } finally {
        RestoreClip()
        g_busy := false
    }
}

; 发送"输入法中英切换键"
SendToggle() {
    global CFG_TOGGLE
    t := StrLower(Trim(CFG_TOGGLE))
    if (t = "lshift") {
        Send("{LShift down}")
        Sleep 35
        Send("{LShift up}")
    } else if (t = "rshift") {
        Send("{RShift down}")
        Sleep 35
        Send("{RShift up}")
    } else if (t = "ctrl+space") {
        Send("{Ctrl down}{Space}{Ctrl up}")
    } else if (t = "ctrl+shift") {
        Send("{Ctrl down}{Shift down}{Shift up}{Ctrl up}")
    } else if (t = "win+space") {
        Send("#{Space}")
    } else if (t = "ctrl") {
        Send("{Ctrl down}")
        Sleep 40
        Send("{Ctrl up}")
    } else {
        ; 其它：当作 AHK 按键表达式直接发，例如 "{Alt down}{Shift}{Alt up}"
        Send(t)
    }
    Sleep 240
}

; ================= 选区 =================
ReadSelection() {
    global g_savedClip, g_hasClip
    g_savedClip := ClipboardAll()
    g_hasClip := true
    sentinel := "PINYINRECALL_" . A_TickCount . "_" . Random(100000, 999999)
    A_Clipboard := sentinel
    Sleep 25
    Send "^c"
    got := ""
    start := A_TickCount
    while (A_TickCount - start < 800) {
        Sleep 15
        cur := A_Clipboard
        if (cur != sentinel) {
            got := cur
            break
        }
    }
    return got
}

RestoreClip() {
    global g_savedClip, g_hasClip
    if (g_hasClip) {
        try A_Clipboard := g_savedClip
        catch
            Log("恢复剪贴板失败")
        g_hasClip := false
        g_savedClip := ""
    }
}

; ================= 拼音判定 =================
NormalizePinyin(raw) {
    global g_syl
    s := StrLower(Trim(raw))
    s := RegExReplace(s, "['’·\-_,.;:!?()\[\]/\\|，。；：！？、（）【】《》]", " ")
    s := RegExReplace(s, "[0-9]", "")
    s := RegExReplace(s, "\s+", " ")
    s := Trim(s)
    if (s = "")
        return ""
    if !RegExMatch(s, "^[a-z ]+$")
        return ""
    letters := RegExReplace(s, "[^a-z]", "")
    n := StrLen(letters)
    if (n < 2 || n > 64)
        return ""
    tokens := StrSplit(s, " ")
    if (tokens.Length = 1) {
        if !Segmentable(tokens[1])
            return ""
    } else {
        for t in tokens
            if !IsSyllable(t)
                return ""
    }
    return letters
}

IsSyllable(s) {
    global g_syl
    return (StrLen(s) >= 1 && StrLen(s) <= 6 && g_syl.Has(s))
}

Segmentable(word) {
    n := StrLen(word)
    if (n < 2 || n > 48)
        return false
    dp := []
    Loop n + 1
        dp.Push(false)
    dp[n + 1] := true
    i := n
    while (i >= 1) {
        maxLen := Min(6, n - i + 1)
        L := 1
        while (L <= maxLen) {
            sub := SubStr(word, i, L)
            if (IsSyllable(sub) && dp[i + L]) {
                dp[i] := true
                break
            }
            L++
        }
        i--
    }
    return dp[1]
}

BuildSyllables(text) {
    global g_syl
    for item in StrSplit(RegExReplace(text, "\s+", " "), " ")
        if (item != "")
            g_syl[item] := true
    for item in StrSplit("ng hm hng m n er yo lo", " ")
        g_syl[item] := true
}

; ================= 输入法状态 =================
GetFocusHwnd() {
    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if !hwnd
        return 0
    pid := 0
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid, "UInt")
    buf := Buffer(72, 0)
    NumPut("UInt", 72, buf, 0)
    if !DllCall("GetGUIThreadInfo", "UInt", tid, "Ptr", buf)
        return 0
    return NumGet(buf, 16, "Ptr")
}

; 当前前台线程的键盘布局语言 ID（0x0804=简体中文，0x0409=英文）
GetFgLangId() {
    fg := DllCall("GetForegroundWindow", "Ptr")
    if !fg
        return 0
    pid := 0
    tid := DllCall("GetWindowThreadProcessId", "Ptr", fg, "UInt*", &pid, "UInt")
    if !tid
        return 0
    hkl := DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
    return hkl & 0xFFFF
}

; 返回 conversion status；-1 = 读不到。低位 bit(0x1)=中文态
GetConvStatus() {
    global g_convDebug
    ; 方法 A：默认 IME 窗口 + WM_IME_CONTROL（跨进程安全，带超时）
    a := QueryConvByImeWindow(DllCall("GetForegroundWindow", "Ptr"))
    if (a = -1) {
        fh := GetFocusHwnd()
        if (fh)
            a := QueryConvByImeWindow(fh)
    }
    if (a != -1) {
        g_convDebug := "imewnd=" a
        return a
    }
    ; 方法 B：AttachThreadInput 后取 IMC（部分老式应用只有这个能用）
    b := QueryConvByAttach(GetFocusHwnd())
    g_convDebug := "imewnd=-1 attach=" b
    return b
}

QueryConvByImeWindow(hwnd) {
    if !hwnd
        return -1
    imeWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !imeWnd
        return -1
    res := 0
    ok := DllCall("user32\SendMessageTimeout", "Ptr", imeWnd, "UInt", 0x0283
                , "Ptr", 0x0001, "Ptr", 0, "UInt", 0x2, "UInt", 400, "UPtr*", &res)
    if !ok
        return -1
    return res
}

QueryConvByAttach(focus) {
    if !focus
        return -1
    fg := DllCall("GetForegroundWindow", "Ptr")
    if !fg
        return -1
    pid := 0
    tid := DllCall("GetWindowThreadProcessId", "Ptr", fg, "UInt*", &pid, "UInt")
    if !tid
        return -1
    myTid := DllCall("kernel32\GetCurrentThreadId", "UInt")
    attached := DllCall("user32\AttachThreadInput", "UInt", myTid, "UInt", tid, "Int", 1)
    conv := -1
    hIMC := DllCall("imm32\ImmGetContext", "Ptr", focus, "Ptr")
    if (hIMC) {
        c := 0, sent := 0
        if DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "Int*", &c, "Int*", &sent)
            conv := c
        DllCall("imm32\ImmReleaseContext", "Ptr", focus, "Ptr", hIMC)
    }
    if attached
        DllCall("user32\AttachThreadInput", "UInt", myTid, "UInt", tid, "Int", 0)
    return conv
}

ForceNative() {
    focus := GetFocusHwnd()
    if !focus
        return false
    hIMC := DllCall("imm32\ImmGetContext", "Ptr", focus, "Ptr")
    if !hIMC
        return false
    conv := 0, sent := 0
    DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "Int*", &conv, "Int*", &sent)
    ok := DllCall("imm32\ImmSetConversionStatus", "Ptr", hIMC, "Int", conv | 1, "Int", sent)
    DllCall("imm32\ImmReleaseContext", "Ptr", focus, "Ptr", hIMC)
    Sleep 80
    st := GetConvStatus()
    return (ok && st != -1 && (st & 1))
}

IsBlacklisted(proc) {
    global CFG_BLACKLIST, g_blackExtra
    if (proc = "")
        return false
    for item in CFG_BLACKLIST
        if (proc = item)
            return true
    return g_blackExtra.Has(proc)
}

LoadBlacklistFile() {
    global CFG_BLFILE, g_blackExtra
    if !FileExist(CFG_BLFILE)
        return
    try {
        for line in StrSplit(FileRead(CFG_BLFILE, "UTF-8"), "`n") {
            line := Trim(StrReplace(line, "`r", ""))
            if (line = "" || SubStr(line, 1, 1) = "#")
                continue
            g_blackExtra[StrLower(line)] := true
        }
    } catch
        Log("读黑名单失败")
}

; ================= 诊断 =================
Diagnose(*) {
    proc := ""
    try proc := StrLower(ProcessGetName(WinGetPID("A")))
    catch
        proc := "?"
    fg := DllCall("GetForegroundWindow", "Ptr")
    focus := GetFocusHwnd()
    ime1 := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", fg, "Ptr")
    ime2 := focus ? DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", focus, "Ptr") : 0
    a := QueryConvByImeWindow(fg)
    b := QueryConvByAttach(focus)
    lang := GetFgLangId()
    st := GetConvStatus()
    msg := "前台进程: " proc "`n"
        . "前台窗口: " fg "  焦点: " focus "`n"
        . "IME窗口(前台/焦点): " ime1 " / " ime2 "`n"
        . "状态·方法A(IME窗口): " (a = -1 ? "读不到" : a) "`n"
        . "状态·方法B(Attach+IMC): " (b = -1 ? "读不到" : b) "`n"
        . "综合判定: " (st = -1 ? "读不到（走 AssumeNative）" : ((st & 1) ? "中文态" : "英文态")) "`n"
        . "键盘语言: " (lang ? Format("{:#x}", lang) : "?") "`n"
        . "触发键: " CFG_TRIGGER "   切换键: " CFG_TOGGLE
    Log("[诊断] " StrReplace(msg, "`n", " | "))
    ToolTip(msg)
    SetTimer(() => ToolTip(), -6000)
}

; ================= 杂项 =================
Abbrev(s) {
    s := StrReplace(s, "`r", " ")
    s := StrReplace(s, "`n", " ")
    if (StrLen(s) > 40)
        return SubStr(s, 1, 40) "…"
    return s
}

Log(msg) {
    global LOG_FILE
    try FileAppend(FormatTime("", "yyyy-MM-dd HH:mm:ss") "  " msg "`n", LOG_FILE, "UTF-8")
}

Tip(msg, ms := 1800) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -ms)
}

TogglePause(*) {
    global g_paused
    g_paused := !g_paused
    if (g_paused)
        Tip("拼音回改：已暂停")
    else
        Tip("拼音回改：已启用")
}

OpenConfig(*) {
    global CFG_FILE
    if FileExist(CFG_FILE)
        Run('notepad.exe "' CFG_FILE '"')
    else
        Tip("没有 设置.ini，全部使用内置默认值")
}

; ================= 托盘 =================
A_IconTip := "拼音选中回改 · 选中拼音单按 " CFG_TRIGGER " 转中文"
A_TrayMenu.Delete()
A_TrayMenu.Add("暂停 / 启用", TogglePause)
A_TrayMenu.Add("诊断当前窗口", Diagnose)
A_TrayMenu.Add("打开设置.ini", OpenConfig)
A_TrayMenu.Add("打开日志", (*) => Run('notepad.exe "' A_ScriptDir '\日志\运行日志.log"'))
A_TrayMenu.Add("重新加载", (*) => Reload())
A_TrayMenu.Add()
A_TrayMenu.Add("退出", (*) => ExitApp())
A_TrayMenu.Default := "暂停 / 启用"

Log("已注册触发键: " CFG_TRIGGER)
