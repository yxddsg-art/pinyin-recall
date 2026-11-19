# Pinyin Recall (拼音选中回改)

> Typed a whole sentence of pinyin because the IME was in English mode? **Select it and tap `Shift` once** — it becomes Chinese candidates in place, pick with number keys or space. No IME switching.

Windows 10/11 · [AutoHotkey v2](https://www.autohotkey.com/) · no network, no window, no data leaves your machine.

## What it does

When your Chinese IME is in English mode, keystrokes produce raw pinyin. This tool takes the **selected pinyin**, re-feeds it into **your current IME**, and lets the IME produce its normal candidates — so ranking, personal dictionary and cloud candidates are identical to normal typing. You then choose with `1`–`9` / `Space` as usual.

## Download (portable, no install)

**👉 [Pinyin Recall v0.2 portable zip](https://github.com/yxddsg-art/pinyin-recall/releases/latest)** — unzip and double-click `双击这里启动.vbs` (AutoHotkey runtime bundled).

## Install

```powershell
powershell -ExecutionPolicy Bypass -File .\安装.ps1
# add -AutoStart to start with Windows
```

Or manually: download [AutoHotkey v2](https://www.autohotkey.com/download/ahk-v2.zip), put `AutoHotkey64.exe` into `bin\AutoHotkey\`, then run `拼音选中回改.ahk`.

## Usage

1. Type pinyin while the IME is in English mode (spaces / capitals / digits are fine)
2. Select the pinyin
3. Tap `Shift` once (no long press, no other key while holding)
4. Pick a candidate: `Space`/`Enter` commits the first, `1`–`9` picks others

Tray menu: pause/resume, diagnose current window, open config, open log, reload, exit.

## Compatibility

Requires a **full-pinyin** IME whose English/Chinese mode can be switched from the keyboard.

| IME | Status | Note |
|---|---|---|
| Microsoft Pinyin (default Shift toggle) | ✅ verified | Windows built-in |
| Sogou / WeChat / QQ Pinyin / Baidu | ✅ expected | Shift toggle by default |
| Rime Weasel (Shift to ASCII) | ✅ expected | full-pinyin scheme |
| Microsoft Pinyin with `Ctrl+Space` toggle | ⚙️ configure | set `ToggleKey=Ctrl+Space` in `设置.ini` |
| Separate keyboard layouts (EN layout + CN IME) | ⚙️ configure | `ToggleKey=Win+Space` or `Ctrl+Shift`, `RequiredLangId=0x0804` |
| Shuangpin (双拼) schemes | ❌ not applicable | replay feeds full pinyin letters |
| Wubi / shape-based IMEs | ❌ not applicable | replay feeds pinyin, not shape codes |

If candidates don't appear, use tray → **Diagnose current window** and attach the `IME探测[...]` log line to an issue.

## How it works

1. **Switch** — your `Shift` tap already puts most IMEs back into Chinese mode; if your toggle key differs, the tool sends `ToggleKey` itself.
2. **Read** — temporarily borrows the clipboard, `Ctrl+C`, validates the selection is pinyin (419 syllables + dynamic-programming segmentation, so English sentences are ignored), then restores your clipboard.
3. **Replay** — sends the pinyin letters back with a tunable key delay; the IME shows candidates and you pick one.

Only fires when it's a **single tap** (<320 ms, no other key during the hold, no Ctrl/Alt) **with a non-empty selection**, so `Shift+Arrow` text selection and `Shift+Click` never trigger it.

## Config (`设置.ini`)

| Key | Default | Meaning |
|---|---|---|
| `[trigger] Key` | `LShift` | trigger key |
| `[ime] ToggleKey` | `LShift` | your IME's CN/EN toggle, used when the tool needs to switch |
| `[ime] AssumeNative` | `1` | assume "already Chinese" when IME state can't be read |
| `[ime] RequiredLangId` | `0` | set `0x0804` if CN/EN are separate keyboard layouts |
| `[replay] PressMs` / `GapMs` | `22` / `26` | replay key timing |

## Limitations

- Elevation mismatch: elevated windows can't receive simulated keys unless this tool is also run elevated.
- Remote desktop / exclusive fullscreen games usually won't work.
- Reading the selection uses `Ctrl+C`; add terminal processes to `黑名单.txt` if that's a concern.
- Some legacy IMM32 controls ignore number keys for candidate selection after replay (Space/Enter still work).
- Full pinyin only (no Shuangpin/Wubi).

## License

MIT. AutoHotkey itself is GPL-2.0 and is downloaded separately by `安装.ps1`.
