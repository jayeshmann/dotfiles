-- ~/.wezterm.lua
local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- ============================================================
-- Appearance
-- ============================================================
config.color_scheme = 'Tokyo Night'
config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'JetBrains Mono',
  'Segoe UI Emoji',
}
config.font_size = 11.0
config.line_height = 1.1
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' } -- ligatures on

config.window_background_opacity = 0.97
config.window_decorations = 'TITLE | RESIZE'
config.window_padding = { left = 8, right = 8, top = 6, bottom = 0 }

-- ============================================================
-- Active vs inactive emphasis
-- ============================================================
-- Inactive panes get desaturated and dimmed; the focused pane stays at full
-- color/brightness. Tokyo Night already runs cool, so the active pane reads
-- as the warm/bright one when several panes are split.
config.inactive_pane_hsb = {
  saturation = 0.55,
  brightness = 0.55,
}

-- Make the seams between panes a vivid Tokyo Night magenta so the active
-- region's borders are immediately visible.
config.colors = {
  split = '#bb9af7',
  cursor_bg = '#c0caf5',
  cursor_border = '#c0caf5',
  cursor_fg = '#1a1b26',
}
config.initial_cols = 180
config.initial_rows = 48
config.adjust_window_size_when_changing_font_size = false

-- ============================================================
-- Tabs
-- ============================================================
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32

-- ============================================================
-- WSL as the default shell — this is the important bit
-- ============================================================
config.default_domain = 'WSL:Ubuntu-24.04'
-- If your distro has a different name, run `wsl -l -v` in PowerShell
-- and replace 'Ubuntu' above. Common values: Ubuntu, Ubuntu-24.04.

config.default_cwd = wezterm.home_dir .. '/code'

-- ============================================================
-- Performance
-- ============================================================
config.front_end = 'WebGpu'           -- GPU accel
config.max_fps = 120
config.animation_fps = 60
config.scrollback_lines = 50000

-- ============================================================
-- Keybindings — tmux-style without needing tmux
-- Leader is Ctrl+a (like tmux). All splits/tabs go through it.
-- ============================================================
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1500 }

config.keys = {
  -- Splits
  { key = '|', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-', mods = 'LEADER',       action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },

  -- Pane navigation (vim-style, no leader needed — just Ctrl+hjkl)
  { key = 'h', mods = 'CTRL',  action = act.ActivatePaneDirection 'Left'  },
  { key = 'j', mods = 'CTRL',  action = act.ActivatePaneDirection 'Down'  },
  { key = 'k', mods = 'CTRL',  action = act.ActivatePaneDirection 'Up'    },
  { key = 'l', mods = 'CTRL',  action = act.ActivatePaneDirection 'Right' },

  -- Pane resize (leader + hjkl)
  { key = 'h', mods = 'LEADER', action = act.AdjustPaneSize { 'Left',  5 } },
  { key = 'j', mods = 'LEADER', action = act.AdjustPaneSize { 'Down',  5 } },
  { key = 'k', mods = 'LEADER', action = act.AdjustPaneSize { 'Up',    5 } },
  { key = 'l', mods = 'LEADER', action = act.AdjustPaneSize { 'Right', 5 } },

  -- Close pane
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },

  -- Zoom current pane (toggle fullscreen within window)
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },

  -- Tabs
  { key = 't', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'LEADER', action = act.CloseCurrentTab { confirm = true } },
  { key = '1', mods = 'LEADER', action = act.ActivateTab(0) },
  { key = '2', mods = 'LEADER', action = act.ActivateTab(1) },
  { key = '3', mods = 'LEADER', action = act.ActivateTab(2) },
  { key = '4', mods = 'LEADER', action = act.ActivateTab(3) },
  { key = '5', mods = 'LEADER', action = act.ActivateTab(4) },

  -- Copy mode (vim-style scrollback search)
  { key = '[', mods = 'LEADER', action = act.ActivateCopyMode },

  -- Quick reload of this config
  { key = 'r', mods = 'LEADER', action = act.ReloadConfiguration },

  -- Standard copy/paste (Windows expects Ctrl+Shift+C/V in terminals)
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo  'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
  { key = 'Enter', mods = 'SHIFT', action = wezterm.action.SendString '\x1b\r' },
  -- One-handed pane management (no leader needed)
{ key = 'd', mods = 'CTRL|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
{ key = 'e', mods = 'CTRL|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },
{ key = 'x', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },
}

-- ============================================================
-- Mouse bindings: select-to-copy + right-click to paste
-- ============================================================
config.mouse_bindings = {
  -- Right click pastes from clipboard
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },

  -- Left click drag selects, release auto-copies to clipboard
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.CompleteSelectionOrOpenLinkAtMouseCursor 'ClipboardAndPrimarySelection',
  },

  -- Triple-click selects a whole line and copies
  {
    event = { Up = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
  },

  -- Double-click selects a word and copies
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
  },

  -- Ctrl+click opens links (preserves the default link-open behavior)
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

-- ============================================================
-- Quick three-pane layout for Claude Code workflow
-- LEADER + Space spawns: editor | claude code  /  lazygit
-- ============================================================
wezterm.on('gui-startup', function(cmd)
  wezterm.mux.spawn_window(cmd or {})
end)

-- ============================================================
-- Drop window opacity when wezterm itself loses focus, so the active
-- window is obvious when multiple wezterm windows are open.
-- ============================================================
wezterm.on('window-focus-changed', function(window, _pane)
  local overrides = window:get_config_overrides() or {}
  if window:is_focused() then
    overrides.window_background_opacity = 0.97
  else
    overrides.window_background_opacity = 0.78
  end
  window:set_config_overrides(overrides)
end)

-- ============================================================
-- Tab title: show what's actually running, not just "zsh"
-- ============================================================
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local pane = tab.active_pane
  local title = pane.title or ''

  -- Strip the user@host: prefix that some shells add
  title = string.gsub(title, '^.-:%s*', '')

  -- If the foreground process gives us a clearer name, prefer that
  local proc = pane.foreground_process_name or ''
  if proc ~= '' then
    proc = string.gsub(proc, '(.*[/\\])(.*)', '%2')  -- basename
    -- Show the process name if it's something interesting
    if proc ~= 'zsh' and proc ~= 'bash' and proc ~= 'sh' then
      title = proc .. (title ~= '' and ' · ' .. title or '')
    end
  end

  -- Truncate
  if #title > 28 then
    title = title:sub(1, 25) .. '…'
  end

  local index = tab.tab_index + 1
  local prefix = tab.is_active and '▎ ' or '  '
  return {
    { Text = prefix .. index .. ': ' .. title .. ' ' },
  }
end)

return config