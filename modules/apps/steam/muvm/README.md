# Steam on NixOS Asahi

This keeps NixOS as the native 16 KiB-page ARM host while a pinned Fedora 44 container supplies the Asahi 4 KiB `muvm` guest, FEX, Mesa with Venus, Steam and Xwayland. Because of this, there's no reason to add host-wide x86 binfmt handlers or to patch FEX's root files by hand, and doing either one breaks the setup.

## Reproducing the setup

Running `reb` applies the NixOS configuration, and every `reb` also runs `steam-asahi-bootstrap` after the switch. The bootstrap hashes `Containerfile`, `distrobox.ini` and `steam-guest-tune`, rebuilds the `localhost/steam-asahi` image whenever that hash changes, creates or replaces the `steam-asahi` Distrobox, checks its required packages and keeps Steam's data in a separate container home at `~/.local/share/steam-asahi/home`. The first launch also downloads FEX's Arch rootfs, checks its hash and mounts it where Steam's FEX expects it.

The Fedora base image is pinned by digest, and the known-good Asahi, muvm, libkrun, FEX and Mesa package versions are pinned in `Containerfile`. Running `update` calls `update-steam-asahi-pins`, which moves the digest and those pins forward, since Fedora's `updates` repo only keeps the newest build and old pins stop resolving. The Steam client itself is on the `publicbeta` branch and updates itself, and when an update ends the client, the launcher starts it again up to three times. The host also has a 16 GiB swapfile with zswap so a modern game can't trigger the host OOM killer while its microVM is growing.

The bootstrap can be run by hand after changing the pins, and `steam-asahi-doctor` runs checks on the host and the container that don't change anything:

```bash
steam-asahi-bootstrap
steam-asahi-doctor
```

## Game defaults

Every Steam session starts through the same launcher with `muvm --gpu-mode=venus`, which avoids the black screen DXVK gets on native DRM, and only one Steam VM ever runs, which avoids the close and reopen loop that Fedora's own wrapper gets into. Inside the VM, `steam-guest-tune` raises `vm.max_map_count` to 2147483642, since Proton warns that muvm's default of 65530 can stop games from working, and it bind-mounts crash dumps into the container home. Setting `STEAM_HUD=1` turns on MangoHud and `STEAM_PROTON_LOG=1` turns on Proton's log.

Every installed game gets a desktop entry generated from Steam's manifests on every `reb`, so a game shows up in the launcher without opening Steam first, and every entry goes through `steam-launch`. Picking Steam focuses its window if it's already open and otherwise starts a normal client. Picking a game focuses its window if it's already running, sends it to an open client if there is one, and otherwise starts Steam hidden in the background. niri's window rules make every `steam_app_*` window fullscreen, and a watcher focuses each new game and stops the headless Steam once the last game closes, unless a Steam window or another game is still open. `Mod+Q` on a game closes it, and it also stops the Steam container once no window from the VM is left.

There's no per-game display handling anymore. Every title is mapped to `proton-experimental-arm64`, which replaced the Proton 8 and 10 pins and the custom Box64 tool that Stick Fight needed. The launcher used to read the monitor and write that resolution into each game's own config format (Wine's virtual desktop for Peggle, Unity registry values for Stick Fight, `pcconfig.txt` for LEGO Star Wars and `cs2_video.txt` for CS2). All of that is gone, so git history is the place to look if a game ever comes up on the wrong monitor or at the wrong size.

## What stays outside git

Steam's login, owned and downloaded games, shader caches, Wine prefixes, save files and Steam's own client state are all runtime data, so none of it is stored in git. Steam Cloud or a backup of `~/.local/share/steam-asahi/home` is still needed for those. The container and the launch behavior are reproducible, but account data is deliberately kept out of the system configuration.

## Recovery

If a Steam client update stalls, I fully exit Steam, try again with the VPN off and recreate the network namespace before relaunching:

```bash
docker restart steam-asahi
rm -rf "$XDG_RUNTIME_DIR/krun" "$XDG_RUNTIME_DIR/muvm.lock"
steam-asahi
```
