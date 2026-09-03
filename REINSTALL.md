# Reinstalling this machine

Assembled 2026-08-18, macOS half added 2026-09-01, audited 2026-09-02. The only thing not in this
repo is the age identity that decrypts `secrets/`; everything else converges
from `reb`.

## -1. Back up what the repo does not contain

The repo reproduces the *system*, not the files. Nothing below is in git, in
Drive or in iCloud, and `tmutil` has no destination configured — copy it to an
external disk first.

| macOS | Asahi |
|---|---|
| `~/513 ~/514 ~/546 ~/589 ~/comps` | anything outside the three repos |
| `~/Documents ~/Pictures ~/Music ~/Downloads` | Steam library, if worth 236 GB of copying |
| `~/.local/share/atuin` (shell history) | `~/.local/share/atuin` |

`~/gdrive` is an rclone mount, not a backup — its contents live in Drive and
come back on their own.

Confirm from a *phone*, not from this machine, that the Bitwarden secure note
`sops age key` is reachable and non-empty. That note is the entire recovery for
both hosts — one age identity, one recipient in `.sops.yaml`. The older
`GPG master key` note decrypts nothing since the age migration and can be
ignored.

Two more things only work *before* the erase:

* **Check you can get a Bitwarden 2FA code from the phone.** The whole recovery
  chain is `Bitwarden → age key → everything`. If the second factor lives only
  in Ente Auth on this Mac, erasing it locks you out of the vault holding the
  key. Ente syncs server-side, so the app on the phone or the Ente recovery key
  is enough — but confirm it, do not assume it.
* **Push all three repos.** `~/nix-config`, `~/dotfiles`, `~/ai_memory`. A
  commit that exists only on this disk dies with it, and the flake is cloned
  from GitHub in step 0.5 and step 3, never from a backup.

## 0. Build the stick — on the Asahi side only

**This ISO has only ever booted in QEMU, never on real hardware.** Keep a stock
Asahi ISO on a second stick. If the custom image fails, boot the stock one and
run Determinate's installer inside the live environment — you lose only faster
eval and preconfigured substituters.

The flake has no `linux-builder` and no `extra-platforms`, so the
`aarch64-linux` ISO **cannot be built from the Mac**. It has to come off the
running NixOS install, which means getting that install online first — USB-C
ethernet or phone tethering is enough, and is the fallback for a dead `wlan0`
anyway. No Linux box, no custom ISO: use the stock Asahi one.

```bash
nix build .#nixosConfigurations.iso.config.system.build.isoImage --impure
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

The image carries `claude` alongside `vim`, `git`, `gh`, `bw`, `rg` and `fd`,
so the whole install can be driven from an agent session. Two things it does
not carry: a browser, so Claude Code's login is the paste-the-code flow on a
phone, same as `gh auth login` in step 3; and `~/dotfiles`, so until that is
cloned the session runs with no `CLAUDE.md` and no skills.

## 0.25 The macOS stick

Not needed for Erase All Content and Settings, which is the normal path. This is
the fallback for a Mac that boots but will not erase; a Mac that does not boot at
all needs DFU and a second Mac, which the stick cannot help with either.

**The installer app's `Info.plist` does not say what it installs.**
`DTPlatformVersion`, `CFBundleShortVersionString` and `DTSDKBuild` describe the
SDK the InstallAssistant was compiled against and do not move between point
releases — a 26.6.2 installer reports `26.6.1` / `21.6.01` / `25G74`, and 25G74
is not a shipping build of anything. Read the payload instead:

```bash
hdiutil attach -nobrowse -readonly -noverify \
  "/Volumes/Install macOS Tahoe/Install macOS Tahoe.app/Contents/SharedSupport/SharedSupport.dmg"
rg -o '<key>(OSVersion|Build)</key>\s*<string>[^<]*' -U \
  "/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
hdiutil detach "/Volumes/Shared Support"
```

Rewrite it only if that build is older than what `softwareupdate
--list-full-installers` offers:

```bash
softwareupdate --fetch-full-installer --full-installer-version <version>
sudo "/Applications/Install macOS Tahoe.app/Contents/Resources/createinstallmedia" \
  --volume "/Volumes/Install macOS Tahoe"
