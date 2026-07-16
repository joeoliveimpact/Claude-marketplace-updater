#!/bin/bash
# ============================================================
#  Claude Desktop marketplace-sync fixer  -  macOS
#  Fixes plugins stuck on an old version after an update
#  was published.
#
#  Staged + FULLY REVERSIBLE: folders are RENAMED with a
#  timestamp, never deleted. Restore steps printed at the end.
#  Runbook: docs/marketplace-sync-fix-test.md  (CNTNTSE-139)
#
#  Run (recommended): open Terminal and paste:
#      bash ~/Downloads/fix-marketplace-sync-macos.command
#  (Double-click also works, but a downloaded .command is quarantined.
#   On macOS 15 use System Settings > Privacy & Security > Open Anyway.
#   The bash line above avoids the block entirely.)
# ============================================================

set -u
CLAUDE_DIR="$HOME/Library/Application Support/Claude"
IDB="$CLAUDE_DIR/IndexedDB"
MODE="${1:-}"   # --stage1 / --stage2 = non-interactive (for Claude Code-driven runs)

echo
echo "  ================================================================"
echo "   CLAUDE MARKETPLACE SYNC FIXER  (macOS)"
echo "  ================================================================"
echo
echo "   Your Claude plugins are stuck on an old version. GitHub has the"
echo "   new one; Claude Desktop is holding a stale local cache. This"
echo "   clears that cache so the new version can sync."
echo
echo "   IMPORTANT:"
echo "     - This will FULLY QUIT Claude Desktop (you will re-login)."
echo "     - If you are reading this inside Claude, finish your work first."
echo "     - Nothing is deleted. Folders are renamed to .bak-<time> and"
echo "       can be restored (steps shown at the end)."
echo
if [ -z "$MODE" ]; then
  printf "   Type yes and press Enter to continue (anything else cancels): "
  read -r GO
  GO="$(printf '%s' "$GO" | tr '[:upper:]' '[:lower:]')"
  if [ "$GO" != "yes" ] && [ "$GO" != "y" ]; then echo; echo "   Cancelled. Nothing was changed."; exit 0; fi
fi

if [ ! -d "$CLAUDE_DIR" ]; then
  echo
  echo "   [X] Could not find:"
  echo "       $CLAUDE_DIR"
  echo "       Is Claude Desktop installed for this Mac user?"
  echo; read -r -p "   Press Enter to close."; exit 1
fi

quit_claude() {
  echo "   Quitting Claude..."
  osascript -e 'quit app "Claude"' >/dev/null 2>&1
  sleep 1
  pkill -x "Claude" >/dev/null 2>&1
  sleep 2
}

cli_update() {
  # The cache clear fixes what the app DISPLAYS. The version that actually
  # LOADS is pinned in ~/.claude/plugins/installed_plugins.json (the plugin
  # registry). If the claude CLI is installed, unpin it here while Claude is
  # closed: refresh each marketplace, then update every installed plugin.
  local reg="$HOME/.claude/plugins/installed_plugins.json"
  if ! command -v claude >/dev/null 2>&1; then
    echo "   [i] claude CLI not found - skipping registry update."
    echo "       If the version is STILL old after reopening: uninstall the plugin,"
    echo "       FULLY quit Claude, reopen, reinstall. That rewrites the registry."
    return 0
  fi
  [ -f "$reg" ] || return 0
  echo "   Updating the plugin registry via the claude CLI (may take a minute)..."
  local plugins
  plugins="$(grep -oE '"[A-Za-z0-9._-]+@[A-Za-z0-9._-]+"' "$reg" | tr -d '"' | sort -u)"
  printf '%s\n' "$plugins" | awk -F@ '{print $2}' | sort -u | while read -r m; do
    [ -n "$m" ] && claude plugin marketplace update "$m"
  done
  printf '%s\n' "$plugins" | while read -r p; do
    [ -n "$p" ] && claude plugin update "$p"
  done
  return 0
}

launch_claude() {
  cli_update
  echo "   Reopening Claude..."
  open -a "Claude" >/dev/null 2>&1 || echo "   [i] Could not auto-launch - open Claude manually."
}

# ========== NON-INTERACTIVE MODES (--stage1 / --stage2) ==========
# For Claude Code-driven runs: no prompts, one stage per invocation.
if [ -n "$MODE" ] && [ "$MODE" != "--stage1" ] && [ "$MODE" != "--stage2" ]; then
  echo "   [X] Unknown option '$MODE'. Use --stage1 or --stage2."
  exit 2
