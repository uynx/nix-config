{ inputs, self, ... }:
{
  # Neovim is a wrapped package built from nvf options rather than a symlink to
  # ~/dotfiles/nvim. LazyVim is gone: it fetched plugins from git at runtime, so
  # the editor was never reproducible and lazy-lock.json was the real config.
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
