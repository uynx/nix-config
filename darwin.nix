{ config, lib, inputs, pkgs, ... }:

{  
  users.users.uynx.home = "/Users/uynx";

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

  nix = {
    enable = true;
    gc.automatic = true;
    optimise.automatic = true;
    settings.sandbox = true;
    extraOptions = ''
      experimental-features = flakes nix-command
    '';
  };

  environment = {
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
	upgrade = true;
	autoUpdate = true;
	cleanup = "zap";
    };
    taps = [
      "nikitabobko/tap"
      "mongodb/brew"
    ];
    brews = [
      "git" 
      "gh"
      "coreutils"	
      "fzf" 
      "jq" 
      "fastfetch" 
      "neovim" 
      "lima" 
      "colima" 
      "docker"	
      "postgresql@18"
      "deno"
      "python@3.14"
      "mongodb-community@8.2"
    ];
    casks = [ 
      "ghostty" 
      "ungoogled-chromium" 
      "microsoft-office" 
      "wireshark-app" 
      "brave-browser"
      "firefox"
      "vscodium"
      "aerospace"
      "tor-browser"
      "protonvpn"
      "devpod"
      "obs"
      "qbittorrent"
      "bluestacks"
      "steam"
      "discord"
    ];
    caskArgs = {
      no_quarantine = true;
    };
  };

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

  programs.fish.enable = true;
  users.users."uynx".shell = pkgs.fish;
}
