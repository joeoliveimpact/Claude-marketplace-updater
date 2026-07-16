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
if /i "%MODE%"=="--stage2" goto :auto_s2
if defined MODE (
  echo   [X] Unknown option "%MODE%". Use --stage1 or --stage2.
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
echo   --- Stage 2: full local reset (whole Claude folder) ---
echo   Bigger clear, still reversible. Your MCP servers reappear after re-login.
choice /c YN /m "   Run Stage 2 now"
if errorlevel 2 goto :both_manual

echo   Quitting Claude...
powershell -NoProfile -Command "Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*AnthropicClaude*' -or $_.Path -like '*WindowsApps*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
ping -n 3 127.0.0.1 >nul
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "TS2=%%t"

echo   Renaming Claude  ->  Claude.bak-%TS2%
move "%CLAUDE_DIR%" "%CLAUDE_DIR%.bak-%TS2%" >nul 2>&1
if errorlevel 1 (
  echo   [X] Rename failed - close Claude fully and re-run.
  goto :end
)

call :launch
echo.
echo   ================= CHECK AGAIN =================
echo    Settings ^> Plugins ^> the stuck plugin  ->  new version ?
echo   ==============================================
echo.
choice /c YN /m "   Did it flip to the new version now"
if errorlevel 2 goto :serverside
goto :fixed_s2

REM =================== OUTCOMES ===================
:fixed_s1
echo.
echo   [OK] FIXED via Stage 1 (surgical clear).
echo        Backup: "%IDB%.bak-%TS%"
echo        Keep it a few days; delete once you're happy.
echo        (To undo: quit Claude, delete the new IndexedDB, rename the .bak back.)
goto :end

:fixed_s2
echo.
echo   [OK] FIXED via Stage 2 (full clear).
echo        Backup: "%CLAUDE_DIR%.bak-%TS2%"  (your old settings/MCP live here)
echo        (To undo: quit Claude, delete the new Claude folder, rename the .bak back.)
goto :end

:serverside
echo.
echo   [!!] Both stages ran and it's STILL on the old version.
echo        That means the stale version is coming from Anthropic's servers -
echo        no client-side fix exists. Report "both failed" to Joe -> escalate.
echo        Your original setup is safe in: "%CLAUDE_DIR%.bak-%TS2%"
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
echo   Still on the old version? Re-run this script with --stage2 (full reset, reversible).
exit /b 0

:auto_s2
echo   [auto] Stage 2: full local reset (whole Claude folder)
echo   Quitting Claude...
powershell -NoProfile -Command "Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*AnthropicClaude*' -or $_.Path -like '*WindowsApps*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
ping -n 3 127.0.0.1 >nul
echo   Renaming Claude  -^>  Claude.bak-%TS%
move "%CLAUDE_DIR%" "%CLAUDE_DIR%.bak-%TS%" >nul 2>&1
if errorlevel 1 (
  echo   [X] Rename failed - close Claude fully and re-run.
  exit /b 1
)
call :launch
echo   [OK] --stage2 complete. Backup: "%CLAUDE_DIR%.bak-%TS%"
echo   NEXT: Claude Desktop ^> Settings ^> Plugins - check the plugin's version.
exit /b 0

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
