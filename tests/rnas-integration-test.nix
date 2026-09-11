{ inputs, system }:

(import "${inputs.nixpkgs}/nixos/lib/testing-python.nix" { inherit system; }).runTest {
  name = "rnas-integration-test";

  nodes.machine =
    { lib, ... }:
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
      systemd.services.sops-install-secrets = {
        wantedBy = lib.mkForce [ ];
        requiredBy = lib.mkForce [ ];
      };
      systemd.timers.monitoring-lite-canary.wantedBy = lib.mkForce [ ];

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
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("sshd.service")
    machine.succeed("test $(hostname) = rnas")
    machine.succeed("id qop")
    machine.succeed("su - qop -c 'command -v zsh && command -v git'")
    machine.succeed("mountpoint /lake")
    machine.succeed("test -w /lake")
  '';
}
