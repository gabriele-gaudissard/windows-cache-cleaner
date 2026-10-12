@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Windows Cache Cleaner - Automatic user profile
rem Windows 11. File deletion only; no directory removal commands.
rem Close apps and browsers before running. Elevation is not required.
rem Detect the profile of the account running this file.
if not defined USERPROFILE goto NoProfile
set "CLEAN_PROFILE=%USERPROFILE%"
set "CLEAN_SCRIPT=%~f0"
set "CLEAN_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%CLEAN_PS%" goto NoPowerShell
echo Conservative cleanup for "%CLEAN_PROFILE%"
echo Locked or inaccessible files are left in place.
echo.
call :Clean "%CLEAN_PROFILE%\AppData\Local\Temp"
call :Clean "%SystemRoot%\Temp"
call :Clean "%CLEAN_PROFILE%\AppData\Local\D3DSCache"
call :Clean "%CLEAN_PROFILE%\AppData\Local\NVIDIA\DXCache"
call :Clean "%CLEAN_PROFILE%\AppData\Local\NVIDIA\GLCache"
call :Clean "%CLEAN_PROFILE%\AppData\Local\Google\Chrome\User Data\Default\Cache" chrome
call :Clean "%CLEAN_PROFILE%\AppData\Local\Google\Chrome\User Data\Default\Code Cache" chrome
call :Clean "%CLEAN_PROFILE%\AppData\Local\Google\Chrome\User Data\Default\GPUCache" chrome
call :Clean "%CLEAN_PROFILE%\AppData\Local\Microsoft\Edge\User Data\Default\Cache" msedge
call :Clean "%CLEAN_PROFILE%\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache" msedge
call :Clean "%CLEAN_PROFILE%\AppData\Local\Microsoft\Edge\User Data\Default\GPUCache" msedge

rem Run the TEMP deletion command only after validating its location.
set "CLEAN_MODE=temp"
set "CLEAN_BROWSER="
call :Validate
if errorlevel 1 goto SkipTemp
echo Cleaning TEMP for the account running this file.
del /q /f /s "%temp%\*" >nul 2>&1
goto Finished
:SkipTemp
echo TEMP skipped: missing, disallowed, linked or unverifiable path.
:Finished
echo.
echo Finished. Folder structures have been preserved.
echo Some files may remain because they are locked, protected or inaccessible.
pause
endlocal
exit /b 0
:NoProfile
echo User profile unavailable. No files deleted.
pause
endlocal
exit /b 1
:NoPowerShell
echo Windows PowerShell unavailable. No files deleted.
pause
endlocal
exit /b 1

:Clean
set "CLEAN_TARGET=%~1"
set "CLEAN_BROWSER=%~2"
set "CLEAN_MODE=fixed"
call :Validate
if errorlevel 1 (
    echo Skipped: "%CLEAN_TARGET%"
    exit /b 0
)
echo Cleaning: "%CLEAN_TARGET%"
del /q /f /s "%CLEAN_TARGET%\*" >nul 2>&1
exit /b 0

:Validate
rem PowerShell only validates paths; all deletion uses del.
rem No enumerated path list is passed from PowerShell to cmd.
"%CLEAN_PS%" -NoLogo -NoProfile -NonInteractive -Command "try { $raw=[IO.File]::ReadAllText($env:CLEAN_SCRIPT); $parts=[regex]::Split($raw,'(?m)^# POWERSHELL_PAYLOAD\r?$'); if($parts.Count -ne 2){exit 1}; & ([scriptblock]::Create($parts[1])) } catch { exit 1 }" >nul 2>&1
exit /b %errorlevel%

# POWERSHELL_PAYLOAD
$ErrorActionPreference = 'Stop'
try {
    function Normalize([string] $value) {
        if ([string]::IsNullOrWhiteSpace($value) -or
            $value.IndexOfAny([char[]]'"*?') -ge 0 -or
            -not [IO.Path]::IsPathRooted($value)) { throw 'Invalid path' }
        return [IO.Path]::GetFullPath($value).TrimEnd('\')
    }
    $profile = Normalize $env:CLEAN_PROFILE
    $allowed = @(
        "$profile\AppData\Local\Temp",
        "$(Normalize $env:SystemRoot)\Temp",
        "$profile\AppData\Local\D3DSCache",
        "$profile\AppData\Local\NVIDIA\DXCache",
        "$profile\AppData\Local\NVIDIA\GLCache"
    )
    foreach ($browserRoot in @(
        "$profile\AppData\Local\Google\Chrome\User Data\Default",
        "$profile\AppData\Local\Microsoft\Edge\User Data\Default"
    )) {
        foreach ($cache in @('Cache', 'Code Cache', 'GPUCache')) {
            $allowed += "$browserRoot\$cache"
        }
    }
    if ($env:CLEAN_MODE -eq 'temp') {
        $target = Normalize $env:TEMP
        $allowed = @(
            "$profile\AppData\Local\Temp",
            "$(Normalize $env:USERPROFILE)\AppData\Local\Temp",
            "$(Normalize $env:SystemRoot)\Temp"
        )
    } elseif ($env:CLEAN_MODE -eq 'fixed') {
        $target = Normalize $env:CLEAN_TARGET
    } else { throw 'Invalid mode' }
    if ($allowed -notcontains $target) { throw 'Not allowed' }
    if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw 'Missing' }
    $self = Normalize $env:CLEAN_SCRIPT
    if ($self.StartsWith($target + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Move the BAT outside the folder being cleaned'
    }
    if ($env:CLEAN_BROWSER -and
        (Get-Process -Name $env:CLEAN_BROWSER -ErrorAction SilentlyContinue)) {
        throw 'Browser running'
    }
    # Check the target and every ancestor for reparse points.
    $ancestor = $target
    while ($ancestor) {
        $item = Get-Item -LiteralPath $ancestor -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link' }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    # Inspect the entire tree before del /s; any link or inspection error skips it.
    $pending = New-Object 'System.Collections.Generic.Queue[string]'
    $pending.Enqueue($target)
    while ($pending.Count -gt 0) {
        foreach ($entry in @(Get-ChildItem -LiteralPath $pending.Dequeue() -Force)) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link' }
            if ($entry.PSIsContainer) { $pending.Enqueue($entry.FullName) }
        }
    }
    exit 0
} catch {
    exit 1
}
