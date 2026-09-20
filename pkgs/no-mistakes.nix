{ config, ... }:

# Owns the one thing the official no-mistakes installer does not: a systemd drop-in giving the daemon
# its umask (else pipeline fixtures go group-writable) and a PATH with the tools a run shells out to.
# The unit name hashes the state root, so it can stop matching silently - doctor.sh asserts the effect.

{
  xdg.configFile."systemd/user/no-mistakes-daemon-${
    builtins.substring 0 8 (builtins.hashString "sha256" "${config.home.homeDirectory}/.no-mistakes")
  }.service.d/10-no-mistakes.conf".text =
    ''
      [Service]
      UMask=0022
      Environment="PATH=%h/.nix-profile/bin:/nix/var/nix/profiles/default/bin:%h/.local/bin:%h/go/bin:%h/.cargo/bin:%h/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    '';
}
