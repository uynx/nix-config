{
  flake.homeModules.office =
    { pkgs, lib, ... }:
    {
      home.packages = [
        pkgs.obsidian
      ]
      # nixpkgs builds LibreOffice for Linux only; darwin/office.nix casks it.
      ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.libreoffice;
    };
}
