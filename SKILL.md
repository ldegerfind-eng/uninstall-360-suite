---
name: uninstall-360-suite
description: 在 Windows 上彻底卸载 360 全家桶（360安全卫士、360杀毒、360安全浏览器、360极速浏览器、360软件管家、360安全大脑、360压缩等），并修复被 360 劫持的浏览器主页（hao.360.com / www.360.cn / 360导航），清理残留进程、服务、内核驱动、文件夹、注册表项、开机启动项、计划任务、右键菜单与浏览器扩展。当用户提出「卸载 360 / 删除 360 / 清除 360 残留 / 360 卸载不干净 / 360 删不掉 / 浏览器主页被改成 360 导航 / hao.360.com 劫持 / 恢复浏览器主页」等诉求时触发；也可复用于同类国产安全套件的清理（替换清单即可）。
agent_created: true
---

# 彻底卸载 360 全家桶（Windows）

## 概述

本 Skill 整理了真机处理经历与配套脚本：从**浏览器劫持检查**开始，依次完成**进程/服务/内核驱动处置 → 官方与面板卸载 → 文件/注册表残留清理 → 启动项/计划任务/右键菜单逐项复核 → 重启或安全模式处理被占用组件 → 多轮验证**。配套脚本尚需在不同电脑上逐项验证，执行前必须看预览结果。

360 的卸载难点不在"卸载"本身，而在三处：
1. **自保护内核驱动**（360Box64 / 360netmon / 360FsFlt / 360AntiSteal）会在卸载后残留，锁住文件与目录，普通权限甚至管理员权限都删不动。
2. **卸载器会诱导"修复/保留"**，实际不删除核心组件。
3. **浏览器劫持**（主页/启动页/快捷方式参数/策略注册表）在卸载后依然存在，用户会误以为"没删干净"。

本 Skill 的所有操作路径、界面入口均来自真机实操记录，未臆造不存在的按钮。

## 适用范围

**适用**：Windows 10 / 11 上卸载 360 系列软件、清除其残留、修复被其劫持的浏览器。
**不适用**：非 360 的其他安全软件残留（可参考本流程改写白名单）；企业统一管控环境下被管理员策略锁定的软件（需联系 IT）。

## 安全前置（必读，先做完再动手）

| 前置项 | 要求 | 说明 |
|---|---|---|
| 权限 | **管理员**（右键程序 →「以管理员身份运行」） | 结束服务、删除驱动、清理 Program Files 与 HKLM 注册表都必须管理员 |
| 系统还原点 | 强烈建议先创建 | 命令：`Checkpoint-Computer -Description "before-360-removal"`；若提示未启用，先运行 `SystemPropertiesProtection.exe` 打开"系统保护"为 C 盘启用 |
| 注册表备份 | 改注册表前**必须**导出 | 在 regedit 中选中要删除的键 → 右键 →「导出」，或 `reg export <键路径> <备份文件.reg>` |
| 杀软协同 | 注意本机杀软 | 若装有第三方杀软（如火绒），它可能在内核层拦截对已识别威胁文件的删除（关防护开关无效），需改用杀软自带"文件粉碎"或临时完全退出 |
| 数据安全 | 先侦察再删除 | 先跑 Phase 0 只读侦察，确认目标确实属于 360，避免误删同名目录 |

**风险分级**：

- 🟢 低风险：查看进程/服务/目录、运行只读侦察脚本、浏览器设置里改主页。
- 🟡 中风险：结束进程、停止服务、禁用启动项、删除浏览器配置文件（会丢浏览器本地设置，需重登）。
- 🔴 高风险：删除 Program Files / ProgramData / 系统目录下的文件夹、删除注册表项、删除内核驱动与服务、强制取得所有权。**每一项都必须先备份或创建还原点。**

## 快速开始（推荐给普通用户）

