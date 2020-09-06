{ pkgs ? import <nixpkgs> { } }: 

with pkgs;
with builtins;

let

  mpi = openmpi;

  hdf5Drv = import (
    builtins.fetchTarball "https://github.com/eigenfunctor/nix-hdf5-112/archive/master.tar.gz"
  ) { inherit pkgs; };

  hdf5 = hdf5Drv.override { inherit stdenv fetchurl removeReferencesTo mpi zlib; };

  files = import ./nix/files.nix { inherit pkgs hdf5 mpi zlib; };

  scripts = import ./nix/scripts.nix { inherit pkgs hdf5 mpi zlib; };

  helpers = import ./nix/helpers.nix { inherit pkgs; };

  scriptsList = (map (key: getAttr key scripts) (attrNames scripts));

in 

args@{
  name,
  lib ? ./lib,
  requirements ? null,
  buildInputs ? [],
  pythonModules ? [],
  installPhase ? "",
  shellHook ? "",
  ...
}:

stdenv.mkDerivation (
  args // {
    inherit name;

    buildInputs = [
      hdf5
      mpi
      nodejs
      python38
      zlib
    ] ++ scriptsList ++ buildInputs ;

    src = lib;

    phases = "installPhase";

    installPhase = ''
      mkdir $out;

      cp -r $src/* $out/

      ${installPhase}
    '';

    shellHook = ''
      unset name

      source ${files.base-env-vars}

      # Python virtual environment setup
      echo 'Initializing python virtual environment (this may take a while)...'
      [ ! -d $(pwd)/.venv ] && ${python38}/bin/python -m venv $(pwd)/.venv && mkdir $(pwd)/.venv/repos
      source $(pwd)/.venv/bin/activate
      python -m pip install --quiet -U pip
      [ -z TEMPDIR ] && export TEMPDIR=$(pwd)/.pip-temp
      [ -z PIP_CACHE_DIR ] && export PIP_CACHE_DIR=$TEMP_DIR
      python -m pip install --quiet -r ${files.base-pip-requirements}
      # Install shell user's locally defined pip requirements list
      ${if (requirements != null) then "python -m pip install --quiet -r ${requirements}" else ""}

      # Build h5py with mpi
      ${scripts.install-h5py-mpi}/bin/install-h5py-mpi

      export PYTHONPATH=$PYTHONPATH:${builtins.toString lib}
      ${helpers.install-python-modules pythonModules}

      # Setup npm prefix and install pm3
      export GLOBAL_NODE_MODULES_PATH=$(pwd)/.venv/global-node-modules
      [ ! -d $GLOBAL_NODE_MODULES_PATH ] && mkdir $GLOBAL_NODE_MODULES_PATH
      npm config set prefix $GLOBAL_NODE_MODULES_PATH
      export PATH=$PATH:$GLOBAL_NODE_MODULES_PATH/bin
      [ -z $(which pm2) ] && npm install --global pm2

      # Display if Cuda can be used from mpi
      echo "Checking if CUDA is available:"
      ${scripts.check-cuda}/bin/check-cuda

      ${shellHook}
    '';

    requirements = null;
  }
)
