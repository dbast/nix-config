{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
  };

  home.sessionVariables.SHELL = "${pkgs.zsh}/bin/zsh";

  home.packages = with pkgs; [
    # keep-sorted start
    tig
    # keep-sorted end
    # Pixi package manager wrapped in FHS environment for NixOS compatibility
    # https://github.com/NixOS/nixpkgs/issues/316443
    (pkgs.buildFHSEnv {
      name = "pixi";
      runScript = "pixi";
      targetPkgs = _: [ pkgs.pixi ];
    })
    # General FHS shell for running dynamically linked binaries
    (pkgs.buildFHSEnv {
      name = "fhs-shell";
      runScript = "bash";
      targetPkgs =
        _: with pkgs; [
          openssl
        ];
    })
  ];

  home.stateVersion = "25.11";
}
