{ inputs, ... }:
{
  flake.homeModules.sops =
    { config, pkgs, ... }:
    {
      imports = [ inputs.sops-nix.homeModules.sops ];

      home.packages = [ pkgs.sops ];

      # PGP backend rather than age. Setting gnupg.home also moves the
      # activation service into graphical-session-pre.target, which is what
      # lets pinentry-qt prompt for the passphrase at login.
      sops.gnupg.home = "${config.home.homeDirectory}/.gnupg";
    };
}
