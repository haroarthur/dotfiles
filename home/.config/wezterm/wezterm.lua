-- Owns WezTerm on both hosts: linked to ~/.config/wezterm, and on Windows loaded out of the WSL clone
-- by the stub windows.ps1 writes to %USERPROFILE%\.wezterm.lua - so this file is the only copy.

local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Windows: the app talks to WSL Ubuntu, so open inside WSL at ~ (the launch dir would be /mnt/c), bind
-- splits to letters (the stock shifted punctuation is awkward on ABNT2), and skip the focus dim below.
if wezterm.target_triple:find("windows") then
	local act = wezterm.action
	-- The distro name is never typed here: %USERPROFILE%\.wezterm.lua resolved this file through
	-- wsl.exe and left the distro it came out of in WSL_DISTRO.
	if WSL_DISTRO then
		config.default_domain = "WSL:" .. WSL_DISTRO
	end
	config.default_cwd = "~"
	-- Without it the default WGL backend fails behind a DisplayLink dock ("LoadLibrary failed with error 126", no window).
	config.prefer_egl = true
	config.keys = {
		{ key = "d", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "e", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		{ key = "q", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
	}
	return config
end

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
	if actual == nil or expected == nil then
		return actual == expected
	end
	return actual.hue == expected.hue
		and actual.saturation == expected.saturation
		and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
	local overrides = window:get_config_overrides() or {}
	local text_hsb, opacity
	if not window:is_focused() then
		text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
		opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
	end

	-- Only write when one of the two values we own actually changes; a redundant
	-- set_config_overrides() call would trigger another config reload.
	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end)

return config
