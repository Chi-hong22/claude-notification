param([string]$AudioFile)

if (-not $AudioFile -or -not (Test-Path $AudioFile)) { exit 0 }

try {
    $player = New-Object System.Media.SoundPlayer $AudioFile
    $player.PlaySync()
    $player.Dispose()
} catch {
    # silent fail
}
