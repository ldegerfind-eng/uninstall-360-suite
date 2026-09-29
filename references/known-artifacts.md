# 360 全家桶已知痕迹速查表（Windows）

> 用途：清理前对照识别、清理后逐项核对。**删除前务必确认对象确实属于 360**；历史命名的目录可能仍被其他软件使用。

## 1. 产品清单（应用面板中会出现的名称）

| 中文名 | 英文/别名 | 主程序 | 安装目录（典型） |
|---|---|---|---|
| 360安全卫士 | 360 Total Security | `360Safe.exe` / `360Tray.exe` | `C:\Program Files (x86)\360\360Safe` |
| 360杀毒 | 360 Antivirus | `360sd.exe` / `360rp.exe` | `C:\Program Files (x86)\360\360sd` |
| 360安全浏览器 | 360 Secure Browser | `360se.exe` | `C:\Users\<用户>\AppData\Roaming\360se6` 或 `C:\Program Files (x86)\360\360se6` |
| 360极速浏览器 | 360 Speed / Chrome Browser | `360Chrome.exe` | `C:\Users\<用户>\AppData\Local\360Chrome` |
| 360软件管家 | 360 Software Manager | `360SoftMgr.exe` | 随卫士安装 |
| 360安全大脑 | 360 Security Brain | — | — |
| 360压缩 | 360 Zip | `360zip.exe` | `C:\Program Files (x86)\360\360zip` |
| 360驱动大师 | 360 Driver Master | `360DrvMgr.exe` | — |
| 360（其他） | 任何 `360` 前缀程序 | — | — |

## 2. 残留目录（白名单，逐项判断）

```
C:\Program Files (x86)\360
C:\Program Files\360
%LOCALAPPDATA%\360
%APPDATA%\360
%APPDATA%\360safe                 <- 真机确认存在过
%USERPROFILE%\AppData\LocalLow\360
%LOCALAPPDATA%\360Chrome
%LOCALAPPDATA%\360se6
%APPDATA%\360se6
C:\ProgramData\360SD              <- 真机确认存在过（常为空目录）
C:\ProgramData\360safe
C:\Windows\System32\drivers\360*.sys
```

## 3. 进程（按前缀匹配 `360`）

`360se.exe`、`360Chrome.exe`、`360Safe.exe`、`360Tray.exe`、`360sd.exe`、`360rp.exe`、`360zip.exe`、`360SoftMgr.exe`、`360DrvMgr.exe`、其它以 `360` 开头的进程。

## 4. 服务

- 按 `^360` 匹配：`360Box64`、`360netmon` 等。
- 按 `^Q360` 匹配：真机出现过 **`Q360AMPPL`**（OCR 来源，名称易与 `Q369/Q368` 混淆，以实际扫描为准）。
- 查询：`Get-Service | Where-Object {$_.Name -match '360'}`

## 5. 内核驱动（关键难点）

| 驱动 | 类型 | 说明 |
|---|---|---|
| `360Box64.sys` | 内核驱动 / 服务 | 真机确认残留，删文件后需重启才彻底失效 |
| `360netmon.sys` | 网络监控驱动 | 真机确认残留 |
| `360FsFlt.sys` | **mini-filter**（文件系统过滤） | 挂载在 C:/D:/E: 卷，锁定被判定为威胁的文件 |
| `360AntiSteal.sys` | 内核驱动 | 反盗窃/自保护 |

**行为特征（真机实测）**：
- `fltmc detach` 报 `0x801f0010`；`sc stop` 报 `1052` 或永久卡在 `STOP_PENDING`。
- 驱动加载期间，即使管理员/SYSTEM 也无法删除或改名被保护的文件。
- **驱动文件删除 + 重启 = 彻底失效**（重启后系统找不到文件，无法加载，文件锁随之解除）。

查询命令：
```powershell
Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -match '360' } | Select Name,State,PathName
fltmc instances
fltmc filters
```

## 6. 注册表

**顶级厂商键（脚本白名单）**：
```
HKCU\Software\360
HKCU\Software\360Safe
HKLM\SOFTWARE\360
HKLM\SOFTWARE\360Safe
HKLM\SOFTWARE\WOW6432Node\360
HKLM\SOFTWARE\WOW6432Node\360Safe
```

**其他需人工确认的位置**：
```
卸载项：HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*（DisplayName 含 360）
       HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*
       HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*
启动项：HKCU/HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run (+WOW6432Node)
浏览器策略：HKLM/HKCU\SOFTWARE\Policies\Microsoft\Edge
           HKLM/HKCU\SOFTWARE\Policies\Microsoft\Chrome
右键菜单：见第 8 节
```

> ⚠️ **血的教训**：不要用宽泛子串（如 `360`）在 `HKCU\Classes` 等位置做批量递归删除——曾误删 Windows 自带的 AppContainer 映射、MrtCache、SID/GUID 项。**搜索可以，删除必须逐项确认。**

## 7. 计划任务

命名通常含 `360` 或厂商拼音缩写。查询：
```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -match '360' -or $_.TaskPath -match '360' }
```
删除：`Unregister-ScheduledTask -TaskName <名> -TaskPath <路径> -Confirm:$false`

