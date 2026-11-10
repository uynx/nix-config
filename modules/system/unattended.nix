{
  flake.nixosModules.unattended =
    { pkgs, ... }:
    {
      boot = {
        lanzaboote.bootCounting.initialTries = 2;
        kernel.sysctl = {
          "kernel.panic" = 10;
          "kernel.panic_on_oops" = 1;
          "kernel.softlockup_panic" = 1;
          # A power cut lost files git wrote 20 s earlier under the default 30 s expiry (x86, 2026-11-10).
          "vm.dirty_expire_centisecs" = 300;
          "vm.dirty_writeback_centisecs" = 100;
        };
      };

      systemd.settings.Manager = {
        RuntimeWatchdogSec = "2min";
        RebootWatchdogSec = "2min";
      };

      # A new generation with no route in 10 minutes reboots; after its second failed try systemd-boot falls back to the previous generation.
      systemd.services.boot-health = {
        description = "Reboot when a freshly installed generation boots without network";
        requiredBy = [ "boot-complete.target" ];
        before = [ "boot-complete.target" ];
        after = [ "NetworkManager.service" ];
        unitConfig = {
          ConditionPathExists = "/sys/firmware/efi/efivars/LoaderBootCountPath-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f";
          OnFailure = "reboot.target";
        };
        restartIfChanged = false;
        path = [
          pkgs.iproute2
          pkgs.ripgrep
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = 600;
        };
        script = "until ip -4 route show default | rg -q 'dev (wl|en)'; do sleep 3; done";
      };
    };
}
