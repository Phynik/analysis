# The tool lists, shared by the dev shells and the VM.
pkgs:
let
  capaSrc = pkgs.python3Packages.flare-capa.src;

  # nixpkgs' capa ships without its rule set and signatures; its source has the matching ones
  capa = pkgs.writeShellScriptBin "capa" ''
    exec ${pkgs.capa}/bin/capa -r ${capaSrc}/rules -s ${capaSrc}/sigs "$@"
  '';

  python = pkgs.python3.withPackages (ps: [
    ps.pefile
    ps.oletools
    ps.lief
    ps.yara-python
  ]);
in
{
  logs = [
    pkgs.lnav # log viewer that understands common formats
    pkgs.jq
    pkgs.yq-go
    pkgs.miller # mlr: CSV/JSON/TSV as tables
    pkgs.ripgrep
    pkgs.ugrep # ug -z also searches compressed files
    pkgs.duckdb # SQL over CSV/JSON/parquet logs
    pkgs.visidata # vd: interactive table viewer
    pkgs.chainsaw # Windows event logs (.evtx) with Sigma rules
  ];

  static = [
    pkgs.file
    pkgs.binutils # strings, readelf, objdump
    pkgs.hexyl
    pkgs.radare2
    pkgs.rizin
    pkgs.yara
    pkgs.yara-x
    capa
    pkgs.flare-floss # floss: deobfuscated strings
    pkgs.detect-it-easy # diec: packers, compilers, file types
    pkgs.binwalk
    pkgs.upx
    pkgs.ssdeep
    pkgs.exiftool
    pkgs._7zz # 7zz x sample.zip -pinfected
    python # pefile, oletools (olevba, …), lief, yara
  ];
}
