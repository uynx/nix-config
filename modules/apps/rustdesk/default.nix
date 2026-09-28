{ self, inputs, ... }:
{
  flake.nixosModules.rustdesk =
    { pkgs, lib, ... }:
    {
      imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

      services.flatpak = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
        enable = true;

        remotes = [
          {
            name = "flathub";
            location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
          }
        ];

        packages = [ "com.rustdesk.RustDesk" ];

        update.onActivation = true;
      };
    };

  flake.homeModules.rustdesk =
    { pkgs, lib, ... }:
    let
      pin = builtins.fromJSON (builtins.readFile ./pins.json);
      path = "@v@/rustdesk-@v@-x86_64.deb";
      rustdesk = pkgs.stdenvNoCC.mkDerivation {
        pname = "rustdesk";
        inherit (pin) version;
        src = pkgs.fetchurl {
          url = "https://github.com/rustdesk/rustdesk/releases/download/${
            builtins.replaceStrings [ "@v@" ] [ pin.version ] path
          }";
          inherit (pin) hash;
        };
        nativeBuildInputs = [ pkgs.dpkg ];
        unpackCmd = "dpkg-deb -x $src source";
        dontFixup = true;
        installPhase = "cp -r usr/share $out";
      };
    in
    {
      imports = [ self.homeModules.x86Emu ];

      x86Apps = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
        rustdesk = {
          name = "RustDesk";
          exec = "${rustdesk}/rustdesk/rustdesk";
          icon = "${rustdesk}/icons/hicolor/256x256/apps/rustdesk.png";
          github = {
            repo = "rustdesk/rustdesk";
            inherit path;
            pins = "modules/apps/rustdesk/pins.json";
          };
        };
      };
    };
}
