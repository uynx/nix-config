{
  flake.nixosModules.locale = {
    time.timeZone = "America/New_York";
    console.useXkbConfig = true;
    services.xserver.xkb = {
      layout = "us";
      options = "caps:escape";
    };

    services.udev.extraHwdb = ''
      evdev:input:b*
       KEYBOARD_KEY_70039=esc
       KEYBOARD_KEY_3a=esc

      evdev:atkbd:dmi:*
       KEYBOARD_KEY_3a=esc
    '';
  };
}