⚠️ **执行策略提醒**：不少 Windows 机器默认 `Restricted`（禁止运行任何 .ps1），直接双击脚本会报"在此系统上禁止运行脚本"。因此本 Skill 附带 4 个 **.bat 一键启动器**（内部使用 `-ExecutionPolicy Bypass`，不会永久修改系统策略）：

| 启动器 | 作用 | 需要管理员 |
|---|---|---|
| `scripts/01-Scan.bat` | 只读侦察，报告存到桌面 `360-scan-report.txt` | 否 |
| `scripts/02-Stop-360.bat` | 预览→确认→结束 360 进程与服务 | 是（自动请求 UAC） |
| `scripts/03-Clean-Remnants.bat` | 空跑预览→确认→执行清理（自动建还原点） | 是（自动请求 UAC） |
| `scripts/04-Repair-Browser.bat` | 预览→确认→修复带 360 参数的快捷方式；主页、策略只提示人工复核 | 否 |

**推荐顺序**：`01 → 04 → 02 → 03`（先侦察、先救浏览器，再停进程、最后清残留）。

若习惯手工命令，统一用这种形式（同样绕过策略限制）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\Detect-360Remnants.ps1"
```

> 不要用 `Set-ExecutionPolicy` 全局放开策略；本 Skill 的调用方式已足够，且不改变系统设置。

## 工作流总览

| 阶段 | 目标 | 是否需要管理员 | 形态 |
|---|---|---|---|
| Phase 0 | 只读侦察，摸清残留范围 | 否 | `scripts/Detect-360Remnants.ps1` |
| Phase 1 | 急救浏览器，恢复主页 | 否 | `scripts/Repair-BrowserHijack.ps1` + 手动步骤 |
| Phase 2 | 结束 360 进程与服务 | 是 | `scripts/Stop-360Processes.ps1` |
| Phase 3 | 官方卸载器 / 应用面板卸载 | 是 | 手动 |
| Phase 4 | 清理文件、厂商注册表键与驱动；提示人工复核启动项、任务和右键菜单 | 是 | `scripts/Remove-360Remnants.ps1` |
| Phase 5 | 重启 / 安全模式清除被占用组件 | 是 | 手动 + 脚本复跑 |
| Phase 6 | 多轮验证 + 降级处理 | 视情况 | `scripts/Detect-360Remnants.ps1` 复检 |

> 执行次序不可颠倒：**必须先恢复浏览器**（Phase 1）。若先卸载 360，可能连带卸载/破坏浏览器，届时无法上网下载工具。

---

## Phase 0 — 只读侦察

**前置**：无。**风险**：🟢 只读，不修改任何内容。

```powershell
# 在工作区或任意位置运行；结果同时写入 360-scan-report.txt
powershell -ExecutionPolicy Bypass -File scripts/Detect-360Remnants.ps1 -OutFile "$env:USERPROFILE\Desktop\360-scan-report.txt"
```

侦察覆盖：进程 / 服务 / 内核驱动（`Win32_SystemDriver` + `fltmc instances`）/ 残留目录 / 卸载注册表项 / 启动项（Run 键·启动文件夹·启动审批）/ 计划任务 / 右键菜单处理程序 / 浏览器劫持迹象 / hosts 异常条目。

**判读要点**：
- 出现 `360Box64` `360netmon` `360FsFlt` `360AntiSteal` 任一驱动 → 后续必须走 Phase 5 重启流程。
- 服务名出现 `360`、`Q360` 前缀（历史上见过 `Q360AMPPL`、`360netmon`）→ 记入清理清单。
- 侦察到的每一项都要**人工确认属于 360** 再做删除，尤其是注册表项。

---

## Phase 1 — 急救浏览器，恢复正常主页

**前置**：能正常打开浏览器。**风险**：🟡 重置浏览器设置会清除扩展与本地设置（**不删书签和密码**）。

### 1.1 改 Chrome / Edge 主页与启动页（真实菜单路径）

**Chrome**：
1. 打开 Chrome → 右上角 **⋮（三个点）** → **设置**。
2. 左侧 **"启动时"** → 选择 **"打开新标签页"**，或 **"打开特定网页或一组网页"** 并填入你自己的主页（如 `https://www.google.com`）。
3. 左侧 **"外观"** → 检查 **"显示主页按钮"** 是否开启，若开启则确保主页地址不是 360 的。

