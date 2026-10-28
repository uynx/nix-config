# nix-config

This is the configuration for all of my computers, NixOS and macOS alike, in one flake. It's a dendritic flake built on `flake-parts` and `import-tree`, which means every `.nix` file under `modules/` gets imported automatically and modules find each other by their output name instead of by path. Because of this, files can be moved around freely and the directories are only there to make things easier to find. Anything prefixed with `_` is skipped by import-tree.

## Hosts

| Attribute | Machine | `hostName` |
|---|---|---|
| `asahi` | MacBook Pro, NixOS-Asahi, the primary machine | `asahi` |
| `x86` | the x86_64 desktop, GTX 1070 | `x86` |
| `agent` | unattended assistant and trading laptop, GTX 1060 | `agent` |
| `darwin` | the same MacBook under macOS | `MacBook-Pro` |
| `arm` | generic 4 KiB-page aarch64 desktop (Danush's Snapdragon layout), niri, `self.lib.gaming "fex"` | `arm` |
| `waydroid` | Android-in-a-VM guest | `waydroid` |
| `iso` / `iso-x86` | installer images, aarch64 and x86_64 | none |

`asahi` and `x86` take nearly the same list of bundles, so anything added to a shared module lands on both of them at once, which is why it's worth checking what else uses a module before editing it.

## Layout

| Path | Role |
|------|------|
| `modules/parts.nix` | flake-parts plumbing, declaring the flake outputs that need to merge |
| `modules/lib/` | `flake.lib`, which holds the user identity and the `mkBundle` helper |
| `modules/hosts/` | One directory per machine, plus the Home Manager base wiring |
| `modules/hardware/` | Per-architecture hardware, with no software choices |
| `modules/system/` | Base NixOS that every host wants, with no desktop and no hardware |
| `modules/darwin/` | The same for macOS, since nix-darwin has its own module system |
| `modules/apps/` | One directory per program, holding every tier it needs |
| `modules/apps/personal-assistant/` | Agent-only SimpleX CLI and Proton Mail Bridge |
| `modules/apps/assistant-ssh/` | Key-only SSH access to asahi through the trusted Tailscale interface |
| `modules/bundles/` | The switches a host flips, one line each covering both tiers |
| `modules/wallpapers/` | The wallpaper image, referenced by the desktop bundles |

`modules/apps/<name>/` is the unit of implementation. niri's NixOS module and its KDL config live in the same directory, and a directory can export any mix of `nixosModules`, `darwinModules`, `homeModules` and wrapped `packages`. When a program needs a different delivery on macOS, like a cask instead of a nixpkgs build, that goes in `<name>/darwin.nix` right beside the shared half instead of in a separate macOS tree.

`modules/bundles/<name>.nix` is the unit of choice. A bundle pulls every tier of a component together so a host only has to list it once. Without bundles, a host would have two separate lists and dropping a component would mean editing both of them.

## The two platforms

`mkBundle` returns both a NixOS module and a darwin module from one definition, because the Home Manager half is usually identical and only the system half differs. This makes `modules/hosts/darwin/` read just like `modules/hosts/asahi/`, with the same bundle names on one line each, so moving a component between machines is just moving a line. When the home tier differs by an entry or two, `homeLinux` and `homeDarwin` add to the shared `home` list instead of restating it, so a bundle is always one `mkBundle` call and never two.

Everything portable is shared as it is. When a package only exists on one platform, the app module absorbs that difference with a `lib.optional stdenv.hostPlatform.isLinux` beside the package and a cask in `darwin.nix`, so the hosts never have to branch. An app only splits into two files when the platforms share no structure at all, the way `apps/launchers/` does with a different browser binary and different window handling, and whatever text the two halves still have in common goes in an `_`-prefixed file beside them instead of in both. A single package name that differs stays a ternary.

Three rules keep this working. First, a module should never branch on `pkgs`, because putting `if isDarwin then … else …` around a module body makes the import depend on config, which is an infinite recursion inside Home Manager. Using `lib.mkIf` on the values works instead, and `modules/apps/ghostty/default.nix` shows how. Second, a darwin module can't share a name with the bundle that imports it, since `flake.darwinModules.office` defined in terms of `self.darwinModules.office` is the same recursion by another route. Otherwise a darwin module is named after its own directory to match the home module beside it, and only `mediaCasks` needs a different name because `apps/media/` and the `media` bundle are spelled the same. Third, the shell can't name a component. `apps/fish/` holds no command that drives another program, so `vpn` lives in `apps/obscura/` and `android` lives in `apps/waydroid/`. A component that needs to run something at `update` or `reb` time registers it through `shellHooks`, which is declared in `apps/fish/default.nix` and loaded for every Home Manager user by `homeManagerBase`, so a host that drops the component drops the command with it instead of keeping one that fails.

## Adding or removing a component

Adding or removing a component is one line in `modules/hosts/<host>/default.nix`. If I delete `ai`, every AI CLI, its skills wiring and dictation are gone. `reb switch` flips the host's `desktop` file (on asahi and x86) between `niri` and `kde`, so the compositor, greeter, bar and GTK theme all change together, and then it rebuilds and reboots.

| Bundle | Contents | macOS |
|---|---|---|
| `desktopNiri` | niri, sddm-astronaut greeter, noctalia, GTK theme, screen utils, Wayscriber (`apps/wayscriber/`), `android` (aarch64 only) | no |
| `desktopKde` | Plasma 6, sddm, spectacle | no |
| `desktopMacos` | AeroSpace, SketchyBar, JankyBorders, wallpaper, file associations | only |
| `shell` | fish, ghostty, tmux, starship, yazi, btop, CLI tooling | yes |
| `programming` | language toolchains, git, nvim (+ colima on macOS) | yes |
| `office` | obsidian, libreoffice | yes (`libreoffice-bin`) |
| `latex` | texlive scheme-full (stable pin) | yes |
| `media` | obs, mpv, qbittorrent, image tooling | casks OBS/Streamlabs/BlackHole |
| `comms` | vesktop, whatsapp, rustdesk, SimpleX Chat (`apps/simplex/`, nixpkgs) | whatsapp, rustdesk cask |
| `web` | brave-origin and its profile launchers, ungoogled-chromium, stripped Firefox | cask Brave + menu shortcuts, stripped Firefox |
| `secrets` | sops (age), rage, Bitwarden | Bitwarden only; needs its own key in `.sops.yaml` |
| `cloud` | rclone gdrive + crypt mount (pulls `sops` itself) | needs its own secrets |
| `privacy` | obscura VPN + egress lockdown + `vpn`, tor and mullvad browsers | three casks, no `vpn` |
| `ai` | every AI CLI, shared skills/AGENTS.md, dictation | Homebrew CLIs + desktop apps |
| `prismlauncher` | Prism Launcher (Minecraft) | cask prismlauncher |
| `android` | Waydroid launcher and image updater; the VM itself is `apps/waydroid/vm.nix` (aarch64 only, gated inside the module) | no |

Four host lines are single modules instead of bundles, because a bundle around one name would only restate it: `virt` (`apps/virt/`), `campus-wifi` (`system/campus-wifi.nix`, the UMass eduroam profile), `tailscale` (`apps/tailscale/`, joins the tailnet with the sops auth key; in `standard`) and `cpuBatteryCap` (`hardware/cpu-battery-cap.nix`).

On aarch64, apps with no stable ARM build run their official x86_64 release under FEX. They get registered in `x86Apps` (`apps/x86-emu/`), which emits a launcher into the Steam runner's muvm VM or FEX container with a per-app home under `~/.local/share/x86-apps/`, so this needs the `muvm` or `fex` runner on that host.

Every bundle needs `homeManagerBase` on either platform, since it carries the Home Manager wiring and the `shellHooks` option declarations.

On macOS the whole AI toolchain comes from Homebrew instead of pins, because the pins in `modules/apps/ai-tools/linux.nix` are aarch64-linux artifacts and the desktop apps come along with the casks anyway. `update-ai-clis` rolls the tools that can't be pinned (agy and t3) on Linux only. Since 2026-09-02 each of those has a formula or cask on the Mac, so the script doesn't exist there, and `greedyCasks` plus `onActivation.upgrade` keep the rest current on every rebuild.

## The family configs

Two more trees share this layout and most of these modules: `treyalex333/NixConfiguration` (x86_64 NixOS, two machines, Plasma) and `azalexander/nix-config` (macOS only). Each one has its own README describing its own tree. The ways they differ from this one are deliberate and listed there, so a difference shouldn't be resolved by copying this repo over either of them.

## Commands

```bash
reb              # rebuild (stages first, since a flake build can't see untracked files)
update && reb    # relock every input + bump pinned tools, then rebuild
update nvf       # relock one input only
```

`reb` targets the machine's own hostname on Linux and `darwin` on macOS, and drives `nh os` or `nh darwin` to match, though passing a host name overrides it. The hostname doubles as the flake attribute on every NixOS host here, which is why that needs no per-host branch. Both commands are assembled per host, so `update` runs the pin updaters this host installed and `reb` runs its post-switch hooks, and neither one names a component this host might not have. `nix fmt` formats the tree with nixfmt, and `statix check .` should report nothing.

Rebuilds need `--impure`, which `reb` passes, because the Asahi firmware directory has to stay a real path and the AI skills are read out of a working copy. `modules/hardware/asahi.nix` has the details.

## Fresh install

Everything except one file is in this repo. That file is the age identity that decrypts `secrets/`, and it has to be in place before the first `reb`. Without it, `sops-nix.service` fails while the rebuild still succeeds, so you get a working desktop with no SSH key, no Drive mount and nothing but an inactive unit to tell you why.

```bash
bw login && bw unlock                 # or run these from the installer ISO
bw get notes 'sops age key' | install -Dm600 /dev/stdin ~/.config/sops/age/keys.txt
gh auth login
git clone https://github.com/uynx/nix-config.git ~/nix-config
cd ~/nix-config && reb
```

The HTTPS clone URL is on purpose. `git` rewrites GitHub HTTPS to SSH at connect time, which can't work until the SSH key comes out of sops.

## First rebuild on a Mac

Homebrew itself isn't declarative, so it has to be installed once by hand or the activation fails with `command not found`:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
nix run nix-darwin -- switch --flake ~/nix-config#darwin --impure
```

After that first switch, `reb` works the same way it does on Linux.

## Snapshots and sync

Every `reb` runs in this order: snapshot, commit, pull with a rebase, build and push `main`. Offline, it skips the pull and the push. On a conflict it builds nothing, leaves the tree as it was, pushes the commits to `conflict-<host>` and tells you to ask an LLM to fix that branch, and the next successful `reb` deletes the branch.

For KDE, `rc2nix`'s dump of the current settings goes to `kde-snapshots/<hostname>.nix`. It's a record and not live config, so moving a setting between machines or into the declared config means having an LLM port it from the snapshot diff. For Noctalia on niri, `~/.config/noctalia/settings.json` is a symlink to `modules/apps/noctalia/settings.json`, so a change in the panel lands in the repo right away and the next `reb` commits it. Every niri host shares that file, and `reb` restarts Noctalia after a switch.
