#!/usr/bin/env nix-shell
#!nix-shell -i make -p gnumake bash

SHELL := /usr/bin/env bash -o pipefail -o errexit

archive:
	git archive --output=nixos-config.tar.gz HEAD

check:
	nix flake check --all-systems

fmt:
	nix fmt

clean:
	nh clean all

update:
	nix flake update

qnas-disko:
	sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode destroy,format,mount ./disko/qnas.nix

qnas-install:
	sudo nixos-install --option extra-experimental-features "nix-command flakes" --flake .#qnas

qnas-switch:
	sudo nixos-rebuild switch --flake .#qnas

switch-nh:
	nh os switch .

jump:
	docker run -v $$PWD:/config -w /config -ti --rm nixos/nix:2.32.4 /bin/sh

show-revision:
	nixos-version --configuration-revision

show-generations:
	nixos-rebuild list-generations

.PHONY: all $(MAKECMDGOALS)
