{
  pkgs,
  lib,
  inputs ? { },
  ...
}:

let
  username = "qop";
in
{
  # Store the flake's narHash in /etc so the exact configuration source
  # is identifiable on the running system via /run/current-system/etc/flake-narHash
  environment.etc."flake-narHash".text = inputs.self.narHash or "unknown";

  # Include the narHash in the canary heartbeat payload (Context: flake-narHash:...)
  services.monitoringLite.canary.extraContext.flake-narHash = {
    runtimeInputs = [ pkgs.coreutils ];
    script = "cat /etc/flake-narHash";
  };

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
    btrfs-progs
    coreutils
    cryptsetup
    curl
    cyme
    dix
    duf
    ethtool
    exfatprogs
    fd
    findutils
    fuc
    ghostty.terminfo
    git
    gnugrep
    gnumake
    gnupg
    hdparm
    htop
    iperf
    less
    lf
    lvm2
    mdadm
    nettools
    nh
    nvme-cli
    openssl
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
    sops
    time
    tmux
    ttl
    unzip
    uutils-coreutils
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

  # Require the root password for the primary user's sudo commands
  security.sudo-rs = {
    enable = true;
    extraConfig = ''
      Defaults:${username} rootpw
      ${username} ALL=(ALL) PASSWD: ALL
    '';
  };
}
