# analysis

Terminal tools for **log analysis** and **static malware analysis**, with the same pinned versions on any Linux machine with Nix. Nothing is installed on the machine.

**Requirements:** Linux (x86_64 or aarch64) and Nix with flakes enabled (`experimental-features = nix-command flakes`). The first start downloads a few GB.

- [Quick start](#quick-start)
- [Which tool for what](#which-tool-for-what)
- [The VM](#the-vm)
- [Maintaining this repo](#maintaining-this-repo)

---

## Quick start

| Task | Command |
|---|---|
| All tools in a shell | `nix develop github:Phynik/analysis` |
| Only log tools | `nix develop github:Phynik/analysis#logs` |
| Only static analysis tools | `nix develop github:Phynik/analysis#static` |
| Isolated VM with a sample | `nix run github:Phynik/analysis#vm -- ./sample.zip` |

Leave a shell with `exit` or `Ctrl+D`; leave the VM with `sudo poweroff`.

> **Shell or VM?** The shell runs directly on your machine. Use it for logs and files you trust. Open anything that might be malicious **only in the VM**: a crafted file can exploit a bug in an analysis tool, and in the shell that would hit your real system.

---

## Which tool for what

### Logs

| I want to… | Tool | Example |
|---|---|---|
| Browse and filter a log file | `lnav` | `lnav /var/log/syslog`; recognises syslog, journald, web server and JSON logs, `/` searches, `:filter-in` filters |
| Search many or huge files | `rg` | `rg -i "failed password" logs/` |
| Search inside `.gz`/`.zip` archives | `ug` | `ug -z "error" logs.tar.gz` |
| Pick fields from JSON logs | `jq` | `jq -r 'select(.level=="error") \| .msg' app.jsonl` |
| Read or convert YAML | `yq` | `yq '.services' config.yaml` |
| Count, sort, group CSV/TSV/JSON | `mlr` | `mlr --icsv --opprint count-distinct -f src_ip access.csv` |
| SQL over large log files, joins, time buckets | `duckdb` | `duckdb -c "SELECT status, count(*) FROM 'access.csv' GROUP BY 1"` |
| Explore a table interactively | `vd` | `vd access.csv`; `Shift+F` on a column shows value frequencies |
| Search Windows event logs (`.evtx`) | `chainsaw` | `chainsaw search "mimikatz" -i Security.evtx` |

`chainsaw hunt`, which detects attacks with Sigma rules, needs rules and a mapping file that aren't included. `chainsaw search` works without them.

### Static analysis

Roughly in the order you'd use them on a new sample:

| I want to… | Tool | Example |
|---|---|---|
| Unpack a sample archive | `7zz` | `7zz x sample.zip -pinfected -o./work` |
| Know what kind of file it is | `file`, `diec` | `diec sample.exe` also shows compiler, packer and protector |
| Hashes and similarity to other samples | `sha256sum`, `ssdeep` | `ssdeep -b *.exe` |
| Read document and image metadata | `exiftool` | `exiftool invoice.pdf` |
| Find embedded files (firmware, droppers) | `binwalk` | `binwalk -e firmware.bin` |
| Unpack UPX | `upx` | `upx -d -o unpacked.exe sample.exe` (when `diec` says UPX) |
| Quick look at the strings | `strings` | `strings -n 8 sample.bin` |
| Decode hidden and obfuscated strings | `floss` | `floss sample.exe`; Windows PE and shellcode only |
| See what the binary is capable of | `capa` | `capa sample.exe`; ATT&CK techniques and behaviour, for PE, ELF, .NET and shellcode |
| Analyse Office documents and macros | `olevba`, `oleid`, `mraptor`, `rtfobj`, `msodde` | `olevba invoice.docm` extracts and rates VBA macros |
| Look at ELF headers and sections | `readelf`, `objdump` | `readelf -h -S sample.elf` |
| Look at bytes | `hexyl` | `hexyl -n 256 sample.bin` |
| Disassemble and reverse | `r2`, `rizin` | `r2 -A sample.elf`, then `afl` lists functions, `pdf @ main` disassembles |
| Write and test detection rules | `yr`, `yara` | `yr scan rules.yar samples/`; yara-x (`yr`) is faster, `yara` for older rule sets |
| Script your own checks | `python` | `pefile`, `lief` (PE, ELF, Mach-O), `yara` and `oletools` are importable |

---

## The VM

```
nix run github:Phynik/analysis#vm -- ./samples     # a folder or a single file
```

Boots in your terminal in about 2–3 minutes (most of that is building its own copy of the Nix store) and logs you in as `analyst`. Every start is a fresh system.

| Path in the VM | What it is |
|---|---|
| `/input` | The file or folder you passed. **Read-only and `noexec`**: samples can't be changed or run from there. |
| `~/work` | Scratch space for unpacking. Deleted on shutdown. |
| `/results` | Notes, reports, extracted strings. Copied to `./analysis-results/` on the host after `sudo poweroff`. |

**Isolation:**
- No network card at all (`-nic none`), not just a disabled connection.
- No shared folders, and its own Nix store instead of the host's.
- No graphics device: the console is your terminal.
- The root disk is deleted after every run.
- Results come out as plain data: symlinks are dropped and execute bits removed.

**Never put samples into `/results`.** It's the only way out of the VM.

**Static, not dynamic.** The VM is for looking at samples, not running them. Linux malware expects a typical distribution (`/usr/bin/wget`, a writable `/etc/systemd/system`, cron), which NixOS doesn't have, so most samples would just fail. For dynamic analysis, use a dedicated Ubuntu or REMnux VM with a fake network such as INetSim.

---

## Maintaining this repo

| File | Contents |
|---|---|
| `tools.nix` | The tool lists, used by both the shells and the VM |
| `vm.nix` | The VM: isolation, disks, user |
| `flake.nix` | Outputs and the `nix run …#vm` script |

**Add a tool:** add it to `tools.nix`, check with `nix develop` and `nix run .#vm`, then commit and push:
```
jj commit -m "add <tool>"
jj bookmark set main -r @-
jj git push
```

**Update all tools:** `nix flake update`, check that `nix develop --command capa --version` still works, then commit and push the same way.

**Known limitations:**
- `register-nix-paths.service` fails in the VM, a side effect of its separate Nix store. It only affects `nix` commands inside the VM, not the tools.
- `capa` takes from a few seconds to several minutes, depending on the size of the binary.
