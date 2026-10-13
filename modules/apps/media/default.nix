{
  flake.homeModules.media =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      qbtConfig = ''
        [Application]
        FileLogger\Age=1
        FileLogger\AgeType=1
        FileLogger\Backup=true
        FileLogger\DeleteOld=true
        FileLogger\Enabled=true
        FileLogger\MaxSizeBytes=66560
        FileLogger\Path=${config.home.homeDirectory}/.local/share/qBittorrent/logs
        GUI\Notifications\TorrentAdded=false

        [BitTorrent]
        Session\AnonymousModeEnabled=true
        Session\DHTEnabled=false
        Session\Encryption=1
        Session\Interface=obscuravpn
        Session\InterfaceName=obscuravpn
        Session\LSDEnabled=false
        Session\PeXEnabled=false
        Session\Port=9479
        Session\QueueingSystemEnabled=false
        Session\SSL\Port=21801
        Session\StartPaused=false

        [Core]
        AutoDeleteAddedTorrentFile=Never

        [GUI]
        DownloadTrackerFavicon=false
        Log\Enabled=false

        [LegalNotice]
        Accepted=true

        [Network]
        PortForwardingEnabled=false

        [Preferences]
        General\CloseToTrayNotified=true
        General\Locale=en
      '';
    in
    {
      home.packages =
        with pkgs;
        [
          mpv
          qbittorrent
          imagemagick
          ghostscript
        ]
        ++ lib.optionals stdenv.hostPlatform.isLinux [
          (symlinkJoin {
            name = "obs-studio-nvenc";
            paths = [ (obs-studio.override { browserSupport = false; }) ];
            nativeBuildInputs = [ makeWrapper ];
            # obs-nvenc-test dlopens libnvidia-encode.so.1 and nothing puts the driver dir on its search path.
            postBuild = ''
              wrapProgram $out/bin/obs --suffix LD_LIBRARY_PATH : /run/opengl-driver/lib
            '';
          })
          obs-cmd
          v4l-utils
        ];

      xdg.configFile = {
        "qBittorrent/qBittorrent.conf" = {
          force = true;
          text = qbtConfig;
        };
        "qBittorrent/qBittorrent.ini" = {
          force = true;
          text = qbtConfig;
        };
      };
    };
}


