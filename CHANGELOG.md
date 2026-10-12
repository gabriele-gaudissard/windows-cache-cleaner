# Changelog

## 1.0.0 — 2026-10-12

- Automatically detect the account launching the BAT through `%USERPROFILE%`.
- Clean selected user temporary files, Windows Temp, shader caches and Chrome/Edge Default-profile caches.
- Preserve directories and skip missing, linked or unverifiable targets.
- Skip browser cache targets while the relevant browser is running.
- Include a validated `del /q /f /s "%temp%\*"` step.
- Add an English guide, fixture tests and Windows CI.
