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
              # nixd evaluates this string at edit time on the machine running
              # neovim, so the host resolves from that machine's own
              # /etc/hostname rather than from a table here every new host would
              # have to be added to. The file carries a trailing newline, which
              # would make the attribute name miss. Darwin has exactly one
              # configuration and no /etc/hostname, so it stays a literal.
              hostAttr =
                if isDarwin then
                  "darwinConfigurations.darwin"
                else
                  ''nixosConfigurations.''${builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile /etc/hostname)}'';
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