**Edge**（地址栏直接输入）：
- `edge://settings/startHomeNTP` → **"Microsoft Edge 启动时"** 选择 **"打开新标签页"**。
- `edge://settings/reset` → 点击 **"将设置还原为其默认值"** → **重置**。

### 1.2 检查快捷方式"目标"栏是否被追加 URL（**最常见原因**）

1. 桌面/任务栏找到浏览器图标 → **右键 → 属性**。
2. 看 **"目标"** 栏，正常形如：
   `"C:\Program Files\Google\Chrome\Application\chrome.exe"`
3. 若后面被追加了 `https://hao.360.com` 之类内容（例如
   `"...chrome.exe" https://hao.360.com/?src=lm&ls=...`），**把引号后多余的部分整段删除**，只保留 exe 路径。
4. 点击 **应用 → 确定**。开始菜单、任务栏固定项若有同样问题，一并处理。

> 脚本 `Repair-BrowserHijack.ps1` 可扫描快捷方式中的 360 参数（默认空跑，加 `-Execute` 后尝试删除参数，并备份原快捷方式）；主页和浏览器策略需人工核对。

### 1.3 重置浏览器设置

Chrome：**设置 → 重置设置 → 将设置还原为原始默认设置**。此操作不清除书签与密码，但会清除恶意扩展与主页劫持。

### 1.4 检查浏览器策略注册表（卸载后仍被劫持的头号原因）

用 regedit 检查以下位置。它们也可能包含正常的个人或组织策略，**不要删除整个 `Edge` / `Chrome` 文件夹**；确认某个具体值由 360 设置后，先导出备份，再单独处理该值。脚本只报告这些键，不会自动删除。

```
HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge
HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Chrome
HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Edge
HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Chrome
```

### 1.5 排查可疑扩展

- Chrome：地址栏输入 `chrome://extensions`
- Edge：地址栏输入 `edge://extensions`

移除不认识或不必要的扩展。**重点警惕假冒成"Microsoft Edge Flash Player""Flash 播放器"之类的扩展**——真机案例中出现过：此类扩展拥有"读取和更改所有网站数据"权限，会向 `4399.com` 等站点注入内容，必须删除。

### 1.6 兜底排查（主页仍跳 360 时）

1. **DNS 被劫持**：检查路由器设置，或把 DNS 改为 `223.5.5.5`（阿里云）/ `119.29.29.29`（腾讯）。
2. **hosts 被改**：检查 `C:\Windows\System32\drivers\etc\hosts`，删除指向 360 域名的异常条目。
   ⚠️ 注意：hosts 里可能存在**公司/机房终端管理软件**的条目（真机案例中见过形如 `*.xxxxxx.cn` 的内部域名），**不属于 360，不要动**。
3. **系统级木马**：若怀疑是恶意软件而非正规 360，转用 Malwarebytes 或卡巴斯基免费版全盘扫描。

---

## Phase 2 — 结束 360 进程与服务

**前置**：管理员权限。**风险**：🟡 结束进程可能丢失未保存数据，先保存工作。

### 2.1 常见 360 进程

| 进程 | 归属 |
|---|---|
| `360se.exe` | 360 安全浏览器 |
| `360Chrome.exe` | 360 极速浏览器 |
| `360Safe.exe` / `360Tray.exe` | 360 安全卫士 |
| `360sd.exe` / `360rp.exe` | 360 杀毒 |
| `360zip.exe` | 360 压缩 |
| 其他以 `360` 开头的进程 | 一律列入待处理 |

