{ moduleWithSystem, ... }:
{
  flake.wrappers.bat =
    { pkgs, wlib, ... }:
    let
      # Ghostty ships the syntax. Home Manager used to wire it up against
      # ~/.config/ghostty/config, which stopped existing once ghostty's config
      # was baked into its package, so the mapping now targets the copy in this
      # repo — the one anyone actually reads.
      configDir = pkgs.runCommand "bat-config" { nativeBuildInputs = [ pkgs.bat ]; } ''
        mkdir -p $out/syntaxes $out/cache
        cp ${pkgs.ghostty}/share/bat/syntaxes/ghostty.sublime-syntax $out/syntaxes/
        BAT_CONFIG_DIR=$out BAT_CACHE_PATH=$out/cache bat cache --build
      '';
    in
    {
      imports = [ wlib.modules.default ];

      package = pkgs.bat;

      env = {
        # BAT_CONFIG_DIR supplies syntaxes; BAT_CACHE_PATH is the compiled set
        # bat actually reads. Neither carries options — see the flag below.
        BAT_CONFIG_DIR = configDir;
        BAT_CACHE_PATH = "${configDir}/cache";
      };

      # A flag, not a line in bat's config file: bat 0.26.1 reads the config
      # file (--diagnostic confirms it) but ignores --map-syntax from there,
      # while honouring the identical value on the command line. The glob needs
      # `**`, since `*` does not cross directory separators.
      flagSeparator = "=";
      flags."--map-syntax" = "**/ghostty/config:Ghostty Config";
    };

  flake.homeModules.bat = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.bat ];
    }
  );
}
