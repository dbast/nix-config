# nix-config

This repository contains a minimal NixOS configuration for a QNAP TS-433 NAS, including the extlinux/U-Boot boot setup, RK3568 kernel module defaults, and disk layout used by the `qnas` machine. It assumes the device is booted with a mainline U-Boot image, such as the one built by [qnap-ts-433-bootloader-builder](https://github.com/dbast/qnap-ts-433-bootloader-builder), and is intentionally TS-433-first until related hardware has been tested.

The same setup can potentially also be used for related TSx33 devices by forcing the Linux device tree that NixOS writes into `extlinux.conf`, for example `hardware.deviceTree.name = "rockchip/rk3568-qnap-ts233.dtb";` for TS-233 or `hardware.deviceTree.name = "rockchip/rk3566-qnap-ts133.dtb";` for TS-133. Treat this as experimental: the TS-433 U-Boot image may be enough to hand off to Linux with the right DTB, but TS-133/TS-233-specific support should only be promoted into real modules after validation on hardware.

## Makefile

The [`Makefile`](./Makefile) provides the common build, test, deployment, and secrets operations. Run `make help` for the available targets.

## Secrets

SOPS encrypts values committed under `secrets/`. sops-nix decrypts production secrets on each machine during activation and writes root-only files under `/run/secrets`. Private age identities must never enter Git or the Nix store.

| Identity | `secrets/qnas.yaml` | `secrets/ci.yaml` | Private identity |
| --- | --- | --- | --- |
| Developer | yes | yes | `~/.config/sops/age/keys.txt` |
| QNAS | yes | no | `/var/lib/sops-nix/key.txt` on QNAS |
| CI | no | yes | GitHub secret `SOPS_AGE_KEY` |

All recipients begin with `age1pq1` and use age's hybrid ML-KEM-768 + X25519 construction. Required versions are age 1.3 or newer and SOPS 3.12.1 or newer. Secrets-related Make targets use the developer identity at `~/.config/sops/age/keys.txt`; export `SOPS_AGE_KEY_FILE` when running SOPS directly.

Both encrypted files contain the same key with environment-specific values:

```yaml
healthchecks-canary-url: https://hc-ping.com/...
```

Never use `sops decrypt --in-place`: it leaves plaintext in the worktree.

### Generate Keys

Generate developer identity:

```sh
umask 077
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
mkdir -p "$(dirname "$SOPS_AGE_KEY_FILE")"
age-keygen -pq -o "$SOPS_AGE_KEY_FILE"
age-keygen -y "$SOPS_AGE_KEY_FILE"
```

Generate a machine identity on that machine, then add only the printed `age1pq1...` recipient to `.sops.yaml`:

```sh
sudo install -d -m 0700 -o root -g root /var/lib/sops-nix
sudo age-keygen -pq -o /var/lib/sops-nix/key.txt
sudo age-keygen -y /var/lib/sops-nix/key.txt
```

To add a new machine completely:

1. Generate its machine identity as above.
1. Add the public recipient to the `keys` section of `.sops.yaml` under a machine-named YAML anchor.
1. Add a `creation_rules` entry for `secrets/<machine>.yaml` containing the developer and machine anchors.
1. Create the encrypted file with `sops edit secrets/<machine>.yaml`.
1. Configure the machine's sops-nix module with that file as `defaultSopsFile`, `/var/lib/sops-nix/key.txt` as `age.keyFile`, and its required `sops.secrets` declarations.
1. Add `secrets-edit-<machine>` and include the new file in the `secrets-check` and `secrets-update-keys` Make targets.

Generate CI identity temporarily and upload it directly to GitHub:

```sh
ci_key_dir="$(mktemp -d)"
ci_key="$ci_key_dir/keys.txt"
umask 077
age-keygen -pq -o "$ci_key"
age-keygen -y "$ci_key"
gh secret set SOPS_AGE_KEY < "$ci_key"
rm -f "$ci_key"
rmdir "$ci_key_dir"
```

### Revoke Or Replace A Key

Adding access only needs `.sops.yaml` plus `make secrets-update-keys`. Removing or replacing access requires new file data keys:

1. Remove recipient from `.sops.yaml`.
1. Run `make secrets-update-keys`.
1. Rotate affected data key with `sops rotate --in-place secrets/qnas.yaml` or `secrets/ci.yaml`.
1. If the identity may be compromised, rotate the affected credentials now.
1. Run `make secrets-check` and commit ciphertext changes.

Order matters: rotate file data key before writing replacement credentials. Historical Git revisions remain decryptable by recipients authorized at that revision.

Periodic data-key rotation uses the same explicit commands:

```sh
sops rotate --in-place secrets/qnas.yaml
sops rotate --in-place secrets/ci.yaml
```