任务管理器路径：`Ctrl + Shift + Esc` → **"进程"** 选项卡 → 找到目标 → 右键 **"结束任务"**。

### 2.2 用脚本批量处置

```powershell
# 默认空跑（只列出将要做的事），确认后加 -Execute
powershell -ExecutionPolicy Bypass -File scripts/Stop-360Processes.ps1
powershell -ExecutionPolicy Bypass -File scripts/Stop-360Processes.ps1 -Execute
```

脚本行为：按可配置的前缀清单（默认 `360*`）结束进程 → 停止匹配的 `360*` / `Q360*` 服务 → 输出逐项结果日志。

> **自保护提示**：若进程杀不掉或服务停不掉（报"拒绝访问"/卡在 STOP_PENDING），说明 360 自保护内核驱动在起作用。**不要反复强杀**，直接进入 Phase 5 的重启流程——重启后驱动文件若已删除，其保护自然失效。

---

## Phase 3 — 卸载 360 软件

**前置**：Phase 2 已完成（进程已结束）。**风险**：🔴 卸载会删除软件数据，确认无需保留配置。

### 3.1 从"应用和功能"卸载

**真实入口**：`Win + I` → **应用** → **已安装的应用**（旧版系统为"应用和功能"）→ 搜索并逐个卸载：

- 360安全卫士 / 360 Total Security
- 360杀毒
- 360安全浏览器
- 360极速浏览器
- 360软件管家
- 360安全大脑
- 360压缩（如不用）
- **任何带"360"字样的程序**

### 3.2 使用 360 自带卸载程序（面板卸载不干净时）

进入 360 安装目录运行其卸载器（如 `uninst.exe` / `Uninstall.exe`）。

> ⚠️ **卸载器话术陷阱**：卸载过程中 360 会弹出"修复""保留防护""仅卸载部分组件"等诱导选项。**必须选择"继续卸载"/"狠心卸载"/"彻底卸载"**，任何带"保留""修复"的选项都会留下核心组件。

### 3.3 卸载受阻时

若卸载器提示被占用或无法继续，说明残留服务/驱动在运行 → 直接走 Phase 5（重启或安全模式）后再卸载。

---

## Phase 4 — 深度清理残留

**前置**：管理员权限 + 已完成备份/还原点。**风险**：🔴 高风险区，逐项确认后再删。

### 4.1 残留文件夹（删除前确认目录内无你的个人文件）

| 路径 | 说明 |
|---|---|
| `C:\Program Files (x86)\360` | 主安装目录残留 |
| `C:\Program Files\360` | 64 位残留 |
| `%USERPROFILE%\AppData\Local\360` | 用户级残留 |
| `%USERPROFILE%\AppData\Roaming\360` | 用户级残留（曾见 `Roaming\360safe`） |
| `%USERPROFILE%\AppData\LocalLow\360` | 低完整性残留 |
| `C:\ProgramData\360SD` | 曾见空的 `360SD` 目录（需管理员删除） |
| `C:\Windows\System32\drivers\360*.sys` | 驱动文件（见 4.6） |

> 真机经验：`Program Files (x86)\360` 常被设为 TrustedInstaller 所有并加防删保护，普通管理员删除会"拒绝访问"。处理方式：先 `takeown /f "<目录>" /r /d y` 取得所有权 → `icacls "<目录>" /grant administrators:F /t /q` 授权 → `rmdir /s /q "<目录>"`。**这些命令必须由用户以管理员身份运行**（脚本内已实现）。

### 4.2 注册表项

⚠️ **强烈警告**：注册表误删可能造成系统异常。**必须**先导出备份；**只删除确认属于 360 的项**。

**禁止**用通配符或宽泛子串批量删除。允许"搜索"，但删除时必须逐项人工确认。

重点检查路径：

```
HKEY_CURRENT_USER\Software\360
HKEY_LOCAL_MACHINE\SOFTWARE\360
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\360
```

