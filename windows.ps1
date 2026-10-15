# Owns the Windows side of a fresh machine: WSL Ubuntu, WezTerm, its font, .wslconfig and the
# %USERPROFILE%\.wezterm.lua that loads the clone's config. Safe to run again. Self-contained on
# purpose: it must run with no clone beside it, so the two files it writes are text here.

$ErrorActionPreference = 'Stop'

function Step($n) { Write-Host "`n==> $n" -ForegroundColor Cyan }
function Note($m) { Write-Host "    $m" }

# The one source for the distro name: every WSL call and the WezTerm stub use it.
$distro = 'Ubuntu-24.04'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$wslConfig = @'
[wsl2]
memory=18GB
swap=4GB

[experimental]
autoMemoryReclaim=gradual
'@

# WezTerm reads nothing from the WSL home, so this loads the clone's config; until WSL answers, a
# plain terminal is enough to fix that.
$wezTermStubTemplate = @'
local wezterm = require("wezterm")

local ok, out = wezterm.run_child_process({
	"wsl.exe",
	"-d",
	"__WSL_DISTRO__",
	"-e",
	"sh",
	"-c",
	'wslpath -w "$HOME/.dotfiles/home/.config/wezterm/wezterm.lua"',
})

if ok then
	local path = out:gsub("%s+$", "")
	local chunk = loadfile(path)
	if chunk then
		-- \\wsl.localhost\<distro>\home\... - the distro is read off the path, never typed.
		WSL_DISTRO = path:match("^\\\\[^\\]+\\([^\\]+)\\")
		return chunk()
	end
end

local fallback = wezterm.config_builder()
fallback.color_scheme = "rose-pine-moon"
fallback.font = wezterm.font("Hack Nerd Font")
fallback.font_size = 15.0
return fallback
'@
$wezTermStub = $wezTermStubTemplate.Replace('__WSL_DISTRO__', $distro)

Step 'WSL'
# `wsl -l -q` answers from the registry, so it is true even while a fresh install waits for its
# reboot; the strings come back UTF-16, which PowerShell hands over with embedded NULs.
$installed = @(wsl.exe --list --quiet 2>$null | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
$targetInstalled = $installed -contains $distro
if ($targetInstalled) {
  Note "already installed: $distro"
} else {
  # Needs an administrator; without one Windows says so and this stops.
  wsl.exe --install -d $distro
  Note 'installed - reboot before launching it for the first time'
}

Step 'WezTerm'
if (Get-Command wezterm.exe -ErrorAction SilentlyContinue) {
  Note 'already installed'
} else {
  winget install --id wez.wezterm --exact --accept-package-agreements --accept-source-agreements
}

Step 'Hack Nerd Font'
# Per account: a copy into the profile's font directory plus an HKCU entry is what "Install for me"
# does, and it needs no administrator. These four faces are the family wezterm.lua asks for.
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontKey = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$faces = @('HackNerdFont-Regular', 'HackNerdFont-Bold', 'HackNerdFont-Italic', 'HackNerdFont-BoldItalic')
if (-not ($faces | Where-Object { -not (Test-Path -LiteralPath (Join-Path $fontDir "$_.ttf")) })) {
  Note 'already installed'
} else {
  $zip = Join-Path $env:TEMP 'Hack.zip'
  $unzip = Join-Path $env:TEMP 'Hack-nerd-font'
  Invoke-WebRequest -UseBasicParsing -OutFile $zip `
    'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip'
  Expand-Archive -LiteralPath $zip -DestinationPath $unzip -Force
  New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
  foreach ($face in $faces) {
    $dst = Join-Path $fontDir "$face.ttf"
    Copy-Item -LiteralPath (Join-Path $unzip "$face.ttf") -Destination $dst -Force
    New-ItemProperty -Path $fontKey -Name "$face (TrueType)" -Value $dst -PropertyType String -Force | Out-Null
  }
  Remove-Item -Recurse -Force $unzip, $zip
  Note "installed $($faces.Count) faces"
}

Step 'Profile files'
# A here-string drops the line break before its terminator; both of these are text files.
[IO.File]::WriteAllText((Join-Path $env:USERPROFILE '.wslconfig'), $wslConfig + "`n", $utf8NoBom)
[IO.File]::WriteAllText((Join-Path $env:USERPROFILE '.wezterm.lua'), $wezTermStub + "`n", $utf8NoBom)
Note 'wrote .wslconfig and .wezterm.lua'

Step 'Next'
# Run before the clone exists, it has to say where to go next.
$cloned = $targetInstalled -and ((wsl.exe -d $distro -e sh -c 'test -d "$HOME/.dotfiles" && echo yes') -match 'yes')
if ($cloned) {
  Note 'The clone is already there, so the Ubuntu side is done. Check it inside WSL: ~/.dotfiles/doctor.sh'
} else {
  Note 'Open Ubuntu, create your account, then do README.md#start-here inside it: the login, the clone'
  Note 'to ~/.dotfiles, and ~/.dotfiles/bootstrap.sh. Then run this file again, out of that clone:'
  Write-Host ''
  Write-Host '      Set-ExecutionPolicy -Scope Process Bypass -Force'
  Write-Host ('      & (wsl.exe -d {0} -e sh -c ''wslpath -w "$HOME/.dotfiles/windows.ps1"'')' -f $distro)
  Write-Host ''
}