fi
if [ -n "$MODE" ]; then
  quit_claude
  TS="$(date +%Y%m%d-%H%M%S)"
  if [ "$MODE" = "--stage1" ]; then
    if [ -d "$IDB" ]; then
      echo "   Renaming IndexedDB  ->  IndexedDB.bak-$TS"
      mv "$IDB" "$IDB.bak-$TS" || { echo "   [X] Rename failed - close Claude fully and re-run."; exit 1; }
    else
      echo "   [i] IndexedDB folder not found - may already be cleared."
    fi
  else
    echo "   Renaming Claude folder  ->  Claude.bak-$TS"
    mv "$CLAUDE_DIR" "$CLAUDE_DIR.bak-$TS" || { echo "   [X] Rename failed - close Claude fully and re-run."; exit 1; }
  fi
  launch_claude
  echo
  echo "   [OK] $MODE complete. Backup kept (nothing deleted)."
  echo "   NEXT: Claude Desktop > Settings > Plugins - check the plugin's version."
  if [ "$MODE" = "--stage1" ]; then
    echo "   Still on the old version? Re-run this script with --stage2 (full reset, reversible)."
  fi
  exit 0
fi

# =================== STAGE 1 - surgical ===================
echo
echo "   --- Stage 1: surgical clear (IndexedDB only) ---"
quit_claude
TS="$(date +%Y%m%d-%H%M%S)"

if [ ! -d "$IDB" ]; then
  echo "   [i] IndexedDB folder not found - may already be cleared. Reopening."
else
  echo "   Renaming IndexedDB  ->  IndexedDB.bak-$TS"
  if ! mv "$IDB" "$IDB.bak-$TS"; then
    echo "   [X] Rename failed - close Claude fully and re-run."
    read -r -p "   Press Enter to close."; exit 1
  fi
fi

launch_claude
echo
echo "   ================= CHECK NOW ================="
echo "    Settings > Plugins > the stuck plugin"
echo "    Look for the NEW version number"
echo "   ============================================"
echo
printf "   Did the version flip to the new one?  (y/n): "
read -r A1
A1="$(printf '%s' "$A1" | tr '[:upper:]' '[:lower:]')"
if [ "$A1" = "y" ] || [ "$A1" = "yes" ]; then
  echo
  echo "   [OK] FIXED via Stage 1 (surgical clear)."
  echo "        Backup: $IDB.bak-$TS"
  echo "        (To undo: quit Claude, delete the new IndexedDB, rename the .bak back.)"
  read -r -p "   Press Enter to close."; exit 0
fi

# =================== STAGE 2 - full ===================
echo
echo "   --- Stage 2: full local reset (whole Claude folder) ---"
echo "   Bigger clear, still reversible. Your MCP servers reappear after re-login."
printf "   Run Stage 2 now?  (y/n): "
read -r S2
S2="$(printf '%s' "$S2" | tr '[:upper:]' '[:lower:]')"
if [ "$S2" != "y" ] && [ "$S2" != "yes" ]; then
  echo "   Stopped before Stage 2. Stage 1 backup (if made): $IDB.bak-$TS"
  read -r -p "   Press Enter to close."; exit 0
fi

quit_claude
TS2="$(date +%Y%m%d-%H%M%S)"
echo "   Renaming Claude folder  ->  Claude.bak-$TS2"
if ! mv "$CLAUDE_DIR" "$CLAUDE_DIR.bak-$TS2"; then
  echo "   [X] Rename failed - close Claude fully and re-run."
  read -r -p "   Press Enter to close."; exit 1
fi

launch_claude
echo
echo "   ================= CHECK AGAIN ================="
echo "    Settings > Plugins > the stuck plugin  ->  new version ?"
echo "   =============================================="
echo
printf "   Did it flip to the new version now?  (y/n): "
read -r A2
A2="$(printf '%s' "$A2" | tr '[:upper:]' '[:lower:]')"
if [ "$A2" = "y" ] || [ "$A2" = "yes" ]; then
  echo
  echo "   [OK] FIXED via Stage 2 (full clear)."
  echo "        Backup: $CLAUDE_DIR.bak-$TS2  (old settings/MCP live here)"
  echo "        (To undo: quit Claude, delete the new Claude folder, rename the .bak back.)"
else
  echo
  echo "   [!!] Both stages ran and it's STILL on the old version."
  echo "        The stale version is coming from Anthropic's servers -"
  echo "        no client-side fix exists. Report \"both failed\" to Joe -> escalate."
  echo "        Your original setup is safe in: $CLAUDE_DIR.bak-$TS2"
fi
read -r -p "   Press Enter to close."
exit 0
