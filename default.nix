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
    ] ++ buildInputs;

    shellHook = ''
      unset name

      source ${scripts.base-env-vars}

      # Python virtual environment setup
      echo 'Initializing python virtual environment (this may take a while)...'
      [ ! -d $(pwd)/.venv ] && ${python38}/bin/python -m venv $(pwd)/.venv && mkdir $(pwd)/.venv/repos
      source $(pwd)/.venv/bin/activate
      python -m pip install --quiet -U pip
      [ -z TEMPDIR ] && export TEMPDIR=$(pwd)/.pip-temp
      [ -z PIP_CACHE_DIR ] && export PIP_CACHE_DIR=$TEMP_DIR
      python -m pip install --quiet -r ${scripts.base-pip-requirements}

      # Build h5py with mpi
      ${scripts.install-h5py-mpi}/bin/install-h5py-mpi

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
  }
)
