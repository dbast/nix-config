{ pkgs, ... }:

{
  systemd.user.startServices = "suggest";

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "z"
      ];
    };

    initContent = pkgs.lib.mkOrder 600 ''
      eval "$(pixi completion --shell zsh)"
    '';
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    # Use fd for fast traversal
    defaultCommand = "fd --hidden --follow --exclude .git .";
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git .";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git .";
    # Core display / preview behavior
    defaultOptions = [
      "--layout=reverse"
      "--ansi"
      "--preview-window=right:60%"
      "--preview"
      "'bat --style=numbers,changes --wrap never --color always {} 2>/dev/null || eza --tree --level 2 --icons --color=always --group-directories-first {} 2>/dev/null'"
    ];
  };

  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
    extraOptions = [
      "--color-scale=all"
      "--header"
      "--hyperlink"
    ];
  };

  home.shellAliases = {
    gs = "git status";
  };

  home.sessionVariables.SHELL = "${pkgs.zsh}/bin/zsh";

  home.packages = with pkgs; [
    # keep-sorted start
    lazygit
    nix-output-monitor
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
