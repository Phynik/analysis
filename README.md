# analysis

Terminal tools for **log analysis** and **static malware analysis**, the same versions on any Linux machine with Nix. Nothing gets installed; everything comes pinned from `flake.lock`.

Needs Nix with flakes enabled (`experimental-features = nix-command flakes`). x86_64 and aarch64 Linux.

## Just the tools (dev shell)

```
nix develop github:Phynik/analysis          # everything
nix develop github:Phynik/analysis#logs     # log tools only
nix develop github:Phynik/analysis#static   # static analysis only
```

Good for logs and harmless files. **Don't open malware samples here**: the shell runs directly on the host, so a parser bug in a tool or an accidental `./sample` hits the real machine. Use the VM for samples.

## Isolated VM for samples

```
nix run github:Phynik/analysis#vm -- ./samples     # a folder or a single file
```

Boots a NixOS VM in the terminal (about 2–3 minutes, mostly building its own copy of the Nix store) and logs in as `analyst`.

| Inside the VM | |
|---|---|
| `/input` | the file or folder you passed, **read-only and `noexec`**: samples can't be changed or run from there |
| `/results` | copied to `./analysis-results/` on the host when the VM shuts down |
| `~/work` | scratch space, gone after shutdown |

```
7zz x /input/sample.zip -pinfected -o$HOME/work    # unpack a sample
sudo poweroff                                       # shut down and copy results out
```

**Isolation:**
- No network card at all (`-nic none`), not just a disabled network.
- No shared folders, and its own Nix store image instead of the host's store.
- No graphics device: the console is the terminal you started it from.
- Every start is a fresh system; the root disk is deleted afterwards.
- Results come out as plain data: symlinks are dropped and execute bits removed. Still, **never put samples into `/results`**; it's for notes, reports and extracted strings.

Static analysis doesn't run the sample, so the remaining risk is a bug in an analysis tool that a crafted file exploits. The VM contains that. Don't use it for dynamic analysis (running samples): see the notes on that in the conversation that led to this repo, or use a dedicated Ubuntu/REMnux VM with a fake network.

## Tools

**Logs:** `lnav`, `jq`, `yq`, `mlr` (miller), `rg` (ripgrep), `ug` (ugrep, `-z` for compressed files), `duckdb` (SQL over CSV/JSON), `vd` (visidata), `chainsaw` (Windows .evtx with Sigma rules)

**Static:** `file`, `strings`/`readelf`/`objdump`, `hexyl`, `r2` (radare2), `rizin`, `yara`, `yr` (yara-x), `capa` (with Mandiant's rules and signatures), `floss`, `diec` (Detect It Easy), `binwalk`, `upx`, `ssdeep`, `exiftool`, `7zz`, and `python` with `pefile`, `oletools`, `lief`, `yara`

To add a tool: put it in `tools.nix` (both the shells and the VM use that list), check `nix develop` and `nix run .#vm`, commit, push.

## Updating

```
nix flake update && nix develop --command capa --version
jj commit -m "flake: update inputs" && jj bookmark set main -r @- && jj git push
```

## Known limitations

- `register-nix-paths.service` fails in the VM (an effect of the separate store image). It only matters for `nix` commands *inside* the VM, not for the tools.
- `capa` takes from seconds to several minutes, depending on the size of the binary.
