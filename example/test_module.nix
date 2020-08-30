{ pkgs ? import <nixpkgs> { } }:

with pkgs;

stdenv.mkDerivation {
  name = "test_module";

  src = ./test_module;

  phases = "installPhase";

  installPhase = ''
    mkdir $out
    cp -r $src $out/test_module
  '';
}
