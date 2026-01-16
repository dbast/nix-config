{
  projectRootFile = "flake.nix";
  programs = {
    actionlint.enable = true;
    deadnix.enable = true;
    jsonfmt.enable = true;
    keep-sorted.enable = true;
    nixfmt.enable = true;
    shellcheck.enable = true;
    statix.enable = true;
    shfmt.enable = true;
    taplo.enable = true;
    yamlfmt.enable = true;
  };
  settings = {
    formatter = { };
  };
}
