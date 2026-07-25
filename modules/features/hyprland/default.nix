{
  flake.homeModules.hyprland =
    { config, pkgs, ... }:

    let
      home = "/home/uynx";
      H = "${pkgs.hyprland}/bin/hyprctl";
      J = "${pkgs.jq}/bin/jq";
    workspace-switcher = pkgs.writeShellScriptBin "workspace-switcher" ''
      KEY=$1
      ACTION=''${2:-goto}
      STATE=/tmp/hyprland_merged_workspaces
      HDMI=$(grep -q "^connected$" /sys/class/drm/*-HDMI-A-1/status 2>/dev/null && echo 1 || echo 0)

      if [ "$ACTION" = sync ]; then
        if [ "$HDMI" = 0 ]; then
          if [ ! -f "$STATE" ]; then
            CUR=$(${H} activeworkspace -j | ${J} -r .id)
            : >"$STATE"
            ${H} clients -j | ${J} -r '.[]|select(.workspace.id>=4 and .workspace.id<=6)|"\(.workspace.id):\(.address)"' |
              while IFS=: read -r ws addr; do
                echo "$ws:$addr" >>"$STATE"
                ${H} dispatch movetoworkspacesilent "$((ws - 3)),address:$addr"
              done
            [ "$CUR" -ge 4 ] && [ "$CUR" -le 6 ] && ${H} dispatch workspace "$((CUR - 3))"
          fi
        else
          for ws in 1 2 3; do ${H} dispatch moveworkspacetomonitor "$ws HDMI-A-1"; done
          if [ -f "$STATE" ]; then
            while IFS=: read -r o a; do ${H} dispatch movetoworkspacesilent "$o,address:$a"; done <"$STATE"
            rm -f "$STATE"
          fi
        fi
        exit 0
      fi

      BASE=1
      if [ "$HDMI" = 1 ]; then
        [ "$(${H} monitors -j | ${J} -r '.[]|select(.focused==true)|.name')" != HDMI-A-1 ] && BASE=4
      fi
      case "$KEY" in
        u) T=$BASE ;; i) T=$((BASE + 1)) ;; o) T=$((BASE + 2)) ;; *) exit 1 ;;
      esac
      ${H} dispatch "$([ "$ACTION" = move ] && echo movetoworkspace || echo workspace)" "$T"
    '';

    monitor-hotplug = pkgs.writeShellScriptBin "monitor-hotplug" ''
      ${pkgs.systemd}/bin/udevadm monitor --subsystem=drm --udev | while read -r line; do
        echo "$line" | grep -q change || continue
        sleep 0.25
        ${workspace-switcher}/bin/workspace-switcher "" sync
      done
    '';

    in
    {
      home.packages = with pkgs; [
        hyprlandPlugins.hy3
        hyprpaper
        workspace-switcher
        monitor-hotplug
      ];

      home.file = {
        ".config/hypr/hyprland.conf".source =
          config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/hypr/hyprland.conf";
        ".config/hypr/hyprpaper.conf".source =
          config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/hypr/hyprpaper.conf";
      };
    };
}
