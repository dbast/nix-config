{ inputs, system }:

(import "${inputs.nixpkgs}/nixos/lib/testing-python.nix" { inherit system; }).runTest {
  name = "rnas-integration-test";

  nodes.machine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        ./../machines/rnas.nix
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
        inputs.nixos-hardware.nixosModules.qnap-ts-233
        inputs.nixos-monitoring-lite.nixosModules.default
        inputs.sops-nix.nixosModules.sops
      ];

      disko.devices.disk.main.device = "/dev/vda";
      networking.interfaces.eth0.useDHCP = true;
      system.configurationRevision = "1111111111111111111111111111111111111111";

      sops.useSystemdActivation = true;
      sops.validateSopsFiles = false;
      systemd.services.sops-install-secrets = {
        wantedBy = lib.mkForce [ ];
        requiredBy = lib.mkForce [ ];
      };
      systemd.timers.monitoring-lite-canary.wantedBy = lib.mkForce [ ];

      services.restic.server.htpasswd-file = lib.mkForce "/etc/restic-test.htpasswd";
      environment.etc."restic-test.htpasswd".source = pkgs.runCommand "restic-test.htpasswd" { } ''
        ${pkgs.apacheHttpd}/bin/htpasswd -bcB "$out" test test-password
      '';
      environment.systemPackages = [
        pkgs.restic
        (pkgs.writeShellApplication {
          name = "restic-canary-evidence";
          inherit (config.services.monitoringLite.canary.extraContext.restic-internal) runtimeInputs;
          text = config.services.monitoringLite.canary.extraContext.restic-internal.script;
        })
      ];
      services.restic.backups.internal.passwordFile = lib.mkForce "/run/restic-test-password";
      systemd.timers.restic-backups-internal.wantedBy = lib.mkForce [ ];

      virtualisation = {
        memorySize = 2048;
        diskSize = 8192;
        # ponytail: smoke test uses tmpfs; add a virtual XFS disk for storage tests.
        fileSystems."/lake" = {
          device = "none";
          fsType = "tmpfs";
        };
      };
    };

  testScript = ''
    import json

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("sshd.service")
    machine.succeed("test $(hostname) = rnas")
    machine.succeed("id qop")
    machine.succeed("su - qop -c 'command -v zsh && command -v git'")
    machine.succeed("mountpoint /lake")
    machine.succeed("test -w /lake")

    machine.wait_for_unit("restic-rest-server.service")
    machine.succeed("su -s /bin/sh restic -c 'test -w /lake/backup/hosted'")
    assert machine.succeed("curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/test/config").strip() == "401"
    machine.succeed("RESTIC_PASSWORD=test-repository-password restic -r rest:http://test:test-password@127.0.0.1:8000/test init")
    machine.succeed("test -f /lake/backup/hosted/test/config")
    machine.fail("RESTIC_PASSWORD=test-repository-password restic -r rest:http://test:test-password@127.0.0.1:8000/other init")
    machine.succeed("test ! -e /lake/backup/hosted/other")

    machine.wait_for_unit("syncthing.service")
    machine.succeed("test -d /data && ! mountpoint -q /data")
    machine.succeed("su -s /bin/sh syncthing -c 'test -w /data/shared'")
    machine.succeed("su - qop -c 'test -w /data/shared'")
    cli = "syncthing cli --home=/data/syncthing/.config/syncthing"
    machine.wait_until_succeeds(f"{cli} config dump-json >/dev/null")
    config = json.loads(machine.succeed(f"{cli} config dump-json"))
    assert config["folders"] == [], "Folders should be configured through the Web UI"
    assert config["gui"]["address"] == "127.0.0.1:8384"
    assert len(config["devices"]) == 1, "Only the local device should exist"

    # A folder added interactively must survive a restart.
    machine.succeed(
        f"{cli} config folders add --id shared --label shared --path /data/shared --ignore-perms"
    )
    machine.succeed("systemctl restart syncthing.service")
    machine.wait_until_succeeds(f"{cli} config dump-json >/dev/null")
    config = json.loads(machine.succeed(f"{cli} config dump-json"))
    assert [folder["id"] for folder in config["folders"]] == ["shared"]
    assert config["folders"][0]["path"] == "/data/shared"
    assert config["folders"][0]["ignorePerms"]

    machine.succeed("systemctl stop syncthing.service")
    machine.succeed("printf shared-test > /data/shared/backup-test")
    machine.succeed("printf syncthing-test > /data/syncthing/backup-test")
    machine.succeed("printf test-only-password > /run/restic-test-password")
    machine.succeed("printf journal-backup-marker | systemd-cat -t restic-backup-test")
    machine.succeed("systemctl start restic-backups-internal.service")
    snapshot_id = machine.succeed("journalctl --sync && restic-canary-evidence").strip()
    snapshots = json.loads(machine.succeed("restic-internal snapshots --json"))
    assert snapshot_id == snapshots[-1]["id"]
    assert len(snapshot_id) == 64
    machine.succeed("restic-internal restore latest --target /tmp/restore")
    machine.succeed("cmp /data/shared/backup-test /tmp/restore/data/shared/backup-test")
    machine.succeed("cmp /data/syncthing/backup-test /tmp/restore/data/syncthing/backup-test")
    assert machine.succeed("cat /tmp/restore/data/nixos-configuration-revision").strip() == "1111111111111111111111111111111111111111"
    machine.succeed(
        "journalctl --directory=/tmp/restore/var/log/journal/$(cat /etc/machine-id) "
        "-t restic-backup-test --no-pager -o cat | grep -Fx journal-backup-marker"
    )
    machine.succeed("test ! -e /tmp/restore/var/log/journal/$(cat /etc/machine-id)/system.journal")
    machine.succeed("test -d /data/smart")
  '';
}
