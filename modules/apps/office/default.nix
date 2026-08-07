{
  flake.homeModules.office = { pkgs, ... }: {
    home.packages = with pkgs; [
      obsidian
      libreoffice
    ];
  };
}
