{ inputs, system }:

(import "${inputs.nixpkgs}/nixos/lib/testing-python.nix" { inherit system; }).runTest {
  name = "rnas-integration-test";

  nodes.machine =
    { lib, pkgs, ... }:
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
      environment.systemPackages = [ pkgs.restic ];

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
    import shlex

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

    # Simulate Web UI folder creation, pairing, and sharing, then restart.
    machine.succeed(
        f"{cli} config folders add --id shared --label shared --path /data/shared --ignore-perms"
    )
    config = json.loads(machine.succeed(f"{cli} config dump-json"))
    machine.succeed("syncthing generate --home=/tmp/syncthing-peer")
    peer = machine.succeed("syncthing device-id --home=/tmp/syncthing-peer").strip()
    machine.succeed(f"{cli} config devices add --device-id {peer} --name manual-peer")
    folder = config["folders"][0]
    folder["devices"].append({"deviceID": peer})
    payload = shlex.quote(json.dumps(folder))
    api_key = config["gui"]["apiKey"]
    machine.succeed(
        f"curl --fail -H 'X-API-Key: {api_key}' -H 'Content-Type: application/json' "
        f"-X PUT -d {payload} http://127.0.0.1:8384/rest/config/folders/shared"
    )
    machine.succeed("systemctl restart syncthing.service")
    machine.wait_until_succeeds(f"{cli} config dump-json >/dev/null")
    config = json.loads(machine.succeed(f"{cli} config dump-json"))
    assert [folder["id"] for folder in config["folders"]] == ["shared"]
    assert config["folders"][0]["path"] == "/data/shared"
    assert config["folders"][0]["ignorePerms"]
    assert any(device["deviceID"] == peer for device in config["devices"])
    assert any(device["deviceID"] == peer for device in config["folders"][0]["devices"])
  '';
}
