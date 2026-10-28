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
  home-manager.users.uynx.shellHooks.rebPostSwitch = lib.mkForce "";

  sops.secrets.assistant-wireguard-key = {
    sopsFile = ../../../secrets/assistant-wireguard.yaml;
    key = "privateKey";
  };
  environment.etc."netns/assistant-browser/resolv.conf".text = lib.concatMapStrings (
    dns: "nameserver ${dns}\n"
  ) tunnel.dns;
  systemd.services = {
    obscura.enable = lib.mkForce false;
    obscura-connect.enable = lib.mkForce false;
    obscura-lockdown.enable = lib.mkForce false;
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
