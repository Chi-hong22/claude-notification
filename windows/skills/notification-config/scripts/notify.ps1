param([string]$Title = "Claude Code", [string]$Message = "通知", [string]$Dir = "")

# 如果 Dir 为空或未展开，尝试从环境变量获取
if (-not $Dir -or $Dir -eq '${CLAUDE_PROJECT_DIR}' -or $Dir -eq '$CLAUDE_PROJECT_DIR') {
    $Dir = $env:CLAUDE_PROJECT_DIR
    if (-not $Dir) {
        $Dir = Get-Location
    }
}

# 读取配置文件
$configFile = Join-Path $Dir ".claude/claude-notification.local.md"
$barkUrl = ""
$systemNotificationEnabled = $true
$notifyAlways = $false

if (Test-Path $configFile) {
    $content = Get-Content $configFile -Raw
    if ($content -match '(?s)^---\r?\n(.+?)\r?\n---') {
        $frontmatter = $Matches[1]
        if ($frontmatter -match 'bark_url:\s*[''"]?([^''"}\r\n]+)[''"]?') {
            $barkUrl = $Matches[1].Trim()
        }
        if ($frontmatter -match 'system_notification_enabled:\s*(true|false)') {
            $systemNotificationEnabled = $Matches[1] -eq 'true'
        }
        if ($frontmatter -match 'notify_always:\s*(true|false)') {
            $notifyAlways = $Matches[1] -eq 'true'
        }
    }
}

# 前台检测：用纯 .NET API，避免 Add-Type 编译 C# 和 WMI 查询
$myTerminalPid = $null
$terminalName = $null

# 向上遍历父进程，找到有窗口的终端进程（最多 10 层）
try {
    $cur = [System.Diagnostics.Process]::GetCurrentProcess()
    for ($i = 0; $i -lt 10; $i++) {
        $parentId = (Get-CimInstance Win32_Process -Filter "ProcessId=$($cur.Id)" -Property ParentProcessId -ErrorAction SilentlyContinue).ParentProcessId
        if (-not $parentId) { break }
        $parent = Get-Process -Id $parentId -ErrorAction SilentlyContinue
        if (-not $parent) { break }
        if ($parent.MainWindowHandle -ne [IntPtr]::Zero -and $parent.ProcessName -ne 'explorer') {
            $myTerminalPid = $parent.Id
            $terminalName = if ($parent.MainWindowTitle) { $parent.MainWindowTitle } else { $parent.ProcessName }
            break
        }
        $cur = $parent
    }
} catch {
    # 忽略，不影响通知发送
}

# 获取前台窗口 PID（用 .NET + user32，仅在需要时加载）
$foregroundPid = 0
try {
    Add-Type -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
'@ -Name 'User32Fg' -Namespace 'NativeMethods' -ErrorAction SilentlyContinue
    $hwnd = [NativeMethods.User32Fg]::GetForegroundWindow()
    [NativeMethods.User32Fg]::GetWindowThreadProcessId($hwnd, [ref]$foregroundPid) | Out-Null
} catch {
    # 获取失败时 foregroundPid 保持 0，shouldNotify 由 alwaysNotify 决定
}

$shouldNotify = $notifyAlways -or ($foregroundPid -ne $myTerminalPid)

if ($shouldNotify) {
    if ($Dir) {
        $parts = $Dir -split '[/\\]' | Where-Object { $_ }
        $shortDir = ($parts | Select-Object -Last 2) -join '/'
        $Message = "$Message - $shortDir"
    }

    # 添加终端名称
    if ($terminalName) {
        $Message = "$Message [$terminalName]"
    }

    # 发送 Bark 通知
    if ($barkUrl) {
        try {
            $encodedTitle = [System.Uri]::EscapeDataString($Title)
            $encodedMessage = [System.Uri]::EscapeDataString($Message)
            $barkFullUrl = "$barkUrl/$encodedTitle/$encodedMessage"
            Invoke-RestMethod -Uri $barkFullUrl -Method Get -TimeoutSec 5 | Out-Null
        } catch {
            # Bark 发送失败，静默忽略
        }
    }

    # 发送 Windows Toast 通知（除非 system_notification_enabled 为 false）
    if ($systemNotificationEnabled) {
        try {
            # 加载 Windows Runtime 组件
            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

            # 应用标识符（使用 PowerShell 的 AppUserModelId）
            $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

            # 创建 Toast XML 模板
            $ToastXml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$([System.Security.SecurityElement]::Escape($Title))</text>
            <text>$([System.Security.SecurityElement]::Escape($Message))</text>
        </binding>
    </visual>
    <audio silent="true"/>
</toast>
"@

            # 加载 XML
            $XmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
            $XmlDoc.LoadXml($ToastXml)

            # 创建并显示通知
            $Toast = [Windows.UI.Notifications.ToastNotification]::new($XmlDoc)
            $Toast.Tag = "ClaudeCode"
            $Toast.Group = "ClaudeCode"

            $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
            $Notifier.Show($Toast)
        } catch {
            # Toast 通知失败，回退到 BalloonTip
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $notify = New-Object System.Windows.Forms.NotifyIcon
                $notify.Icon = [System.Drawing.SystemIcons]::Information
                $notify.BalloonTipTitle = $Title
                $notify.BalloonTipText = $Message
                $notify.Visible = $true
                $notify.ShowBalloonTip(5000)
                # 不使用 Start-Sleep，让通知异步显示
                $notify.Dispose()
            } catch {
                # 完全失败，静默忽略
            }
        }
    }
}
