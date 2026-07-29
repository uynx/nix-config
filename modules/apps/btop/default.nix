{ self, ... }:
{
  # First wrapped program. Unlike the home-manager modules under this tree, the
  # config here is baked into the derivation rather than written to ~/.config:
  # the wrapper passes --config and --themes-dir pointing at store paths, so
  # this btop carries its own settings and needs no home directory at all.
  #
  # Consequences worth knowing:
  #   * `nix run ~/nixos-config#btop` gives a themed btop on any machine.
  #   * The theme file no longer appears in ~/.config/btop/themes/.
  #   * Editing this file rebuilds the package, so there is no live-edit loop
  #     the way there is with a mutable config file.
  flake.wrappers.btop =
    { wlib, ... }:
    {
      imports = [ wlib.wrapperModules.btop ];

      settings.color_theme = "flexoki";

      # Passed as a path, which the wrapper copies into its themes dir. The file
      # came out of noctalia's theming template originally; `color_theme` above
      # resolves against the name given here.
      themes.flexoki = ./flexoki.theme;
    };

  # Installs the wrapper built above. Indexed by the evaluating system rather
  # than taken from self' so this stays a plain home module usable by any host.
  flake.homeModules.btop =
    { pkgs, ... }:
    {
      home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.btop ];
    };
}
