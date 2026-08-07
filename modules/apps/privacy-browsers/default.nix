{
  flake.homeModules.privacyBrowsers =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.callPackage ./_tor-browser.nix { })
        (pkgs.callPackage ./_mullvad-browser.nix { })
      ];
    };
}
