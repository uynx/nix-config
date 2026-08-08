{ self, ... }:
{
  # Guest machines for testing other systems. aarch64 guests run under KVM at
  # near-native speed — including 4 KiB-page guests on this 16 KiB-page host,
  # which the Waydroid VM already proves. x86_64 guests only run through TCG
  # emulation; fine for an installer, too slow to live in.
  flake.nixosModules.virt =
    { pkgs, ... }:
    {
      virtualisation.libvirtd.enable = true;

      # Windows 11 refuses to install without a TPM 2.0, and this is the only
      # way libvirt can offer one.
      virtualisation.libvirtd.qemu.swtpm.enable = true;

      programs.virt-manager.enable = true;
      users.users.${self.lib.user.name}.extraGroups = [ "libvirtd" ];

      # libvirt's own qemu is not on PATH, and booting an ISO once is a single
      # qemu-system-aarch64 command that needs no domain defined.
      environment.systemPackages = [ pkgs.qemu ];
    };
}
