{ self, ... }:
{
  flake.homeModules.cakeWallet =
    { pkgs, lib, ... }:
    let
      pin = builtins.fromJSON (builtins.readFile ./pins.json);
      path = "v@v@/Cake_Wallet_v@v@_Linux.tar.xz";
      cake = pkgs.stdenvNoCC.mkDerivation {
        pname = "cake-wallet";
        inherit (pin) version;
        src = pkgs.fetchurl {
          url = "https://github.com/cake-tech/cake_wallet/releases/download/${
            builtins.replaceStrings [ "@v@" ] [ pin.version ] path
          }";
          inherit (pin) hash;
        };
        dontFixup = true;
        installPhase = "cp -r . $out";
      };
    in
    {
      imports = [ self.homeModules.x86Emu ];

      x86Apps = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
        cake-wallet = {
          name = "Cake Wallet";
          exec = "${cake}/cake_wallet";
          icon = "${cake}/data/flutter_assets/assets/images/app_logo.png";
          github = {
            repo = "cake-tech/cake_wallet";
            inherit path;
            pins = "modules/apps/cake-wallet/pins.json";
          };
        };
      };
    };
}