```

`softwareupdate` exits 0 even when the download fails — it printed
`PKDownloadError Code=8` at 90% and still returned success. Confirm
`/Applications/Install macOS Tahoe.app` exists before believing it. Re-read the
disk identifier immediately before writing, too: it is not stable across
replugs, and the same stick came back as `disk7` and then `disk6`.

## 0.5 Reinstall macOS

Do the whole macOS reinstall **before** touching the Linux side. A macOS
install pushes shared Apple SFR, and m1n1 has to be newer than the SFR it boots
against — installing NixOS first and macOS second can leave a stub that no
longer boots.

Erase All Content and Settings is enough and keeps the recovery path short; a
DFU restore from another Mac is only needed if the machine will not boot at
all. Either way the Asahi partitions go with it, so this is a full
p3/p4/p5 rebuild, not the p5-only case in step 1.

Then, still in macOS:

```bash
curl https://alx.sh | sh     # resize APFS, UEFI environment only
```

Take the **UEFI environment only** option — the NixOS partitions get made by
hand in step 2. Leave FileVault **off** until after this run, then turn it on
(`sudo fdesetup enable`, local recovery key rather than iCloud escrow, key into
Bitwarden). It is near-instant on Apple Silicon, so deferring costs nothing and
keeps the resize from needing a `diskutil apfs unlockVolume` first. FileVault is
the only option for the macOS side — LUKS covers p5 and nothing else. This is also the run that writes a fresh `vendorfw/`, which is
the only way that blob ever refreshes.

Bootstrap the Mac itself while you are there. Neither Nix nor Homebrew is
declarative at this stage, and `mas` needs you signed into the App Store or
`cakewallet` silently never installs:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
bw login && bw unlock
bw get notes 'sops age key' | install -Dm600 /dev/stdin ~/.config/sops/age/keys.txt
gh auth login
git clone https://github.com/uynx/nix-config.git ~/nix-config
nix run nix-darwin -- switch --flake ~/nix-config#darwin --impure
```

The age key goes in before the first switch here for the same reason it does on
Linux — see step 5. After that first switch `reb` works normally.

**macOS fails the same silent way, not a milder one.** The identity is
unencrypted and `generateKey` stays false, so nothing ever prompts: a missing
key fails the launchd agent while `darwin-rebuild` still exits 0. Verify rather
than assume:

```fish
launchctl list | rg sops        # org.nix-community.home.sops-nix, status 0
ls -l ~/.ssh/id_ed25519         # symlink into ~/.config/sops-nix/secrets
ls ~/.config/sops-nix/secrets   # six files: the ssh key plus five rclone
ssh -T git@github.com           # GitHub greeting; exits 1 even on success
```

Darwin runs the home tier only — `bundle.darwin` adds nothing but `enteAuth`,
and sops arrives through `mkBundle`'s shared `home` list. The Linux-only system
tier exists for eduroam, which macOS has no equivalent of.

## 1. Decide how deep the wipe goes

Wiping **p5 only** (the NixOS root) needs no macOS-side work. p3 (Asahi stub,
m1n1 + U-Boot) and p4 (`EFI - NIXOS`, `/boot`) both came from the macOS-side
`alx.sh` run and are not NixOS-managed.

**Never `mkfs` p4.** It holds `vendorfw/firmware.cpio`, `m1n1/` and `EFI/` —
`vendorfw/firmware.cpio` replaced the old internal `asahi/all_firmware.tar.gz`
format upstream, and `hardware.asahi.peripheralFirmwareDirectory` here already
points at `/boot/vendorfw` expecting the new format (`modules/hardware/asahi.nix`).
The installer mounts it by the partuuid at
`/proc/device-tree/chosen/asahi,efi-system-partition` to extract firmware.
Reformat it and the installer loses Wi-Fi *and* the installed system loses its
bootloader — recoverable only by redoing the macOS-side install.

A macOS reinstall wipes all three, so after step 0.5 this is always the deep
case: p3 and p4 come back from `alx.sh`, p5 is made by hand below.

