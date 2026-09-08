{
  # nixpkgs' `flutter` wrapper hard-references `aapt` for the Android toolchain,
  # and aapt is a Google-built x86_64 binary with no aarch64-linux release — so
  # every Flutter app stopped *evaluating* on asahi with the 2026-09-08 lock
  # bump. The stub satisfies the reference; nothing here ever builds an APK.
  # Drop it once nixpkgs makes that reference conditional.
  flake.nixosModules.enteAuth =
    { lib, ... }:
    {
      nixpkgs.overlays = [
        (
          _: prev:
          lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
            aapt = prev.writeShellScriptBin "aapt2" "exit 1";
          }
        )
      ];
    };

  flake.homeModules.enteAuth =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
    in
    {
      home.packages = lib.optional isLinux pkgs.ente-auth;
    };
}
