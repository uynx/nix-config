{
  flake.homeModules.office =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.obsidian
        # Two different packages, not two platforms of one: the Linux build is
        # from source, `-bin` repackages the official DMG and is unfree.
        (if pkgs.stdenv.hostPlatform.isDarwin then pkgs.libreoffice-bin else pkgs.libreoffice)
      ];
    };
}
