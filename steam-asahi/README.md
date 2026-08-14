# Steam on NixOS Asahi

This keeps NixOS as the native 16 KiB-page ARM host. A pinned Fedora 44
container supplies the Asahi 4 KiB `muvm` guest, FEX, Mesa/Venus, Steam, and
Xwayland. Do not add host-wide x86 binfmt handlers or patch FEX root files by
hand.

## Reproduce the setup

Apply the NixOS configuration:

```bash
reb uynx
```

The first `steam-asahi` launch runs `steam-asahi-bootstrap` automatically. It
hashes this directory, builds `localhost/steam-asahi:44` when the checked-in
definition changed, creates or replaces the `steam-asahi` Distrobox, verifies
its required packages, and preserves Steam data in the separate container home
at `~/.local/share/steam-asahi/home`.

The Fedora base image is pinned by digest. The known-good Asahi, FEX, Mesa,
Steam, PulseAudio, and Xwayland package versions are pinned in `Containerfile`.
The host configuration also provisions a 16 GiB disk swapfile with zswap so a
modern game cannot trigger the host OOM killer while its microVM is growing.
Run the bootstrap directly after intentionally changing those pins:

```bash
steam-asahi-bootstrap
```

Run the non-destructive host/container checks at any time:

```bash
steam-asahi-doctor
```

## Game defaults

Every Steam session starts through the same versioned launcher with:

- `muvm --gpu-mode=venus`, which avoids the native-DRM DXVK black screen;
- `-cef-disable-gpu`, which avoids the Steam web helper GPU crash loop;
- one explicitly managed Steam VM, avoiding the Fedora wrapper's close/reopen
  loop;
- a Hyprland fullscreen rule for every `steam_app_<id>` window;
- launch-time monitor geometry from Hyprland: HDMI when connected, otherwise
  the focused laptop display, using exact logical width and height with no
  guessed resolution fallback.

Pressing `Alt+Space` regenerates desktop entries from installed Steam manifests
before opening Fuzzel. Newly installed games therefore appear automatically,
and every generated entry routes through the shared launcher. Home Manager also
regenerates them during every `reb`, so preserved manifests restore Fuzzel game
entries without first opening Steam. Selecting Steam
focuses its existing window or starts a normal Venus client. Selecting a game
focuses its existing window, forwards through an open client, or starts a
hidden Venus session when Steam is closed. A watcher true-fullscreens each new
game. After the last game closes, headless Steam stops automatically; a Steam
window or another running game keeps the container alive.

Pressing `Alt+Q` on Steam stops the entire dedicated container, including
Steam, FEX, and muvm. On a game, it preserves Steam when a Steam window or
another game exists; otherwise it stops the headless container. On other
windows it retains normal close behavior.

`steam-launch` has no per-game display handling. Every title maps to
`proton-experimental-arm64`, replacing the Proton 8/10 pins and the bespoke
Box64 tool Stick Fight needed, and niri's window rules fullscreen every
`steam_app_*` window. The launcher used to read the monitor and write that
resolution into each game's own config format — Wine's virtual desktop for
Peggle, Unity registry dwords for Stick Fight, `pcconfig.txt` for LEGO Star
Wars, `cs2_video.txt` for CS2. All of it is gone; restore from git if a game
comes up on the wrong monitor or at the wrong size.

Three exceptions remain, none of them display-related:

- Hogwarts Legacy (990080): a 4 GiB Venus VRAM budget so the renderer cannot
  exhaust this 16 GiB host, plus its own FEX config for Denuvo's 16-byte
  atomics. Every main Steam VM raises guest `vm.max_map_count` to `1048576`;
  Proton warns the muvm default of `65530` can prevent games working.
- CS2 (730): `r_csgo_player_occlusion_query 0`, because Venus can lose the
  occlusion query pool during match load. Also the one title deliberately
  *not* mapped to Proton — it is a native Linux build.

## What remains mutable

Steam authentication, owned/downloaded games, shader caches, Wine prefixes,
save files, and Steam's proprietary client state are runtime data and are not
stored in Git. Steam Cloud or a backup of `~/.local/share/steam-asahi/home` is
still required for those. The container and launch behavior are reproducible;
account data is deliberately not embedded in the system configuration.

## Recovery

If a Steam client update stalls through Proton VPN, disconnect the VPN, fully
exit Steam, and recreate the network namespace before relaunching:

```bash
docker restart steam-asahi
rm -rf "$XDG_RUNTIME_DIR/krun" "$XDG_RUNTIME_DIR/muvm.lock"
steam-asahi
```

To intentionally move to newer Fedora/Asahi package versions, update the base
digest and package pins in `Containerfile`, run `steam-asahi-bootstrap`, then
run `steam-asahi-doctor` before testing games.
