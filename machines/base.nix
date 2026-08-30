{ pkgs, lib, ... }:

let
  username = "qop";
in
{
  networking.networkmanager.enable = false;

  time.timeZone = "Europe/Berlin";

  # Mount /tmp as tmpfs
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

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "data"
    ];
    shell = pkgs.zsh;
  };

  users.groups.data = { };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username}.imports = [ ../users/hm-generic.nix ];
  };

  # Allow unfree packages (if needed for your hardware/tools)
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
    age
    bat
    binutils
    btop
    coreutils
    cryptsetup
    curl
    cyme
    dix
    duf
    ethtool
    fd
    findutils
    fuc
    ghostty.terminfo
    git
    gnugrep
    gnumake
    hdparm
    htop
    less
    lf
    nettools
    nh
    nvme-cli
    parted
    pciutils
    powertop
    procps
    rclone
    restic
    ripgrep
    rkdeveloptool
    screen
    smartmontools
    snitch
    time
    tmux
    ttl
    unzip
    vim
    wget
    witr
    xfsprogs
    zoxide
    # keep-sorted end
  ];

  # Enable system-level zsh for login shell support
  programs.zsh.enable = true;

  # Nix-ld for running foreign binaries
  programs.nix-ld.enable = true;

  # Enable passwordless sudo for the primary user
  security.sudo-rs = {
    enable = true;
    extraConfig = ''
      ${username} ALL=(ALL) NOPASSWD: ALL
    '';
  };
}
