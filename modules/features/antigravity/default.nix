{
  flake.homeModules.antigravity =
    { pkgs, lib, ... }:

    let
      home = "/home/uynx";
      H = "${pkgs.hyprland}/bin/hyprctl";
      J = "${pkgs.jq}/bin/jq";

      antigravity-launcher = pkgs.writeShellScriptBin "antigravity-launcher" ''
        set -eu

        HAS_WINDOW=$(${H} clients -j 2>/dev/null | ${J} -r '.[] | select(((.class // "") | ascii_downcase) == "antigravity") | .pid' 2>/dev/null || true)
        if [ -z "$HAS_WINDOW" ]; then
          ${pkgs.procps}/bin/pkill -f "/.local/share/antigravity/antigravity" 2>/dev/null || true
          sleep 0.1
        fi
        exec /home/uynx/.local/share/antigravity/antigravity "$@"
      '';
    in
    {
      home.packages = [ antigravity-launcher ];
      home.sessionVariables.AGY_CLI_DISABLE_AUTO_UPDATE = "true";

      xdg.desktopEntries.antigravity = {
        name = "Antigravity";
        genericName = "Text Editor";
        comment = "Antigravity AI Code Editor";
        exec = "${antigravity-launcher}/bin/antigravity-launcher %U";
        icon = "antigravity";
        type = "Application";
        categories = [
          "Development"
          "IDE"
        ];
      };

      home.activation.installAgy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${home}/.local/bin/agy" ]; then
          ${pkgs.curl}/bin/curl -fsSL https://antigravity.google.com/install.sh | ${pkgs.bash}/bin/bash || true
        fi
      '';
    };
}
