{ self, ... }:
{
  flake.nixosModules.virt =
    { pkgs, ... }:
    {
      virtualisation.libvirtd.enable = true;

      virtualisation.libvirtd.qemu.swtpm.enable = true;

      programs.virt-manager.enable = true;
      users.users.${self.lib.user.name}.extraGroups = [ "libvirtd" ];

      environment.systemPackages = [ pkgs.qemu ];
    };
}