操作方式：`Win + R` → `regedit` → `Ctrl + F` 搜索 `360Safe` 或 `360` → 逐项判断 → 仅删除明显属于 360 的键。

> **历史教训（务必传达给用户）**：曾用宽泛子串（如 `360`）在 `HKCU\Classes` 等位置递归匹配并删除，误删了 Windows 自身的 AppContainer 映射、MrtCache、SID/GUID 项。**宁可少删，不可错删**；不确定就保留并告知用户。

### 4.3 开机启动项

1. `Ctrl + Shift + Esc` → **"启动应用"** → 对 360 相关项右键 **"禁用"**。
2. 注册表（`regedit`，删前导出）：
   `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`
   `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`
   `HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`
   删除值为 360 路径的条目。
3. 启动文件夹：`shell:startup` 与 `shell:common startup`，删除 360 快捷方式。

### 4.4 计划任务

**真实入口**：右键 **"此电脑"** → **管理** → **任务计划程序** → **任务计划程序库**，查找并删除与 360 相关的任务。

命令行等价：`Get-ScheduledTask | Where-Object {$_.TaskName -like '*360*'}` 确认后用 `Unregister-ScheduledTask` 删除（脚本已实现）。

### 4.5 右键菜单残留

删除指向 360 的处理程序（**删前导出对应键**）：

```
HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\<含360的项>
HKEY_CLASSES_ROOT\Directory\shellex\ContextMenuHandlers\<含360的项>
HKEY_CLASSES_ROOT\Directory\Background\shellex\ContextMenuHandlers\<含360的项>
HKEY_CLASSES_ROOT\Folder\shellex\ContextMenuHandlers\<含360的项>
HKEY_LOCAL_MACHINE\SOFTWARE\Classes\*\shellex\ContextMenuHandlers\<含360的项>
```

判断依据：项名或默认值中包含 `360`，且指向的 DLL 已不存在或位于 360 目录。

### 4.6 内核驱动与服务残留（最关键）

真机所见 360 驱动：`360Box64.sys`、`360netmon.sys`，另有 `360FsFlt.sys`、`360AntiSteal.sys`（mini-filter，挂载在 C:/D:/E: 等卷上）。

**检查**：
```powershell
Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -match '360' } | Select-Object Name,State,PathName
fltmc instances            # 查看 mini-filter 实例
fltmc filters              # 查看已注册的过滤驱动
sc query 360Box64          # 查询具体服务状态
```

**处置**（管理员）：
```powershell
sc stop 360Box64           # 可能报 1052 或卡 STOP_PENDING，属正常
sc config 360Box64 start= disabled
sc delete 360Box64         # 删除服务项
```
删除驱动文件：`C:\Windows\System32\drivers\360*.sys`（先停服务）。

> **关键结论**：驱动文件一旦删除，**本次开机已加载进内存的驱动仍在运行**，此时"删除服务项/文件夹"仍会失败——这是正常现象。**重启一次**后系统找不到驱动文件，驱动再也加载不起来，文件锁定自动解除。因此本阶段失败**不代表清理失败**，继续 Phase 5 即可。

### 4.7 用脚本执行（推荐）

```powershell
# 空跑预览（默认，不删任何东西）
powershell -ExecutionPolicy Bypass -File scripts/Remove-360Remnants.ps1

# 正式执行（管理员；自动先建还原点 + 逐项日志）
powershell -ExecutionPolicy Bypass -File scripts/Remove-360Remnants.ps1 -Execute -CreateRestorePoint
```

脚本特性：**默认 dry-run**；固定目录和厂商注册表键会列出供确认；可创建还原点，若创建失败则停止执行；启动项、计划任务与右键菜单仅列出供人工核对，不自动删除。

---

## Phase 5 — 重启 / 安全模式处理被占用组件

**何时需要**：驱动删不掉、目录被锁、服务停在 STOP_PENDING、卸载器提示被占用。

