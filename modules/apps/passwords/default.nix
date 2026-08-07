{
  flake.homeModules.passwords = { pkgs, ... }: {
    home.packages = with pkgs; [
      bitwarden-desktop
      bitwarden-cli
      proton-pass-cli
    ];

    # Without this proton-pass-cli tries the system keyring, which nothing on a
    # niri session provides.
    home.sessionVariables.PROTON_PASS_KEY_PROVIDER = "fs";
  };
}
