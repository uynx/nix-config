{
  flake.homeModules.office =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      home.packages = [
        pkgs.obsidian
        (if isDarwin then pkgs.libreoffice-bin else pkgs.libreoffice)
      ];

      programs.fish.shellAliases =
        let
          lo = if isDarwin then "open -a LibreOffice --args" else "libreoffice";
        in
        {
          word = "${lo} --writer";
          excel = "${lo} --calc";
          powerpoint = "${lo} --impress";
        };
    };
}
