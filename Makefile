#!/usr/bin/env nix-shell
#!nix-shell -i make -p gnumake bash

SHELL := /usr/bin/env bash -o pipefail -o errexit
.DEFAULT_GOAL := help
export SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt

help: ## Show available targets
	@while IFS= read -r line; do \
		case "$$line" in \
			[[:alnum:]_-]*": ##"*) \
				target="$${line%%:*}"; \
				description="$${line#*: ##}"; \
				printf '  %-24s %s\n' "$$target" "$$description"; \
				;; \
		esac; \
	done < "$(firstword $(MAKEFILE_LIST))"

archive: ## Archive current Git revision
	git archive --output=nixos-config.tar.gz HEAD

check: ## Run all flake checks
	nix flake check --all-systems

fmt: ## Format repository files
	nix fmt -- --clear-cache

clean: ## Remove old Nix generations and garbage
	nh clean all

update: ## Update flake inputs
	nix flake update

qnas-disko: ## Destroy, format, and mount QNAS disks
	sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode destroy,format,mount ./disko/qnas.nix

qnas-install: ## Install NixOS on QNAS
	sudo nixos-install --option extra-experimental-features "nix-command flakes" --flake .#qnas

qnas-switch: ## Apply QNAS configuration
	sudo nixos-rebuild switch --flake .#qnas

switch-nh: ## Apply local NixOS configuration with nh
	nh os switch .

jump: ## Open a Nix shell in Docker
	docker run -v $$PWD:/config -w /config -ti --rm nixos/nix:2.32.4 /bin/sh

show-revision: ## Show active configuration revision
	nixos-version --configuration-revision

show-generations: ## List NixOS generations
	nixos-rebuild list-generations

test-qnas: ## Run sandboxed QNAS VM test without secrets or internet
	nix build .#packages.aarch64-linux.qnas-test --print-build-logs

test-qnas-e2e: ## Run trusted QNAS VM test with real Healthchecks URL
	REQUIRE_SOPS_E2E=1 nix run .#packages.aarch64-linux.qnas-test-driver

secrets-edit-qnas: ## Edit QNAS secrets without persistent plaintext
	sops edit secrets/qnas.yaml

secrets-edit-ci: ## Edit CI secrets without persistent plaintext
	sops edit secrets/ci.yaml

secrets-check: ## Verify secrets are encrypted and developer-decryptable
	sops filestatus secrets/qnas.yaml
	sops filestatus secrets/ci.yaml
	sops decrypt secrets/qnas.yaml >/dev/null
	sops decrypt secrets/ci.yaml >/dev/null

secrets-update-keys: ## Sync .sops.yaml recipients while keeping current data keys
	sops updatekeys secrets/qnas.yaml secrets/ci.yaml

.PHONY: help all $(MAKECMDGOALS)
