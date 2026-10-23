# analysis

Public flake: terminal tools for log and static malware analysis. `tools.nix` holds the tool lists (used by `devShells` and the VM), `vm.nix` the isolated NixOS VM, `flake.nix` the outputs and the `apps.vm` run script. `README.md` is the user's manual; keep it updated. jj colocated with git, remote `git@github.com:Phynik/analysis.git`, bookmark `main`. Nothing personal goes in here, it's public.

## Testing

- Shell: `nix develop .#default --command <tool> …`
- VM, non-interactively: feed commands through a FIFO on stdin, wait for `automatic login` in the output before writing, end with `sudo poweroff`. Boot takes ~2.5 min (store image build).

## Gotchas

- The qemu-vm module replaces `fileSystems` with `virtualisation.fileSystems` (mkVMOverride): extra mounts must go in `virtualisation.fileSystems`, or they are silently ignored.
- New QEMU rejects `serial=` in `-drive … if=virtio`; use `-drive …,if=none,id=X -device virtio-blk-pci,drive=X,serial=X`. The guest sees `/dev/disk/by-id/virtio-X`.
- Don't set a short `x-systemd.device-timeout` on those mounts: systemd hasn't registered the disks yet at that point and the mount fails with "dependency".
- The VM's start script is `run-<hostName>-vm` (here `run-analysis-vm`).
- Without `qemu.networkingOptions = mkForce [ "-nic none" ]` QEMU adds a NIC by itself.
- nixpkgs' `capa` has no rules or signatures; `tools.nix` wraps it with `-r`/`-s` from `python3Packages.flare-capa.src`, which matches the version.
- `results` disk is created on the host with `root_owner=1000:100`, so the analyst user keeps `uid = 1000`.
