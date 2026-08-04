{ inputs, self, ... }:
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
            (import ./_config.nix { tmuxNavigator = pkgs.vimPlugins.vim-tmux-navigator; })
          ];
        }).neovim;
    };

  flake.homeModules.nvim =
    { pkgs, ... }:
    {
      home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.nvim ];
    };
}