管理界面入口：**此电脑（右键）→ 管理 → 任务计划程序 → 任务计划程序库**。

## 8. 右键菜单处理程序

```
HKCR\*\shellex\ContextMenuHandlers\<含 360 的项>
HKCR\Directory\shellex\ContextMenuHandlers\<...>
HKCR\Directory\Background\shellex\ContextMenuHandlers\<...>
HKCR\Folder\shellex\ContextMenuHandlers\<...>
HKCR\Drive\shellex\ContextMenuHandlers\<...>
HKLM\SOFTWARE\Classes\*\shellex\ContextMenuHandlers\<...>
HKLM\SOFTWARE\Classes\Directory\shellex\ContextMenuHandlers\<...>
HKLM\SOFTWARE\Classes\Folder\shellex\ContextMenuHandlers\<...>
```
判断依据：子键名或默认值含 `360`，且其指向的 DLL 已不存在或位于 360 目录。

## 9. 浏览器劫持位置（hao.360.com / www.360.cn）

| 位置 | 检查方式 |
|---|---|
| 快捷方式"目标"栏被追加 URL | 右键 .lnk → 属性 → 目标；正常应只有 exe 路径 |
| 浏览器策略注册表 | `HKLM/HKCU\SOFTWARE\Policies\Microsoft\{Edge,Chrome}` |
| 主页 / 启动页 | Chrome：设置→启动时 / 外观；Edge：`edge://settings/startHomeNTP` |
| 配置文件中残留 | `%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Preferences`（及 `Secure Preferences`、`Local State`） |
| 恶意扩展 | `edge://extensions` / `chrome://extensions`（警惕假冒"Flash Player"扩展） |
| DNS / hosts | hosts：`C:\Windows\System32\drivers\etc\hosts`；DNS 建议 `223.5.5.5` / `119.29.29.29` |

**关键区分**：Preferences 里的 `hao.360.com` 若只是**站点数据/访问历史**，那不是劫持设置，不影响使用，可在浏览器里"清除浏览数据"清掉。

## 10. 卸载器话术陷阱

360 卸载器会提供"修复""保留防护""仅卸载部分组件"等选项以阻止彻底卸载。**必须选"继续卸载 / 狠心卸载 / 彻底卸载"**。若不彻底，改用官方卸载程序或走"控制面板卸载 → 重启 → 残留清理"。

## 11. 真机案例记录（可作对照样本）

### 案例 A：某台 Windows 10/11 机器（2026-09）
- 起点：Chrome/Edge 主页被 `hao.360.com` 劫持。
- 侦察结果：**360 主程序已卸载**，但残留 **3 个 360 文件夹 + 1 个 360 服务（`Q360AMPPL`）+ 2 个内核驱动（`360Box64.sys`、`360netmon.sys`）**。
- 该机未安装 Chrome，默认浏览器为 Edge，Edge 首次检查"未发现劫持"。
- 无需管理员即可完成：删除 `AppData\Roaming\360safe`、删除 `HKCU\Software\360`。
- 需管理员：删除内核驱动、`Program Files (x86)\360`、HKLM 注册表。
- 处置：脚本删驱动文件 → **重启** → 驱动不再加载 → 收尾脚本删除服务项与空目录。
- 后续发现 Edge 主页仍指向 hao.360.com → 远程关闭 Edge、备份并处理 `Preferences`/`Secure Preferences`/`Local State`、清理 `Policies\Microsoft\Edge` → 恢复。
- 附带发现并删除：**假冒 "Microsoft Edge Flash Player" 扩展**（会向 4399.com 等注入内容，拥有全部 URL 权限）。
- 最终：服务、驱动、文件夹、注册表、进程、计划任务、启动项、浏览器劫持、扩展全部清零；仅剩 `C:\ProgramData\360SD` 空目录（后删除）。
- 备注：该机安装的是火绒（非 360），不受影响；hosts 中存在某公司终端管理软件的内部域名条目，**不属于 360，未改动**。

### 案例 B：另一台机器的 360 深度清理（2026-09）
- 360 自保护 mini-filter 驱动（`360Box64`/`360FsFlt`/`360AntiSteal`）导致文件无法删除，`fltmc detach` 与 `sc stop` 均失败。
- 重启后驱动卸载成功，但 `C:\Program Files (x86)\360` 仍为受保护空目录（TrustedInstaller 所有）→ 管理员 `takeown` + `icacls` + `rmdir` 清除。
- 隔离区中的顽固文件被该机杀软（火绒）内核层拦截，最终由**火绒自带"文件粉碎"**清除——印证"杀软拦截场景必须用杀软自身能力"。

## 12. 与其他安全软件共存注意事项

- 若装有火绒等第三方杀软：Windows Defender 的三个服务会处于 Stopped 状态（属正常，被第三方接管）。
- 杀软可能会**在内核层拦截**对已识别威胁文件的删除/改名，关防护开关无效 → 用杀软自身"文件粉碎 / 立即处理"，或加入信任区，或临时完全退出杀软。
- 清理前建议先退出 360 的全部界面与托盘程序；清理后再处理杀软的误报记录。
