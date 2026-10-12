# Changelog

## 1.0.1 — 2026-10-12

- Make fixture validation work consistently when launched from Windows PowerShell 5.1 or PowerShell 7.
- Assert both accepted and rejected TEMP paths, and explicitly report test success after expected rejection.
- Pin the Windows CI checkout action to a verified v6 commit.
- The production BAT and its cleanup scope are unchanged.

## 1.0.0 — 2026-10-12

- Automatically detect the account launching the BAT through `%USERPROFILE%`.
- Clean selected user temporary files, Windows Temp, shader caches and Chrome/Edge Default-profile caches.
- Preserve directories and skip missing, linked or unverifiable targets.
- Skip browser cache targets while the relevant browser is running.
- Include a validated `del /q /f /s "%temp%\*"` step.
- Add an English guide, fixture tests and Windows CI.