### 5.1 普通重启（解决 90% 情况）

重启后驱动不再加载、文件锁释放 → 再跑一次 `Remove-360Remnants.ps1 -Execute` 清除服务项与空目录。

### 5.2 进入安全模式（顽固情况）

1. 按住 **Shift** 的同时点击 **开始菜单 → 电源 → 重启**。
2. 进入蓝色恢复界面 → **疑难解答** → **高级选项** → **启动设置** → **重启**。
3. 重启后按 **4** 或 **F4** 进入安全模式（需要网络则按 **5** 或 **F5**）。
4. 在安全模式下重跑清理脚本（此时第三方杀软与自保护驱动均不加载，清理成功率最高）。
5. 正常重启退出安全模式。

### 5.3 杀软拦截的处置

若删除始终失败，且已排除权限与占用问题，**大概率是本机第三方杀软**（如火绒）在内核层拦截。处置顺序：
1. 用杀软**自带的"文件粉碎"/"病毒查杀→立即处理"**删除（杀软用自己的特权路径，最干净）。
2. 或把目标加入杀软**信任区**后删除。
3. 或**临时完全退出杀软**（注意退出后不要联网下载不明文件），删除完成后立即重新开启。

---

## Phase 6 — 验证

**卸载完成的判定标准**：以下全部为空或不存在。

```powershell
# 一次性复检（只读）
powershell -ExecutionPolicy Bypass -File scripts/Detect-360Remnants.ps1
```

| 检查项 | 命令 | 期望结果 |
|---|---|---|
| 进程 | `Get-Process | Where-Object {$_.ProcessName -like '360*'}` | 无输出 |
| 服务 | `Get-Service | Where-Object {$_.Name -like '*360*'}` | 无输出 |
| 驱动 | `Get-CimInstance Win32_SystemDriver | Where-Object {$_.Name -like '*360*'}` | 无输出 |
| 过滤驱动 | `fltmc instances` | 无 360 项 |
| 目录 | `Test-Path` 逐个检查 4.1 清单 | 全为 False |
| 注册表 | 检查 4.2 三个键 | 不存在 |
| 启动项 | 启动应用 + 三个 Run 键 | 无 360 项 |
| 计划任务 | `Get-ScheduledTask` 过滤 360 | 无匹配 |
| 右键菜单 | 检查 4.5 各键 | 无 360 项 |
| 浏览器 | 主页/启动页/快捷方式目标/策略/扩展 | 均无 360 痕迹 |

> 备注：浏览器配置文件（Edge `Preferences`）中可能残留 **hao.360.com 的访问历史/站点数据**。这属于浏览记录，**不是劫持设置**，不影响使用。如需清除：浏览器 → `Ctrl + Shift + Del` → 勾选 **"Cookie 和站点数据"** + **"浏览历史记录"** → 清除。

---

## 失败降级方案（阶梯式）

| 级别 | 现象 | 处置 |
|---|---|---|
| L1 | "拒绝访问" | 以**管理员身份**重跑；确认脚本以管理员启动 |
| L2 | 文件被占用 / 卸载器报占用 | 结束进程与服务 → 不行则重启后重试 |
| L3 | 驱动/服务删不掉，或卡 STOP_PENDING | 重启；再不行 `sc config <名> start= disabled` 后重启；仍不行进**安全模式** |
| L4 | 目录属 TrustedInstaller、takeown 报"特权未分配" | 用**完整管理员令牌**（右键"以管理员身份运行"）执行 takeown + icacls；UAC 过滤令牌权限不足 |
| L5 | 杀软内核拦截（关防护开关无效） | 杀软自带粉碎 / 信任区 / 完全退出杀软后删除 |
| L6 | 卸载后主页仍跳 360 | 按 Phase 1 顺序逐层排查：快捷方式"目标" → 浏览器策略注册表 → Preferences/启动页 → 扩展 → DNS → hosts |
| L7 | 仍怀疑有恶意残留 | Malwarebytes / 卡巴斯基免费版全盘扫描；或使用 360 官方"卸载工具"（官方专杀） |
| L8 | 以上全部无效 | 备份数据 → 重装系统（最后手段） |

