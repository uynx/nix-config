{
  flake.nixosModules.security = _: {
    # Audited 2026-08-04: `ss -tulnp` on the running system listed nothing but
    # a DHCPv6 client and one mDNS socket, so both allow-lists stay empty.
    # Opening a port means adding it here, never `firewall.enable = false`.
    networking.firewall = {
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      allowPing = false;
    };

    # A fresh install decrypts the SSH key from sops but has an empty
    # known_hosts, so the first push stops on a host-key prompt — and takes the
    # trust-on-first-use decision with it. Keys are GitHub's published set.
    programs.ssh.knownHosts = {
      "github.com-ed25519" = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
      "github.com-ecdsa" = {
        hostNames = [ "github.com" ];
        publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
      };
      "github.com-rsa" = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
      };
    };

    boot = {
      kernel.sysctl = {
        "kernel.dmesg_restrict" = 1;
        "kernel.kptr_restrict" = 2;
        # Attaching to an already-running process that is not a child needs
        # this off. Set it back to 1 when a debugger session is over.
        "kernel.yama.ptrace_scope" = 1;
        "kernel.unprivileged_bpf_disabled" = 1;
        # 1, not 2: unprivileged BPF is off above, so 2 would only add constant
        # blinding to root's own programs — systemd's cgroup filters — for no
        # attacker it excludes. The JIT stays on either way.
        "net.core.bpf_jit_harden" = 1;

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

        # Below: parity with Kicksecure's security-misc, minus everything that
        # contradicts a decision already made in this repo — bpf_jit_harden
        # stays 1, tcp_timestamps stays on, swappiness stays 100 for zswap, and
        # rp_filter stays off because Obscura routes by fwmark.
        "kernel.sysrq" = 0;
        "kernel.perf_event_paranoid" = 3;
        # Autoloading a line discipline from an unprivileged ioctl has been a
        # recurring privilege-escalation path.
        "dev.tty.ldisc_autoload" = 0;
        "fs.suid_dumpable" = 0;
        "fs.protected_fifos" = 2;
        "fs.protected_regular" = 2;
        "vm.mmap_min_addr" = 65536;
        "net.ipv4.tcp_rfc1337" = 1;
        # io_uring is a large and repeatedly exploited surface that nothing
        # here uses. 2 disables it outright rather than for unprivileged only.
        "kernel.io_uring_disabled" = 2;
      };

      # The x86-only half of the usual hardened cmdline is deliberately absent:
      # vsyscall, vdso32, ia32_emulation, intel_iommu/amd_iommu and mem_encrypt
      # do not exist on this SoC. An unrecognised param is ignored, but listing
      # dead ones invites someone to "fix" them later.
      kernelParams = [
        "slab_nomerge"
        "init_on_alloc=1"
        "page_alloc.shuffle=1"
        "randomize_kstack_offset=on"
        "debugfs=off"
        "bdev_allow_write_mounted=0"
        "proc_mem.force_override=never"

        # DMA from a malicious peripheral is the one physical attack that lands
        # against a machine that is running and locked, which is this laptop's
        # normal unattended state since it cannot suspend at all.
        "iommu.passthrough=0"
        "efi=disable_early_pci_dma"

        # Not taken: init_on_free=1 (real cost, little over init_on_alloc) and
        # oops=panic/panic=-1, which would turn any Asahi driver oops into an
        # immediate reboot and lose work on a machine whose GPU stack is young.
      ];

      # No BBR: its pacing is distinguishable from cubic's by any destination
      # server, and cubic is what almost every Linux client sends. Blending in
      # beats the throughput on this machine. Do not re-add.

      # Protocols nothing here speaks, each with its own CVE history. dccp and
      # sctp are not in this kernel's config at all, so listing them would be a
      # no-op; these two ship as modules and can actually be autoloaded.
      blacklistedKernelModules = [
        "rds"
        "tipc"
      ];
    };

    # A core dump is a process's memory written to an unencrypted disk, keys
    # included. Nothing here debugs from them.
    systemd.coredump.enable = false;

    security = {
      # Adds `nohibernate` and blocks kexec. Asahi cannot hibernate anyway.
      protectKernelImage = true;
      sudo.execWheelOnly = true;
    };
  };
}
