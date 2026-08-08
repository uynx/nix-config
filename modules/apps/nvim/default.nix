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
              hostAttr = if isDarwin then "darwinConfigurations.darwin" else "nixosConfigurations.asahi";
              # nvf's default SCSS server, some-sass-language-server, pulls in
              # keytar, whose node-addon-api does not compile under Apple clang.
              # css.enable already installs the vscode server, so the Mac keeps
              # working SCSS and loses only the Sass-aware extras.
              scssServers =
                if isDarwin then [ "vscode-css-language-server" ] else [ "some-sass-language-server" ];
            })
          ];
        }).neovim;
    };

  flake.homeModules.nvim = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.nvim ];

      # Here rather than per host: the editor is what decides these, and both
      # hosts were restating the same two lines.
      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
    }
  );
}
