{ pkgs, lib, ... }:

{
  networking.networkmanager.enable = false;

  time.timeZone = "Europe/Berlin";

  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "50%";
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };

  users.users.daniel = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "data"
    ];
    shell = pkgs.zsh;
  };

  users.groups.data = { };

  home-manager.users.daniel =
    { ... }:
    {
      programs.zsh.enable = true;
      programs.fzf.enable = true;
      programs.eza.enable = true;
    };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.substituters = lib.mkAfter [
    "https://ts433.cachix.org"
  ];
  nix.settings.trusted-public-keys = lib.mkAfter [
    "ts433.cachix.org-1:UkneAKlz29k9xx+k+ATzYdqkbqiBvwLLSS8+mVPIyQg="
  ];

  services.fstrim.enable = true;

  # System packages (tools for NAS operation, maintenance, and debugging)
  environment.systemPackages = with pkgs; [
    # keep-sorted start
    bat
    binutils
    btop
    coreutils
    curl
    cyme
    dix
    ethtool
    fd
    git
    gnugrep
    gnumake
    hdparm
    htop
    less
    nettools
    nh
    parted
    pciutils
    procps
    ripgrep
    rkdeveloptool
    screen
    smartmontools
    tmux
    vim
    wget
    xfsprogs
    # keep-sorted end
  ];

  # Enable system-level zsh for login shell support
  programs.zsh.enable = true;

  # Nix-ld for running foreign binaries
  programs.nix-ld.enable = true;

  # Enable passwordless sudo for daniel
  security.sudo-rs = {
    enable = true;
    extraConfig = ''
      daniel ALL=(ALL) NOPASSWD: ALL
    '';
  };
}
