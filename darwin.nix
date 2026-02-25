{ config, lib, inputs, pkgs, ... }:

{  
  users.users.uynx.home = "/Users/uynx";
  nix.enable = false;

  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "bak";
    users.uynx = import ./home.nix;
    extraSpecialArgs = { inherit inputs; };
  };

  system = {
    primaryUser = "uynx";

    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    stateVersion = 6;

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    startup.chime = false;
  };

  environment = {
    systemPackages = with pkgs; [
      docker
      colima
      lima
      postgresql
      mongodb-tools
    ];
    shellAliases = {
      update = "nix flake update --flake ~/nix-config";
      reb = "sudo darwin-rebuild switch --flake ~/nix-config#macos";
    };
    shells = [ pkgs.fish ];
  };

  homebrew = {
    enable = true;
    greedyCasks = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    casks = [ 
      "julia-app"
      "skim"
      "microsoft-office" 
      "tor-browser"
      "mullvad-browser"
      "protonvpn"
      "streamlabs"
      "obs"
    ];
    caskArgs = {
      no_quarantine = true;
    };
  };

  fonts.packages = [ pkgs.nerd-fonts.hack ];

  networking = {
    applicationFirewall.enable = true;
    applicationFirewall.enableStealthMode = true;
    computerName = "MacBook-Pro";
    hostName = "MacBook-Pro";
    # wakeOnLan.enable = true;
  };

  power = {
    restartAfterFreeze = true;
    sleep.allowSleepByPowerButton = true;
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  programs.fish.enable = true;
  users.users."uynx".shell = pkgs.fish;
}
