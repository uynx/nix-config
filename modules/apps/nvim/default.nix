{
  self,
  inputs,
  moduleWithSystem,
  ...
}:
{
  # _config.nix is underscore-prefixed so import-tree skips it — it is not a
  # flake-parts module.
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      packages.nvim =
        (inputs.nvf.lib.neovimConfiguration {
          inherit pkgs;
          modules = [
            (import ./_config.nix {
              tmuxNavigator = pkgs.vimPlugins.vim-tmux-navigator;
              # nixd evaluates this path at edit time on the machine running
              # neovim, so both halves have to name that machine's own home and
              # its own host — a Linux path and `asahi` leave a Mac with no
              # option completion at all, and silently.
              flakePath = "${if isDarwin then self.lib.user.darwinHome else self.lib.user.home}/nixos-config";
              hostAttr = if isDarwin then "darwinConfigurations.darwin" else "nixosConfigurations.asahi";
            })
          ];
        }).neovim;
    };

  flake.homeModules.nvim = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.nvim ];
    }
  );
}
