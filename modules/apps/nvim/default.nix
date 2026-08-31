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
    { pkgs, system, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      packages.nvim =
        (inputs.nvf.lib.neovimConfiguration {
          inherit pkgs;
          modules = [
            (import ./_config.nix {
              c = self.lib.flexoki;
              tmuxNavigator = pkgs.vimPlugins.vim-tmux-navigator;
              # nixd evaluates this path at edit time on the machine running
              # neovim, so both halves have to name that machine's own home and
              # its own host — a Linux path and `asahi` leave a Mac with no
              # option completion at all, and silently.
              flakePath = "${self.lib.user.homeFor system}/nixos-config";
              hostAttr =
                if isDarwin then
                  "darwinConfigurations.darwin"
                else if system == "x86_64-linux" then
                  "nixosConfigurations.x86"
                else
                  "nixosConfigurations.asahi";
              inherit isDarwin;
            })
          ]
          ++ pkgs.lib.optional (!isDarwin) {
            # Some Sass handles plain CSS too, but nvf's scss module attaches it
            # to scss/sass only. On Linux it is the sole CSS-family server, so it
            # takes css as well — this list concatenates with nvf's, so naming
            # scss or sass here would duplicate them.
            vim.lsp.servers.some-sass-language-server.filetypes = [ "css" ];
          };
        }).neovim;
    };

  flake.homeModules.nvim = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.nvim ];

      # Only `v`: nvf's viAlias/vimAlias already ship `vi` and `vim` as real
      # binaries in the package.
      programs.fish.shellAliases.v = "nvim";

      # Here rather than per host: the editor is what decides these, and both
      # hosts were restating the same two lines.
      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
    }
  );
}
