{
  config,
  lib,
  pkgs,
  ...
}:
let
  tunnel = builtins.fromJSON (builtins.readFile ./denver.json);
in
{
  sops.secrets.assistant-wireguard-key = {
    sopsFile = ../../../secrets/assistant-wireguard.yaml;
    key = "privateKey";
  };
  environment.etc."netns/assistant-browser/resolv.conf".text = lib.concatMapStrings (
    dns: "nameserver ${dns}\n"
  ) tunnel.dns;
  systemd.services = {
    # Installed but never started at boot or by a switch: agent's VPN runs only after `vpn on`.
    obscura.wantedBy = lib.mkForce [ ];
    obscura-connect.wantedBy = lib.mkForce [ ];
    obscura-lockdown = {
      wantedBy = lib.mkForce [ ];
      serviceConfig = {
        ExecStartPost = "${pkgs.systemd}/bin/systemctl --no-block stop wireguard-wg-assistant.service";
        ExecStopPost = "-${pkgs.systemd}/bin/systemctl --no-block start wireguard-wg-assistant.service";
      };
    };
    assistant-browser-netns = {
      description = "Network namespace for the assistant browser";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.iproute2}/bin/ip netns add assistant-browser";
        ExecStop = "${pkgs.iproute2}/bin/ip netns delete assistant-browser";
      };
    };
    wireguard-wg-assistant = {
      requires = [ "assistant-browser-netns.service" ];
      after = [
        "assistant-browser-netns.service"
        "sops-nix.service"
      ];
      # The browser tunnel runs only while the host kill switch is down; a switch restarting multi-user.target must not start it.
      serviceConfig.ExecCondition = "${pkgs.bash}/bin/sh -c '! ${pkgs.systemd}/bin/systemctl is-active -q obscura-lockdown.service'";
    };
  };
  networking.wireguard.interfaces.wg-assistant = {
    inherit (tunnel) ips;
    interfaceNamespace = "assistant-browser";
    privateKeyFile = config.sops.secrets.assistant-wireguard-key.path;
    postSetup = "${pkgs.iproute2}/bin/ip -n assistant-browser link set lo up";
    peers = [
      {
        inherit (tunnel) publicKey endpoint allowedIPs;
        persistentKeepalive = 25;
      }
    ];
  };
}
