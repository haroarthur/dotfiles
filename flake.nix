{
  description = "Home configuration at ~/.dotfiles for two hosts: WSL Ubuntu and Mac.";

  inputs = {
    # Release branches only, never a trunk: flake.lock holds the exact revision of each, and it moves
    # only when a bump is committed.
    nixpkgs-linux.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-linux,
      nix-darwin,
      nix-homebrew,
      home-manager,
    }:
    let
      linux = "x86_64-linux";
      # The one place this home names its account; the bootstrap scripts rewrite this line.
      user = "haro";
      pkgsLinux = nixpkgs-linux.legacyPackages.${linux};
      wslUbuntu = self.homeConfigurations."${user}@wsl-ubuntu".activationPackage;
    in
    {
      homeConfigurations."${user}@wsl-ubuntu" = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsLinux;
        modules = [ ./hosts/wsl-ubuntu.nix ];
        extraSpecialArgs = { inherit user; };
      };

      # Never apply this from the WSL host.
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user; };
        modules = [
          ./hosts/darwin-mac.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user; };
            home-manager.users.${user} = import ./hosts/mac.nix;
          }
        ];
      };

      formatter.${linux} = pkgsLinux.nixfmt-tree;

      checks.${linux} = {
        wsl-ubuntu-build = wslUbuntu;

        # `nix flake check` does not know `darwinConfigurations`, so this forces the Mac to evaluate
        # on Linux; discarding the string context keeps it an evaluation rather than a Darwin build.
        mac-eval = pkgsLinux.runCommand "dotfiles-mac-eval" { } ''
          echo ${builtins.unsafeDiscardStringContext self.darwinConfigurations.mac.config.system.build.toplevel.drvPath} > "$out"
        '';

        # The guard rebuild.sh and bootstrap.sh build before they switch: a green build cannot tell a
        # full profile from one missing the pane shell or the units, and activating that one stops
        # every agent pane. The Herdr binary is install-tools.sh's now, so it is doctor.sh that
        # answers for it rather than this.
        wsl-ubuntu-safe = pkgsLinux.runCommand "wsl-ubuntu-safe" { } ''
          for p in home-path/bin/zsh home-path/bin/herdr-pane-shell \
            home-files/.config/systemd/user/herdr.service home-files/.config/systemd/user/herdr-panes.slice; do
            [ -e ${wslUbuntu}/"$p" ] || { echo "wsl-ubuntu-safe: the generation has no $p" >&2; exit 1; }
          done
          touch "$out"
        '';
      };
    };
}
