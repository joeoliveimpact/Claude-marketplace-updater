@echo off
setlocal
set "MODE=%~1"
title Claude Marketplace Sync Fixer (Windows)

REM ============================================================
REM  Claude Desktop marketplace-sync fixer  -  Windows
REM  Fixes plugins stuck on an old version after an update
REM  was published.
REM
REM  Staged + FULLY REVERSIBLE: folders are RENAMED with a
REM  timestamp, never deleted. Restore steps printed at the end.
REM  Runbook: docs/marketplace-sync-fix-test.md  (CNTNTSE-139)
REM ============================================================

echo.
echo   ================================================================
echo    CLAUDE MARKETPLACE SYNC FIXER  (Windows)
echo   ================================================================
echo.
echo    Your Claude plugins are stuck on an old version. GitHub has the
echo    new one; Claude Desktop is holding a stale local cache. This
echo    clears that cache so the new version can sync.
echo.
echo    IMPORTANT:
echo      - This will FULLY QUIT Claude Desktop (you will re-login).
echo        Claude Code terminal sessions are left running.
echo      - If you are reading this inside Claude, finish your work first.
echo      - Nothing is deleted. Folders are renamed to .bak-<time> and
echo        can be restored (steps shown at the end).
echo.
if defined MODE goto :gate_ok
set "GO="
set /p GO="   Type yes and press Enter to continue (anything else cancels): "
if /i "%GO%"=="YES" goto :gate_ok
if /i "%GO%"=="Y" goto :gate_ok
goto :cancel
:gate_ok

set "CLAUDE_DIR=%APPDATA%\Claude"
set "IDB=%CLAUDE_DIR%\IndexedDB"

if not exist "%CLAUDE_DIR%" (
  echo.
  echo   [X] Could not find "%CLAUDE_DIR%".
  echo       Is Claude Desktop installed for THIS Windows user?
  goto :end
)

REM ---- timestamp for reversible backup names ----
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "TS=%%t"

REM ---- non-interactive dispatch (--stage1 / --stage2, for Claude Code-driven runs) ----
if /i "%MODE%"=="--stage1" goto :auto_s1
if /i "%MODE%"=="--stage2" goto :s2_retired
if defined MODE (
  echo   [X] Unknown option "%MODE%". Use --stage1.
  exit /b 2
)

REM =================== STAGE 1 - surgical ===================
echo.
echo   --- Stage 1: surgical clear (IndexedDB only) ---
echo   Quitting Claude...
powershell -NoProfile -Command "Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*AnthropicClaude*' -or $_.Path -like '*WindowsApps*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
ping -n 3 127.0.0.1 >nul

if not exist "%IDB%" (
  echo   [i] IndexedDB folder not found - may already be cleared. Reopening.
) else (
  echo   Renaming IndexedDB  ->  IndexedDB.bak-%TS%
  move "%IDB%" "%IDB%.bak-%TS%" >nul 2>&1
  if errorlevel 1 (
    echo   [X] Rename failed - Claude may still be running.
    echo       Close it fully ^(Ctrl+Shift+Esc ^> Claude ^> End task^) and re-run.
    goto :end
  )
)

call :launch
echo.
echo   ================= CHECK NOW =================
echo    Settings ^> Plugins ^> the stuck plugin
echo    Look for the NEW version number
echo   ============================================
echo.
choice /c YN /m "   Did the version flip to the new one"
if errorlevel 2 goto :stage2
goto :fixed_s1

REM =================== STAGE 2 - full ===================
:stage2
echo.
echo   --- Stage 2: RETIRED on safety grounds (v1.2) ---
echo.
echo   Stage 2 renamed the whole %%APPDATA%%\Claude folder. That folder now also holds:
echo     - claude_desktop_config.json  (your local MCP server config - does NOT come
echo       back after re-login; it is local, not synced)
echo     - local-agent-mode-sessions\  (the entire Cowork plugin store)
echo     - claude-code\                (the running Claude Code executable)
echo.
echo   Renaming it strands every Desktop plugin and takes local MCP config with it.
echo   On Windows it usually just fails on the open file handle anyway.
echo.
echo   If Stage 1 did not fix it, the cause is one of these instead:
echo     - Registry pin  -^> claude plugin update ^<plugin^>@^<marketplace^>, then verify
echo                        the version actually changed in installed_plugins.json
echo     - Still pinned  -^> claude plugin uninstall then install (rewrites the registry)
echo     - Cowork plugin -^> no local fix exists. Remove the plugin in Customize -^> Skills
echo                        so agent mode falls back to your CLI copy. See
echo                        github.com/anthropics/claude-code/issues/69683
echo.
goto :both_manual

