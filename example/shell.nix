{ pkgs ? import <nixpkgs> { } }:

let

  mkDerivation = import ../default.nix { inherit pkgs; };

in mkDerivation {
  name = "example";

  requirements = pkgs.writeTextFile {
    name = "requirements.txt";
    text = (builtins.readFile ./my-env-requirements.txt);
  };
}
