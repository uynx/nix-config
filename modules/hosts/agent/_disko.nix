{
  disko.devices.disk = {
    main = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZVKW512HMJP-00000_S316NA0HB00326";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # Read only while formatting; nixos-anywhere uploads it via --disk-encryption-keys.
              passwordFile = "/tmp/secret.key";
              settings.allowDiscards = true;
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };

    data = {
      type = "disk";
      device = "/dev/disk/by-id/ata-ST2000LM015-2E8174_WDZ29HCD";
      content = {
        type = "gpt";
        partitions.luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptdata";
            settings.keyFile = "/tmp/data.key";
            # Unlocked after boot by crypttab from the sops secret, not in initrd.
            initrdUnlock = false;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/data";
              mountOptions = [ "nofail" ];
            };
          };
        };
      };
    };
  };
}
