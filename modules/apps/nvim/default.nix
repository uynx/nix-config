{
  flake.homeModules.nvim =
    { config, pkgs, ... }:
    let
      home = "/home/uynx";
    in
    {
      home.packages = with pkgs; [
        (neovim.override {
          withNodeJs = true;
          withPython3 = true;
        })
        tree-sitter
        nil
        nixfmt
        statix
      ];

      home.file = {
        ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/nvim";
        ".local/share/nvim/site/parser/norg.so".source =
          "${pkgs.tree-sitter-grammars.tree-sitter-norg}/parser";
      };
    };
}
