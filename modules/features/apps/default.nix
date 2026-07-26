{
  flake.homeModules.apps = { pkgs, ... }: {
    home.packages = with pkgs; [
      obsidian
      libreoffice
      qbittorrent
      wireshark
      proton-vpn
      proton-pass-cli
    ];
    home.sessionVariables.PROTON_PASS_KEY_PROVIDER = "fs";

    # Stop blueman-applet running in the background. It is what opens a window
    # every time a device connects, and a device that flaps produces one window
    # per flap. noctalia's Bluetooth panel already handles connecting and
    # disconnecting paired devices, so the applet earns nothing day to day.
    #
    # blueman itself stays installed: noctalia cannot pair or scan for new
    # devices, so run `blueman-manager` by hand when adding one.
    #
    # Hidden=true is the XDG way to suppress a system autostart entry from the
    # user's own config; the file must keep the same name as the one in
    # /etc/xdg/autostart.
    xdg.configFile."autostart/blueman.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=blueman-applet
      Hidden=true
    '';
  };
}
