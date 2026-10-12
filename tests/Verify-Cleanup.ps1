# Executes only modified BAT copies against disposable fixture profiles.
# Windows Temp is omitted; real user paths are not cleaned.
$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('windows-cache-cleaner-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
function Assert([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}
foreach ($account in @('Account One','Account Two')) {
    $sourcePath = Join-Path $workspace 'Clean-Windows-Cache.bat'
    $raw = [IO.File]::ReadAllText($sourcePath)
    $parts = [regex]::Split($raw, '(?m)^# POWERSHELL_PAYLOAD\r?$')
    Assert ($parts.Count -eq 2) 'Payload marker invalid'
    $tokens = $null; $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseInput($parts[1], [ref]$tokens, [ref]$parseErrors)
    Assert ($parseErrors.Count -eq 0) 'PowerShell syntax invalid'
    Assert ($raw -match 'del /q /f /s "%temp%\\\*"') 'Requested del command missing'
    Assert ($raw -notmatch '(?im)^\s*(rd|rmdir|Remove-Item)\b') 'Unexpected directory deletion'
    $testProfile = Join-Path $fixture $account
    $tempDir = Join-Path $testProfile 'AppData\Local\Temp'
    $nestedDir = Join-Path $tempDir 'nested'
    $graphicsDir = Join-Path $testProfile 'AppData\Local\D3DSCache'
    $linkedCache = Join-Path $testProfile 'AppData\Local\NVIDIA\DXCache'
    $outside = Join-Path $fixture "$account-preserve"
    foreach ($dir in @($nestedDir,$graphicsDir,$linkedCache,$outside)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [IO.File]::WriteAllText((Join-Path $tempDir 'root.tmp'), 'fixture')
    [IO.File]::WriteAllText((Join-Path $nestedDir 'nested.tmp'), 'fixture')
    [IO.File]::WriteAllText((Join-Path $graphicsDir 'shader.bin'), 'fixture')
    [IO.File]::WriteAllText((Join-Path $outside 'keep.txt'), 'preserve')
    [IO.File]::WriteAllText((Join-Path $linkedCache 'keep-too.txt'), 'preserve entire cache if a link exists')
    New-Item -ItemType Junction -Path (Join-Path $linkedCache 'linked') -Target $outside | Out-Null
    $clone = $raw
    $clone = $clone.Replace('call :Clean "%SystemRoot%\Temp"', 'rem System temporary folder omitted in fixture verification')
    $clone = $clone.Replace('pause', 'rem pause omitted in fixture verification')
    $testBat = Join-Path $fixture "test-$account.bat"
    [IO.File]::WriteAllText($testBat, $clone, [Text.Encoding]::ASCII)
    $oldTemp = $env:TEMP
    $oldProfile = $env:USERPROFILE
    try {
        $env:TEMP = $tempDir
        $env:USERPROFILE = $testProfile
        & $env:ComSpec /d /c "`"$testBat`"" | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'Fixture BAT execution failed'
    } finally { $env:TEMP = $oldTemp; $env:USERPROFILE = $oldProfile }
    Assert (Test-Path -LiteralPath $tempDir -PathType Container) 'Temp folder removed'
    Assert (Test-Path -LiteralPath $nestedDir -PathType Container) 'Nested folder removed'
    Assert (-not (Test-Path -LiteralPath (Join-Path $tempDir 'root.tmp'))) 'Root temp file not removed'
    Assert (-not (Test-Path -LiteralPath (Join-Path $nestedDir 'nested.tmp'))) 'Nested temp file not removed'
    Assert (-not (Test-Path -LiteralPath (Join-Path $graphicsDir 'shader.bin'))) 'Graphics cache file not removed'
    Assert (Test-Path -LiteralPath (Join-Path $outside 'keep.txt')) 'Junction target affected'
    Assert (Test-Path -LiteralPath (Join-Path $linkedCache 'keep-too.txt')) 'Linked cache not skipped'
    $env:CLEAN_PROFILE = $testProfile
    $env:CLEAN_SCRIPT = $sourcePath
    $env:CLEAN_MODE = 'temp'
    $validatorCode = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($parts[1]))
    $savedTemp = $env:TEMP
    try {
        $env:TEMP = $tempDir
        & $psExe -NoProfile -NonInteractive -EncodedCommand $validatorCode
        Assert ($LASTEXITCODE -eq 0) 'Valid TEMP rejected'
        $env:TEMP = $fixture
        & $psExe -NoProfile -NonInteractive -EncodedCommand $validatorCode
        Assert ($LASTEXITCODE -ne 0) 'Unsafe TEMP accepted'
    } finally { $env:TEMP = $savedTemp }
    Write-Output "$account : syntax, nested cleanup, folder preservation, missing paths, junction rejection and unsafe TEMP checks passed."
}

# Expected rejection above leaves LASTEXITCODE=1; successful assertions mean success.
exit 0
