{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./base.nix
    ../disko/rnas.nix
  ];

  networking.hostName = "rnas";
  boot.loader.generic-extlinux-compatible.configurationLimit = 5;
  hardware.deviceTree.name = "rockchip/rk3568-qnap-ts233-pcb-12-11.dtb";
  hardware.enableRedistributableFirmware = true;

  sops = {
    defaultSopsFile = ../secrets/rnas.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      sshKeyPaths = [ ];
    };
    gnupg.sshKeyPaths = [ ];
    secrets = {
      healthchecks-alert-url = { };
      healthchecks-canary-url = { };
      restic-internal-password = { };
      restic-rest-server-htpasswd = {
        owner = "restic";
        group = "restic";
        mode = "0400";
        restartUnits = [ "restic-rest-server.service" ];
      };
    };
  };

  services.monitoringLite = {
    canary = {
      enable = true;
      urlFile = config.sops.secrets.healthchecks-canary-url.path;
      disks = [
        "/"
        "/lake"
      ];
      extraContext.u-boot-version = {
        runtimeInputs = [ pkgs.coreutils ];
        script = ''
          tr -d '\0' < /proc/device-tree/chosen/u-boot,version
        '';
      };
      extraContext.restic-internal = {
        runtimeInputs = [
          pkgs.systemd
          pkgs.jq
        ];
        script = ''
          journalctl -u restic-backups-internal --no-pager -o cat |
            jq -Rnr '
              reduce (inputs | fromjson? | objects
                | select(.message_type == "summary") | .snapshot_id | strings)
                as $id ("unknown"; $id)
            '
        '';
      };
      extraContext.ssh-auth-7d = {
        runtimeInputs = [
          pkgs.systemd
          pkgs.gawk
        ];
        script = ''
          journalctl -u sshd --since "7 days ago" --no-pager -o cat |
            awk '
              /^(Accepted|Failed) .* from / {
                loopback = / from (127\.0\.0\.1|::1) port /
                if ($1 == "Accepted") {
                  accepted++; loopback_accepted += loopback
                } else {
                  failed++; loopback_failed += loopback
                }
              }
              END {
                printf "accepted=%d failed=%d loopback_accepted=%d loopback_failed=%d\n", accepted, failed, loopback_accepted, loopback_failed
              }
            '
        '';
      };
    };
    smartd = {
      enable = true;
      urlFile = config.sops.secrets.healthchecks-alert-url.path;
      shortSelfTest = {
        enable = true;
        triggerAfterUnits = [ "restic-backups-internal" ];
      };
    };
    systemdFail = {
      enable = true;
      urlFile = config.sops.secrets.healthchecks-alert-url.path;
      services = [
        "monitoring-lite-smartd-short-self-test"
        "restic-backups-internal"
        "restic-rest-server"
        "smartd"
        "sshd"
        "syncthing"
        "tor"
      ];
    };
  };

  fileSystems."/lake" = {
    device = "/dev/disk/by-label/hdd-lake";
    fsType = "xfs";
    options = [
      "defaults"
      "logbsize=256k"
      "X-fstrim.notrim"
    ];
  };

  users.users.syncthing.extraGroups = [ "data" ];

  systemd.tmpfiles.rules = [
    "d /data 0755 root root -"
    "d /data/shared 2770 syncthing data -"
    "d /data/smart 0700 root root -"
    "d /data/syncthing 0750 syncthing syncthing -"
    "d /lake/backup/hosted 0750 restic restic -"
    "d /lake/backup/internal 0700 root root -"
  ];

  services.restic.backups.internal = {
    repository = "/lake/backup/internal";
    passwordFile = config.sops.secrets.restic-internal-password.path;
    initialize = true;
    timerConfig = {
      OnCalendar = "Sun *-*-* 08:00:00";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
    paths = [ "/data" ];
    dynamicFilesFrom = ''
      ${pkgs.findutils}/bin/find /var/log/journal -type f -name '*@*.journal' -print
    '';
    extraBackupArgs = [
      "--json"
      "--group-by host"
    ];
    pruneOpts = [
      "--group-by host"
      "--keep-weekly 4"
      "--keep-monthly 6"
      "--keep-yearly 2"
    ];
    checkOpts = [ "--with-cache" ];
    runCheck = true;
    backupPrepareCommand = ''
      set -eu
      umask 077
      /run/current-system/sw/bin/nixos-version --configuration-revision > /data/nixos-configuration-revision
      ${pkgs.systemd}/bin/journalctl --sync
      ${pkgs.systemd}/bin/journalctl --rotate
    '';
    backupCleanupCommand = ''
      # Capture while disks are awake, before the OnSuccess self-test.
      ts=$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
      for d in /dev/disk/by-id/ata-*; do
        [ -e "$d" ] || continue
        case "$d" in *-part*) continue ;; esac
        # smartctl also returns nonzero when its JSON reports disk health problems.
        ${pkgs.smartmontools}/bin/smartctl --json -x "$d" \
          > "/data/smart/''${d##*/}_$ts.json" || true
      done
    '';
  };
  systemd.services.restic-backups-internal.unitConfig.RequiresMountsFor = [ "/lake" ];

  services.restic.server = {
    enable = true;
    dataDir = "/lake/backup/hosted";
    privateRepos = true;
    listenAddress = "0.0.0.0:8000";
    htpasswd-file = config.sops.secrets.restic-rest-server-htpasswd.path;
  };
  systemd.services.restic-rest-server.unitConfig.RequiresMountsFor = [ "/lake" ];
  networking.firewall.allowedTCPPorts = [ 8000 ];

  services.syncthing = {
    enable = true;
    dataDir = "/data/syncthing";
    guiAddress = "127.0.0.1:8384";
    openDefaultPorts = true;
    # Manage folders and devices through the Web UI.
    overrideDevices = false;
    overrideFolders = false;
  };

  services.tor = {
    enable = true;
    relay.onionServices.ssh = {
      version = 3;
      map = [
        {
          port = 22;
          target = {
            addr = "127.0.0.1";
            port = 22;
          };
        }
      ];
    };
  };

  services.udev.extraRules =
    let
      mkRule = as: lib.concatStringsSep ", " as;
      mkRules = rs: lib.concatStringsSep "\n" rs;
    in
    mkRules [
      (mkRule [
        ''ACTION=="add|change"''
        ''SUBSYSTEM=="block"''
        ''KERNEL=="sd[a-z]"''
        ''ATTR{queue/rotational}=="1"''
        ''RUN+="${pkgs.hdparm}/bin/hdparm -S 244 /dev/%k"''
      ])
    ];

  system.stateVersion = "25.11";
}