---

## 风险与红线

1. **删注册表前必须导出备份**；只删确认属于 360 的项，绝不用通配符批量删。
2. **删文件夹前确认无个人文件**（360 目录里一般不会有，但真机案例中某盘符下的 `XXXDownloads` 这类"历史命名的下载目录"实际安装着 Photoshop、Dreamweaver 等软件——**目录名不等于内容**）。
3. **Phase 1 必须先于 Phase 3**：先恢复浏览器，再卸载 360，避免卸载后无浏览器可用。
4. **不要动不属于 360 的东西**：hosts 中的公司/机房管理软件条目、其他第三方安全软件（如火绒）一律保留。
5. 脚本**默认空跑**，看清输出再决定是否 `-Execute`；执行前建还原点。

## Agent 环境注意事项（实操补充）

在受控 agent 沙箱中执行时，已知限制会影响直连操作，需提前规划：

- **批量删除防护**会拦截 agent 直接发起的删除（含 `Remove-Item`）；移动/重命名通常不被拦截。
- **`reg.exe`、`schtasks.exe` 等程序可能被策略禁用**；读取注册表改用 `Get-ItemProperty` / `Get-Service` / `Get-CimInstance`。
- **`Add-Type`、COM 对象（如 `WScript.Shell`）可能被禁用**；读取 `.lnk` 可用 `[IO.File]::ReadAllText($p,[Text.Encoding]::Unicode)` 做文本匹配（只能判断"是否含某路径"，分不清目标/图标）。
- PowerShell 工具可能**不回显外部程序 stdout**；把结果 `Out-File` 到文件后用读取工具查看。
- 需要真正删除系统对象时，**生成脚本交由用户"以管理员身份运行"**（脱离沙箱），是可靠路径。
- **跨盘重命名含已安装软件的目录会破坏软件**（注册表内引用大量绝对路径）。若用户只是想"改目录名"，正确做法是：改名后在同位置建立**目录联接（junction）**指向新名，`New-Item -ItemType Junction -Path <旧名> -Target <新名>`；删除联接用 `[IO.Directory]::Delete($path)`（只删链接不动数据）。

## 资源

**一键启动器（.bat，推荐普通用户使用）**
- `scripts/01-Scan.bat` — 只读侦察
- `scripts/02-Stop-360.bat` — 结束进程与服务（管理员）
- `scripts/03-Clean-Remnants.bat` — 深度清理（管理员，空跑预览 + 确认后执行）
- `scripts/04-Repair-Browser.bat` — 浏览器劫持修复

**PowerShell 脚本（可单独调用，全部默认空跑）**
- `scripts/Detect-360Remnants.ps1` — 只读侦察与验证（进程/服务/驱动/目录/注册表/启动项/计划任务/右键菜单/浏览器劫持/hosts）。
- `scripts/Stop-360Processes.ps1` — 结束 360 进程与服务（默认空跑）。
- `scripts/Remove-360Remnants.ps1` — 管理员深度清理（默认空跑；启动项、计划任务与右键菜单仅报告）。
- `scripts/Repair-BrowserHijack.ps1` — 检查浏览器主页/启动页和策略，尝试修复带 360 参数的快捷方式（默认空跑）。

**参考文档**
- `references/known-artifacts.md` — 360 全家桶清单、常见路径/服务/驱动/注册表/计划任务/右键菜单及去身份化的真机案例记录。

> 脚本输出均为英文 ASCII，以避免中文在 PowerShell 5.1 下的编码乱码问题；.bat 启动器同样为纯 ASCII 并采用 CRLF 换行，确保 cmd.exe 正确解析。阅读后可自行翻译给用户。
