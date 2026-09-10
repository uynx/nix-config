{
  self,
  inputs,
  moduleWithSystem,
  ...
}:
{
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
              inherit (pkgs.vimPlugins) vimtex nvim-treesitter-textobjects;
              flakePath = "${self.lib.user.homeFor system}/nix-config";
              hostAttr =
                if isDarwin then
                  "darwinConfigurations.darwin"
                else
                  ''nixosConfigurations.''${builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile /etc/hostname)}'';
              inherit isDarwin;
            })
          ]
          ++ pkgs.lib.optional (!isDarwin) {
            vim.lsp.servers.some-sass-language-server.filetypes = [ "css" ];
          };
        }).neovim;
    };

  flake.homeModules.nvim = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.nvim ];

      programs.fish.shellAliases.v = "nvim";

      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
    }
  );
}
