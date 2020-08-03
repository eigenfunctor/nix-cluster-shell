{ pkgs ? import <nixpkgs> { } }: 

with pkgs;
with builtins;

let

  mpi = openmpi;

  hdf5Drv = import (
    builtins.fetchTarball "https://github.com/eigenfunctor/nix-hdf5-112/archive/master.tar.gz"
  ) { inherit pkgs; };

  hdf5 = hdf5Drv.override { inherit stdenv fetchurl removeReferencesTo mpi zlib; };

  scripts = import ./nix/scripts.nix { inherit pkgs hdf5 mpi zlib; };

  scriptsList = (map (key: getAttr key scripts) (attrNames scripts));

in 

args@{ name, buildInputs ? [], shellHook ? "", ... }: 

stdenv.mkDerivation (
  args // {
    inherit name;

    buildInputs = [
      hdf5
      mpi
      nodejs
      python38
      zlib
    ] ++ scriptsList ++ buildInputs;

    shellHook = ''
      unset name

      source ${scripts.base-env-vars}

      # Python virtual environment setup
      echo 'Initializing python virtual environment...'
      [ ! -d $(pwd)/.venv ] && ${python38}/bin/python -m venv $(pwd)/.venv && mkdir $(pwd)/.venv/repos
      source $(pwd)/.venv/bin/activate
      python -m pip install --quiet -U pip
      [ -z TEMPDIR ] && export TEMPDIR=$(pwd)/.pip-temp
      [ -z PIP_CACHE_DIR ] && export PIP_CACHE_DIR=$TEMP_DIR
      [ -f requirements.txt ] && python -m pip install --quiet -r requirements.txt

      # Build h5py with mpi
      ${scripts.install-h5py-mpi}/bin/install-h5py-mpi

      # Display if Cuda can be used from mpi
      echo "Checking if CUDA is available:"
      ${scripts.check-cuda}/bin/check-cuda

      ${shellHook}
    '';
  }
)
