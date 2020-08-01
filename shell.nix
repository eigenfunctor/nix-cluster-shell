{ pkgs ? import <nixpkgs> { } }:
let

  mkDerivation = import ./default.nix { inherit pkgs; };

in mkDerivation {
  name = "example";
}
