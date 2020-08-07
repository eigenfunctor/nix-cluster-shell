{ pkgs ? import <nixpkgs> { }, hdf5 ? pkgs.hdf5, mpi ? pkgs.openmpi, zlib ? pkgs.zlib }:

rec {
  base-env-vars = pkgs.writeText "base-env-vars" ''
    # Keep track of project directory
    export PROJECT_DIR=$(pwd)

    # Libraries setup
    [ -z LD_LIBRARY_PATH ] && export LD_LIBRARY_PATH=""
    export LD_LIBRARY_PATH=${hdf5}:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${mpi}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.python38}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=${pkgs.zlib}/lib:$LD_LIBRARY_PATH
  '';

  install-h5py-mpi =
    let
      h5py-repo = builtins.fetchGit { url = "https://github.com/h5py/h5py"; };
    in pkgs.writeScriptBin "install-h5py-mpi" ''
      #!/usr/bin/env sh

      H5PY_REPO_DIR=$(pwd)/.venv/repos/$(basename ${h5py-repo})

      [ -d $H5PY_REPO_DIR ] && exit 0

      cp -r ${h5py-repo} $H5PY_REPO_DIR 
      chmod -R gu+rw $H5PY_REPO_DIR

      pushd $H5PY_REPO_DIR

      export CC=${mpi}/bin/mpicc
      export HDF5_DIR=${hdf5}
      export HDF5_MPI=ON

      export NUMPY_INCLUDE=$(python -c 'import numpy; print(numpy.get_include())')
      export CPATH="$NUMPY_INCLUDE:$CPATH"
      export CPATH="${hdf5.dev}/include:$CPATH"
      export CPATH="$(pwd)/lzf:$CPATH"

      python -m pip install --no-binary :all: .

      popd
    '';

  pip-freeze = pkgs.writeScriptBin "pip-freeze" ''
    #!/usr/bin/env sh

    python -m pip freeze | grep -v h5py
  '';

  base-pip-requirements = pkgs.writeTextFile {
    name = "requirements.txt";
    text = (builtins.readFile ./requirements.txt);
  };

  check-cuda = pkgs.writeScriptBin "check-cuda" ''
    #!/usr/bin/env sh

    python -c 'import torch; print(torch.cuda.is_available())'
  '';
}