REM =================== OUTCOMES ===================
:fixed_s1
echo.
echo   [OK] FIXED via Stage 1 (surgical clear).
echo        Backup: "%IDB%.bak-%TS%"
echo        Keep it a few days; delete once you're happy.
echo        (To undo: quit Claude, delete the new IndexedDB, rename the .bak back.)
goto :end

:both_manual
echo.
echo   Stopped before Stage 2. Stage 1 backup (if made): "%IDB%.bak-%TS%"
goto :end

:cancel
echo.
echo   Cancelled. Nothing was changed.
goto :end

REM =========== NON-INTERACTIVE MODES (--stage1 / --stage2) ===========
:auto_s1
echo   [auto] Stage 1: surgical clear (IndexedDB only)
echo   Quitting Claude...
powershell -NoProfile -Command "Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*AnthropicClaude*' -or $_.Path -like '*WindowsApps*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
ping -n 3 127.0.0.1 >nul
if not exist "%IDB%" (
  echo   [i] IndexedDB folder not found - may already be cleared.
) else (
  echo   Renaming IndexedDB  -^>  IndexedDB.bak-%TS%
  move "%IDB%" "%IDB%.bak-%TS%" >nul 2>&1
  if errorlevel 1 (
    echo   [X] Rename failed - close Claude fully and re-run.
    exit /b 1
  )
)
call :launch
echo   [OK] --stage1 complete. Backup kept (nothing deleted).
echo   NEXT: Claude Desktop ^> Settings ^> Plugins - check the plugin's version.
echo   Still on the old version? A bigger clear is NOT the answer - it is not a cache problem.
echo     Registry pin  -^> claude plugin update ^<plugin^>@^<marketplace^>, then confirm the
echo                      version really changed in installed_plugins.json
echo     Still pinned  -^> claude plugin uninstall then install (rewrites the registry)
echo     Cowork plugin -^> no local fix exists; remove it in Customize ^> Skills
exit /b 0

:s2_retired
echo   [X] Stage 2 is RETIRED on safety grounds (v1.2).
echo.
echo   It renamed the whole %%APPDATA%%\Claude folder, which now also holds your local
echo   MCP config (claude_desktop_config.json - it does NOT return after re-login), the
echo   entire Cowork plugin store, and the running Claude Code executable.
echo.
echo   Try instead: claude plugin update, then uninstall/install, then - for Cowork
echo   plugins - remove in Customize ^> Skills. See issues/69683.
exit /b 2

REM =================== CLI REGISTRY UPDATE HELPER ===================
REM The cache clear above fixes what the app DISPLAYS. The version that
REM actually LOADS is pinned in %USERPROFILE%\.claude\plugins\installed_plugins.json
REM (the plugin registry). If the claude CLI is installed, unpin it here while
REM Claude is closed: refresh each marketplace, then update every installed plugin.
:cli_update
where claude >nul 2>&1
if errorlevel 1 (
  echo   [i] claude CLI not found - skipping registry update.
  echo       If the version is STILL old after reopening: uninstall the plugin,
  echo       FULLY quit Claude, reopen, reinstall. That rewrites the registry.
  exit /b 0
)
echo   Updating the plugin registry via the claude CLI (may take a minute)...
powershell -NoProfile -Command "$reg = Join-Path $env:USERPROFILE '.claude\plugins\installed_plugins.json'; if (-not (Test-Path $reg)) { exit 0 }; $names = (Get-Content $reg -Raw | ConvertFrom-Json).plugins.PSObject.Properties.Name; $names | ForEach-Object { ($_ -split '@')[1] } | Sort-Object -Unique | ForEach-Object { claude plugin marketplace update $_ }; $names | ForEach-Object { claude plugin update $_ }"
exit /b 0

REM =================== LAUNCH HELPER ===================
:launch
call :cli_update
echo   Reopening Claude...
REM Standalone install first (AnthropicClaude), then Store app via its AppsFolder AUMID.
if exist "%LOCALAPPDATA%\AnthropicClaude\claude.exe" (
  start "" "%LOCALAPPDATA%\AnthropicClaude\claude.exe"
  exit /b 0
)
powershell -NoProfile -Command "$a = Get-StartApps | Where-Object { $_.Name -eq 'Claude' } | Select-Object -First 1; if (-not $a) { $a = Get-StartApps | Where-Object { $_.Name -like 'Claude*' -and $_.Name -notlike '*Code*' } | Select-Object -First 1 }; if ($a) { Start-Process ('shell:AppsFolder\' + $a.AppID); exit 0 } else { exit 1 }"
if not errorlevel 1 exit /b 0
echo   [i] Could not auto-launch Claude - please reopen it from the Start Menu.
exit /b 0

:end
echo.
pause
endlocal
