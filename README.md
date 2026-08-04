# Claude Marketplace Updater

Force-updates Claude Desktop plugins that are **stuck on an old version** — the marketplace
published a new release, but your installed plugin won't move (and "check for updates" does
nothing). The usual cause is the plugin registry (`installed_plugins.json`) still pointing at the old version while the new one sits unused in the cache. A display-cache clear alone does not move it; these scripts clear it so
the new version syncs.

**Staged and fully reversible:** folders are *renamed* with a timestamp, never deleted. Every
run prints the backup path and how to undo it.

| File | OS |
|------|----|
| `fix-marketplace-sync-macos.command` | macOS |
| `fix-marketplace-sync-windows.bat` | Windows |

---

## Fastest path — ask Claude to run it

Works from a **Claude Desktop chat** or **Claude Code in a terminal**. Paste:

> Download the stuck-plugin fixer for my OS from
> https://github.com/joeoliveimpact/Claude-marketplace-updater and run it **detached** with
> `--stage1`. Claude Desktop will close and reopen mid-fix — that's expected.

The reference commands Claude will use (detached, so the fix keeps running while Claude
Desktop restarts):

```bash
# macOS
curl -fsSL https://raw.githubusercontent.com/joeoliveimpact/Claude-marketplace-updater/main/fix-marketplace-sync-macos.command -o /tmp/cmu.command
(nohup bash /tmp/cmu.command --stage1 >/tmp/cmu-updater.log 2>&1 &)
```

```powershell
# Windows (PowerShell)
curl.exe -fsSL https://raw.githubusercontent.com/joeoliveimpact/Claude-marketplace-updater/main/fix-marketplace-sync-windows.bat -o "$env:TEMP\cmu.bat"
Start-Process "$env:TEMP\cmu.bat" -ArgumentList '--stage1'
```

Running with `claude --dangerously-skip-permissions` (bypass-permissions mode) executes
without approval prompts; in normal mode Claude asks you to approve the two commands once.

### What to expect when you run it from inside Claude Desktop
The fix **quits Claude Desktop** as its first move — your chat disappears with it. That's
fine: the script runs detached, finishes the fix, and reopens Claude Desktop. Reopen your
session (it's right where you left it), then check **Settings → Plugins** — or ask Claude to
read the log (macOS: `/tmp/cmu-updater.log`). Claude Code terminal sessions are never
touched — the scripts only target the Desktop app.

---

## Stages

- **`--stage1` (start here)** — surgical: clears the `IndexedDB` display cache, then (if
  the `claude` CLI is installed) updates the plugin version registry
  (`~/.claude/plugins/installed_plugins.json`) — the file that decides which version
  actually loads — and relaunches Claude. Fixes most stalls.
- **`--stage2` (only if stage 1 didn't flip the version)** — full local reset: renames the
  whole Claude app-data folder (plus the same registry update). You re-login after; your
  old state is kept in the backup.

After either stage: open **Claude Desktop → Settings → Plugins** and check the plugin's
version. Config for REVXL-style plugins is safe — it lives outside the plugin install
(`${CLAUDE_PLUGIN_DATA}` and `~/.claude/revxl/`) and is never touched.

**How often?** Once per incident. When the cache unwedges, updates flow normally again. If a
future update wedges the same way, run it again.

No flag = interactive mode: the script walks you through the same stages with prompts
(`yes` to start, any case).

---

## Running by double-click (no Claude Code)

- **macOS:** a downloaded `.command` is quarantined — double-clicking triggers a "can't check
  it for malware" block (on macOS 15 the only click-through is System Settings → Privacy &
  Security → **Open Anyway**). Skip all of that by running it through Terminal:
  `bash ~/Downloads/fix-marketplace-sync-macos.command`
  Prefer double-click? Clear the flag once first:
  `xattr -d com.apple.quarantine ~/Downloads/fix-marketplace-sync-macos.command`
- **Windows:** double-click works. If you get an "Open File - Security Warning," click
  **Run** (or right-click → Properties → **Unblock** once).

## Restore (undo)

- Stage 1: quit Claude → delete the new `IndexedDB` → rename `IndexedDB.bak-<timestamp>` back.
- Stage 2: quit Claude → delete the new `Claude` folder → rename `Claude.bak-<timestamp>` back.

App-data locations: Windows `%APPDATA%\Claude` · macOS `~/Library/Application Support/Claude`.

## License

MIT — see [LICENSE](LICENSE).

## Stage 2 is retired (v1.2)

Stage 2 renamed the entire Claude app-data folder. That folder now also holds
`claude_desktop_config.json` (local MCP config, which does **not** come back after
re-login), the Cowork plugin store, and the running Claude Code executable. Renaming it
strands every Desktop plugin. Passing `--stage2` now refuses with an explanation.

If stage 1 does not fix it, the cause is one of:

- **Registry pin** — `claude plugin update <plugin>@<marketplace>`, then confirm the
  version really changed in `installed_plugins.json`.
- **Still pinned** — `claude plugin uninstall` then `install` (rewrites the registry).
- **Cowork plugin** — no local fix exists; Anthropic serves it from their side. Remove it
  in Customize → Skills so agent mode falls back to your CLI copy.
  ([#69683](https://github.com/anthropics/claude-code/issues/69683))
