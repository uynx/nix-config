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
    {
      packages.nvim =
        (inputs.nvf.lib.neovimConfiguration {
          inherit pkgs;
          modules = [
            (import ./_config.nix {
              tmuxNavigator = pkgs.vimPlugins.vim-tmux-navigator;
              flakePath = "${self.lib.user.home}/nixos-config";
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
