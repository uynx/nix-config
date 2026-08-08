{
  flake.homeModules.passwords =
    { pkgs, lib, ... }:
    {
      home.packages =
        with pkgs;
        [
          bitwarden-cli
          proton-pass-cli
        ]
        # The desktop app is Linux-only in nixpkgs; darwin/passwords.nix casks it.
        ++ lib.optional stdenv.hostPlatform.isLinux bitwarden-desktop;

      # Without this proton-pass-cli tries the system keyring, which nothing on a
      # niri session provides.
      home.sessionVariables.PROTON_PASS_KEY_PROVIDER = "fs";
    };
}
