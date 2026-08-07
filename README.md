# nixos-config

Dendritic flake: `flake-parts` + `import-tree`. Every `.nix` under `modules/` is
imported automatically and modules find each other by output name, never by
path — so files can be moved freely, and directories are pure navigation.
Anything prefixed `_` is skipped by import-tree.

## Layout

| Path | Role |
|------|------|
| `modules/parts.nix` | flake-parts plumbing; declares the flake outputs that need to merge |
| `modules/lib/` | `flake.lib` — the user identity and the `mkBundle` helper |
| `modules/hosts/` | One dir per machine, plus the Home Manager base wiring |
| `modules/hardware/` | Per-architecture hardware, no software choices |
| `modules/system/` | Base NixOS every host wants; no desktop, no hardware |
| `modules/apps/` | One dir per program, holding **every** tier it needs |
| `modules/bundles/` | The host-facing switches — one line each, both tiers |
| `steam-asahi/` | Fedora Asahi Steam container and runbook |

`modules/apps/<name>/` is the unit of *implementation*: niri's NixOS module and
its KDL config live in the same directory, and a directory may export any mix of
`nixosModules`, `homeModules` and wrapped `packages`.

`modules/bundles/<name>.nix` is the unit of *choice*. A bundle pulls the NixOS
and Home Manager halves of a component together so a host lists it once. Without
this a host has two separate lists and dropping a component means editing both.

## Adding or removing a component

Edit exactly one line in `modules/hosts/<host>/default.nix`. Delete `ai` and
every AI CLI, its skills wiring and dictation are gone. Replace `desktopNiri`
with `desktopKde` and the compositor, greeter, bar and GTK theme all change
together.

| Bundle | Contents | Portable to another machine |
|---|---|---|
| `desktopNiri` | niri, sddm-astronaut greeter, noctalia, GTK theme, screen utils | Wayland only |
| `desktopKde` | Plasma 6, sddm, spectacle | yes |
| `shell` | fish, ghostty, tmux, starship, yazi, btop, CLI tooling | yes |
| `programming` | language toolchains, git, nvim | yes |
| `office` | obsidian, libreoffice | yes |
| `latex` | texlive scheme-full (stable pin) | yes |
| `media` | obs, mpv, qbittorrent, image tooling | yes |
| `comms` | vesktop, whatsapp | yes |
| `web` | brave-origin and its profile launchers | yes |
| `secrets` | sops, gpg agent, password managers | needs its own key in `.sops.yaml` |
| `cloud` | rclone gdrive + crypt mount (pulls `sops` itself) | needs its own secrets |
| `privacy` | obscura VPN + egress lockdown, tor and mullvad browsers | Linux only |
| `ai` | every AI CLI, shared skills/AGENTS.md, dictation | aarch64-linux pins, Wayland dictation |
| `gaming` | Steam via the Fedora/FEX distrobox container | Asahi only |

Bundles need `homeManagerBase`. Darwin has its own module system and lists
`homeModules` directly instead.

## Commands

```bash
reb              # rebuild (stages first — a flake build cannot see untracked files)
update && reb    # relock every input + bump pinned tools, then rebuild
update nvf       # relock one input only
```

Rebuilds need `--impure`, which `reb` passes: the Asahi firmware directory has
to stay a real path. See `modules/hardware/asahi.nix`.
