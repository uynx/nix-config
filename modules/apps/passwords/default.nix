{
  flake.homeModules.passwords =
    { pkgs, lib, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
    in
    {
      home.packages =
        with pkgs;
        [
          bitwarden-cli
          proton-pass-cli
        ]
        # The desktop app is Linux-only in nixpkgs; ./darwin.nix casks it.
        ++ lib.optional isLinux bitwarden-desktop;

      # Without this proton-pass-cli tries the system keyring, which nothing on a
      # niri session provides. macOS has a real one, so it keeps the default.
      home.sessionVariables = lib.mkIf isLinux {
        PROTON_PASS_KEY_PROVIDER = "fs";
      };
    };
}
