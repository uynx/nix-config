{ moduleWithSystem, ... }:
{
  flake.wrappers.noctalia-shell =
    { wlib, pkgs, ... }:
    let
      saved = builtins.fromJSON (builtins.readFile ./settings.json);
    in
    {
      imports = [ wlib.wrapperModules.noctalia-shell ];

      package = pkgs.noctalia-shell.overrideAttrs (_: {
        postInstall = ''
          substituteInPlace $out/share/noctalia-shell/Modules/LockScreen/LockScreenPanel.qml \
            --replace-fail 'isSelected ? Color.mOnPrimary : Color.mPrimary' \
                           'isSelected ? Color.mOnPrimary : Color.mOnSurface'
        '';
      });

      settings = saved // {
        wallpaper = saved.wallpaper // {
          directory = "${../../wallpapers}";
        };

        hooks = saved.hooks // {
          enabled = true;
          startup = "noctalia-shell ipc call wallpaper set ${../../wallpapers}/wallpaper.png all";
        };
      };

      colors = builtins.fromJSON (builtins.readFile ./Flexoki.json);
    };

  flake.homeModules.noctalia = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.noctalia-shell ];
    }
  );
}
