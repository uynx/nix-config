{
  flake.nixosModules.security =
    { ... }:
    {
      # Audited 2026-08-04: `ss -tulnp` on the running system listed nothing but
      # a DHCPv6 client and one mDNS socket, so both allow-lists stay empty.
      # Opening a port means adding it here, never `firewall.enable = false`.
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ ];
        allowedUDPPorts = [ ];
        allowPing = false;
      };

      boot = {
        kernel.sysctl = {
          "kernel.dmesg_restrict" = 1;
          "kernel.kptr_restrict" = 2;
          "kernel.yama.ptrace_scope" = 1;
          "kernel.unprivileged_bpf_disabled" = 1;
          "net.core.bpf_jit_harden" = 2;

          "net.ipv4.conf.all.accept_redirects" = 0;
          "net.ipv4.conf.default.accept_redirects" = 0;
          "net.ipv4.conf.all.send_redirects" = 0;
          "net.ipv4.conf.default.send_redirects" = 0;
          "net.ipv4.conf.all.accept_source_route" = 0;
          "net.ipv4.conf.default.accept_source_route" = 0;
          "net.ipv6.conf.all.accept_redirects" = 0;
          "net.ipv6.conf.default.accept_redirects" = 0;
          # No use_tempaddr here: networking.tempAddresses already defaults it
          # to 2, and a second definition is a hard eval error.
        };

        # Protocols nothing here speaks, each with its own CVE history.
        blacklistedKernelModules = [
          "dccp"
          "sctp"
          "rds"
          "tipc"
        ];
      };

      security = {
        # Adds `nohibernate` and blocks kexec. Asahi cannot hibernate anyway.
        protectKernelImage = true;
        sudo.execWheelOnly = true;
      };
    };
}
