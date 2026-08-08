{
  flake.homeModules.office =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      home.packages = [
        pkgs.obsidian
        # Two different packages, not two platforms of one: the Linux build is
        # from source, `-bin` repackages the official DMG and is unfree.
        (if isDarwin then pkgs.libreoffice-bin else pkgs.libreoffice)
      ];

      # macOS installs LibreOffice as an .app, which has no CLI entry point.
      # Here rather than in the fish wrapper: the aliases are only correct on a
      # host that took this bundle, and the branch belongs beside the package
      # that forced it.
      programs.fish.shellAliases =
        if isDarwin then
          {
            word = "open -a LibreOffice --args --writer";
            powerpoint = "open -a LibreOffice --args --impress";
          }
        else
          {
            word = "libreoffice --writer";
            powerpoint = "libreoffice --impress";
          };
    };
}
