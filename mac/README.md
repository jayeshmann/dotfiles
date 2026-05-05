# mac/

macOS-specific overlays. Run `bootstrap-mac.sh` from the repo root.

Currently empty — Mac uses cmux which has native Claude Code notification
support, so we don't ship a notify-attention.sh. The shared Notification
hook in `shared/claude/settings.json` is wrapped in a `[ -x ... ] && ...`
guard so it silently no-ops on Mac.

Most of `shared/` applies directly. Future additions, when needed:
- `tmux.conf` or `cmux/` config dump
- `iterm2/` or `ghostty/` profile dump
