{ moduleWithSystem, ... }:
{
  flake.wrappers.yazi =
    { wlib, ... }:
    {
      imports = [ wlib.wrapperModules.yazi ];

      settings.yazi.mgr = {
        show_hidden = false;
        sort_by = "mtime";
        sort_dir_first = true;
      };

      flavors.flexoki = ./flexoki.yazi;
      settings.theme.flavor = {
        dark = "flexoki";
        light = "flexoki";
      };
    };

  flake.homeModules.yazi = moduleWithSystem (
    { self', ... }:
    { pkgs, lib, ... }:
    {
      home.packages = [ self'.packages.yazi ];

      xdg.desktopEntries.yazi = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        name = "Yazi";
        genericName = "File manager";
        exec = "${lib.getExe self'.packages.ghostty} -e ${lib.getExe self'.packages.fish} -i -C y";
        icon = "yazi";
        terminal = false;
        categories = [
          "System"
          "FileTools"
          "FileManager"
        ];
      };

      programs.fish.functions.y.body = ''
        set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
        ${lib.getExe self'.packages.yazi} $argv --cwd-file="$tmp"
        if set -l cwd (command cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
      '';
    }
  );
}
