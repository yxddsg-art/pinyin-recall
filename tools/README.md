# tools / 开发验证脚本

这些脚本用于在没有真人操作的情况下验证工具行为，需要 **Windows PowerShell 5.1**，并且工具已经在运行（托盘有图标）。

| 脚本 | 作用 |
|---|---|
| `端到端验证.ps1` | 自建真实可聚焦文本框，模拟"英文态输入拼音 → 全选 → 单按 Shift → 空格上屏"，打印结果与工具日志 |
| `安全测试-Shift加方向键.ps1` | 用 `Shift+方向键` 选中文字，验证工具不会误触发 |

## 用法

```powershell
# 基本转换
powershell -ExecutionPolicy Bypass -File .\tools\端到端验证.ps1 -LogPath ".\日志\运行日志.log"

# 换一段拼音 / 用数字选第 2 个候选
powershell -ExecutionPolicy Bypass -File .\tools\端到端验证.ps1 -Text "ni hao shi jie" -CommitKey 2 -LogPath ".\日志\运行日志.log"

# 安全测试
powershell -ExecutionPolicy Bypass -File .\tools\安全测试-Shift加方向键.ps1
```

## 注意

- 脚本会**强制把自建窗口提到前台**并发送真实按键，运行期间请不要操作键盘/鼠标。
- 脚本只操作自己创建的窗口，不会碰你已打开的程序（这一点在开发时踩过坑，见 `docs/兼容性与实现原理.md` 第四节）。
- 中文脚本必须是 UTF-8 with BOM，否则 PowerShell 5.1 会按 ANSI 解码导致解析错误。