## 2. Live environment

Boot the stick, autologin. Bring up networking (`nmcli` or `iwctl`, both on the
image). Keep a USB-C ethernet adapter or phone tethering available — if
firmware extraction failed, there is no Wi-Fi.

Encryption wraps the block device, so it precedes `mkfs`. This is the only
moment full-disk encryption can be added; it cannot be retrofitted later.

```bash
cryptsetup luksFormat /dev/nvme0n1p5
cryptsetup open /dev/nvme0n1p5 cryptroot
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot && mount /dev/nvme0n1p4 /mnt/boot
```

## 3. Get the flake onto the target

`gh auth login` happens **here**, in the live environment. The repo is private
and the SSH key that would authenticate is inside the repo being cloned, so the
browser flow over HTTPS is the only way in.

```bash
gh auth login                     # HTTPS, browser flow
mkdir -p /mnt/home/uynx
git clone https://github.com/uynx/nix-config.git /mnt/home/uynx/nix-config
```

Clone into the target home so no second clone is needed later. The HTTPS URL is
deliberate and keeps working after first boot: git's `insteadOf` rewrite to SSH
fires at connect time, not clone time.

## 4. Hardware config, then install

```bash
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/uynx/nix-config/modules/hosts/asahi/_hardware-configuration.nix
```

Do not skip this because the repo already has that file. It pins the old root
UUID and ESP `E6D0-19FC`; fresh partitions invalidate the root UUID
unconditionally, and LUKS changes it even if p4 was kept.
`nixos-generate-config` detects the LUKS container and writes the
`boot.initrd.luks.devices.cryptroot.*` entries itself.

Commit before building — the flake cannot see untracked files, and under
`import-tree` that failure is silent.

```bash
cd /mnt/home/uynx/nix-config && git add -A && git commit -m "hardware config"
nixos-install --flake /mnt/home/uynx/nix-config#asahi --impure
chown -R 1000:100 /mnt/home/uynx
reboot
```

`--impure` is required: the Asahi firmware directory has to stay a real path.

## 5. First boot — the one manual secret

Log in as `uynx`. Everything works except secrets; `sops-nix.service` has
failed because its key is not there yet.

```fish
bw login && bw unlock
bw get notes 'sops age key' | install -Dm600 /dev/stdin ~/.config/sops/age/keys.txt
systemctl --user restart sops-nix.service
```

If `bw unlock` reports `The decryption operation failed` against a correct
password, the CLI's cached key material is stale after a vault KDF change.
`bw logout && bw login` is the only fix — `bw unlock` is offline and `bw sync`
needs an unlocked vault.

Verify before trusting it:

```fish
systemctl --user status sops-nix.service    # active (exited)
ls -l ~/.ssh/id_ed25519                     # symlink into ~/.config/sops-nix/secrets
ssh -T git@github.com                       # prints the GitHub greeting; exits 1 even on success
```

The SSH keypair needs no manual restore. The public half has been registered on
GitHub since 2026-01-17; the private half is ciphertext already in
`secrets/secrets.yaml` and gets written out now that the age key exists.

sops-nix only writes that private half; the public half git's SSH commit
signing needs (`user.signingkey = ~/.ssh/id_ed25519.pub`) is derived by a
`home.activation` hook in `modules/apps/sops`, ordered after `sops-nix` and
guarded to skip until the private key actually exists — needed because
sops-nix's darwin activation only triggers its launchd agent, it doesn't wait
on it. First `reb` after the private key lands produces it; no manual step.

## 6. Converge

```fish
cd ~/nix-config && reb
```

Then reboot once. AI CLIs self-install via `home.activation.installRollingAiClis`
and the Steam container rebuilds on first launch. What does not come back:
Steam game data, and `~/gdrive` contents (encrypted in Drive, remounted by
rclone once secrets land).

**The one hard ordering rule: the age key goes in before the first `reb`.** A
missing key fails the user unit, but `nixos-rebuild` still exits 0 — so the
wrong order gives a green rebuild, a working desktop, no SSH key, no Drive
mount, and nothing but an inactive unit to explain it.
