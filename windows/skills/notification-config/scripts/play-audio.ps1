param([string]$AudioFile, [string]$Dir = "")

if (-not $AudioFile -or -not (Test-Path $AudioFile)) { exit 0 }

if (-not $Dir -or $Dir -eq '${CLAUDE_PROJECT_DIR}') {
    $Dir = $env:CLAUDE_PROJECT_DIR
}

$audioEnabled = $true
$audioAlways = $false

if ($Dir) {
    $configFile = Join-Path $Dir ".claude/claude-notification.local.md"
    if (Test-Path $configFile) {
        $content = Get-Content $configFile -Raw
        if ($content -match 'audio_enabled:\s*(true|false)') {
            $audioEnabled = $Matches[1] -eq 'true'
        }
        if ($content -match 'audio_always:\s*(true|false)') {
            $audioAlways = $Matches[1] -eq 'true'
        }
    }
}

if (-not $audioEnabled) { exit 0 }

$myTerminalPid = $null
try {
    $cur = [System.Diagnostics.Process]::GetCurrentProcess()
    for ($i = 0; $i -lt 10; $i++) {
        $parentId = (Get-CimInstance Win32_Process -Filter "ProcessId=$($cur.Id)" -Property ParentProcessId -ErrorAction SilentlyContinue).ParentProcessId
        if (-not $parentId) { break }
        $parent = Get-Process -Id $parentId -ErrorAction SilentlyContinue
        if (-not $parent) { break }
        if ($parent.MainWindowHandle -ne [IntPtr]::Zero -and $parent.ProcessName -ne 'explorer') {
            $myTerminalPid = $parent.Id
            break
        }
        $cur = $parent
    }
} catch {}

$foregroundPid = 0
try {
    Add-Type -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
'@ -Name 'User32Audio' -Namespace 'NativeMethods' -ErrorAction SilentlyContinue
    $hwnd = [NativeMethods.User32Audio]::GetForegroundWindow()
    [NativeMethods.User32Audio]::GetWindowThreadProcessId($hwnd, [ref]$foregroundPid) | Out-Null
} catch {}

$shouldPlay = $audioAlways -or ($foregroundPid -ne $myTerminalPid)
if (-not $shouldPlay) { exit 0 }

try {
    $player = New-Object System.Media.SoundPlayer $AudioFile
    $player.PlaySync()
    $player.Dispose()
} catch {}
