{
  description = "Terminal tools for log and static malware analysis, as dev shells and as an isolated VM";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs:
        let tools = import ./tools.nix pkgs; in {
          logs = pkgs.mkShell { packages = tools.logs; };
          static = pkgs.mkShell { packages = tools.static; };
          default = pkgs.mkShell { packages = tools.logs ++ tools.static; };
        });

      nixosConfigurations = nixpkgs.lib.genAttrs systems (system:
        nixpkgs.lib.nixosSystem {
          modules = [
            "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
            ./vm.nix
            { nixpkgs.hostPlatform = system; }
          ];
        });

      apps = forAllSystems (pkgs:
        let
          vm = self.nixosConfigurations.${pkgs.stdenv.hostPlatform.system}.config.system.build.vm;
          run = pkgs.writeShellApplication {
            name = "analysis-vm";
            runtimeInputs = [ pkgs.squashfsTools pkgs.e2fsprogs pkgs.coreutils pkgs.findutils ];
            text = ''
              if [ $# -gt 1 ] || [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
                echo "usage: nix run github:Phynik/analysis#vm -- [file or folder]"
                echo "  the file or folder appears read-only at /input in the VM;"
                echo "  whatever the VM writes to /results is copied to ./analysis-results afterwards"
                exit 0
              fi

              results="$PWD/analysis-results"
              tmp=$(mktemp -d)
              trap 'rm -rf "$tmp"' EXIT
              opts=""

              if [ $# -eq 1 ]; then
                if [ -d "$1" ]; then
                  src="$1"
                elif [ -f "$1" ]; then
                  src="$tmp/input"
                  mkdir "$src"
                  cp -- "$1" "$src/"
                else
                  echo "analysis-vm: $1 does not exist" >&2
                  exit 1
                fi
                mksquashfs "$src" "$tmp/input.sqfs" -quiet -no-progress -all-root -no-xattrs
                opts="-drive file=$tmp/input.sqfs,format=raw,if=none,id=input,readonly=on -device virtio-blk-pci,drive=input,serial=input"
              fi

              # empty results disk, owned by the analyst user (uid 1000) inside the VM
              truncate -s 1G "$tmp/results.img"
              mkfs.ext4 -q -E root_owner=1000:100 "$tmp/results.img"
              opts="$opts -drive file=$tmp/results.img,format=raw,if=none,id=results -device virtio-blk-pci,drive=results,serial=results"

              NIX_DISK_IMAGE="$tmp/root.qcow2" QEMU_OPTS="$opts" ${vm}/bin/run-analysis-vm

              # copy results out as plain data: no symlinks, nothing executable
              mkdir -p "$tmp/out"
              debugfs -R "rdump / $tmp/out" "$tmp/results.img" 2>/dev/null
              find "$tmp/out" -type l -delete
              rm -rf "$tmp/out/lost+found"
              if [ -n "$(ls -A "$tmp/out")" ]; then
                mkdir -p "$results"
                find "$tmp/out" -type f -exec chmod a-x,u+rw {} +
                cp -r "$tmp/out/." "$results/"
                echo "==> results copied to $results"
              fi
            '';
          };
        in
        {
          vm = { type = "app"; program = "${run}/bin/analysis-vm"; };
          default = self.apps.${pkgs.stdenv.hostPlatform.system}.vm;
        });
    };
}
