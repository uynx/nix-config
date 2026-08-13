{
  flake.homeModules.passwords =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
    in
    {
      # macOS deliberately gets Bitwarden alone. Proton Pass is Linux-only here
      # until there is a reason to carry the second manager on both — ./darwin.nix
      # casks the desktop app, and nothing below it applies there.
      home.packages = [
        pkgs.bitwarden-cli
      ]
      ++ lib.optionals isLinux (
        with pkgs;
        [
          proton-pass-cli
          bitwarden-desktop
        ]
      );

      # Without this proton-pass-cli tries the system keyring, which nothing on a
      # niri session provides.
      home.sessionVariables = lib.mkIf isLinux {
        PROTON_PASS_KEY_PROVIDER = "fs";
      };

      # Bitwarden's own "start on login" toggle writes this file with the running
      # build's store path baked in, so the next version bump plus a GC leaves an
      # autostart entry pointing at nothing. Declaring it re-resolves per rebuild.
      #
      # No `--autostart`: that flag is the app's "start to tray" switch, and its
      # only effect is to skip the initial window.show() entirely.
      home.file = lib.mkIf isLinux {
        # Overwritten, not backed up: Bitwarden rewrites this every launch, so
        # a backup would collide with the previous one and fail the switch.
        ".config/autostart/bitwarden.desktop".force = true;
        ".config/autostart/bitwarden.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Bitwarden
          Exec=${lib.getExe pkgs.bitwarden-desktop}
          StartupNotify=false
          Terminal=false
        '';
      };

      xdg.mimeApps = lib.mkIf isLinux {
        enable = true;
        defaultApplications."x-scheme-handler/bitwarden" = "bitwarden.desktop";
      };

      # Drives proton-pass-cli, so it follows it rather than living in the fish
      # wrapper — on macOS there is no `pass-cli` for it to call.
      programs.fish = lib.mkIf isLinux {
        shellAliases.pf = "pass-find";

        functions.pass-find.body = ''
          if not pass-cli test >/dev/null 2>&1
              pass-cli test
              or return 1
          end
          pass-cli item list Personal --output json \
              | ${lib.getExe pkgs.jq} -r '(.items // .)[] | "[\((.item_type // .itemType // .type // "unknown") | ascii_upcase)] \(.title // .name)\t\(.id // .item_id // .itemId)"' \
              | ${lib.getExe pkgs.fzf} --ansi --header="Select an item to view credentials" --with-nth=1 \
              | string split \t | read -l display_name id
          if test -n "$id"
              pass-cli item view --vault-name Personal --item-id $id
          end
        '';
      };
    };
}
