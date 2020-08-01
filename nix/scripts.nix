{ pkgs ? import <nixpkgs> { }, hdf5 ? pkgs.hdf5, mpi ? pkgs.openmpi, zlib ? pkgs.zlib }:

{
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

  dask-env-vars = pkgs.writeText "dask-env-vars" ''
    export DASK_DASHBOARD_ADDRESS=''${DASK_DASHBOARD_ADDRESS-8787}
    export DASK_SCHEDULER_HOST=''${DASK_SCHEDULER_HOST-localhost}
    export DASK_SCHEDULER_PORT=''${DASK_SCHEDULER_PORT-8786}
    export DASK_NUM_MPI_SLOTS=''${DASK_NUM_MPI_SLOTS-1}
    export DASK_NUM_THREADS_PER_WORKER=''${DASK_NUM_THREADS_PER_WORKER-$(nproc)}
    
    export DASK_SCHEDULER_URL=tcp://$DASK_SCHEDULER_HOST:$DASK_SCHEDULER_PORT 
  ''; 

  notebook-env-vars = pkgs.writeText "notebook-env-vars" ''
    export JUPYTERLAB_PORT=''${JUPYTERLAB_PORT-8888}
  ''; 

  run-dask-scheduler = pkgs.writeScriptBin "run-dask-scheduler" ''
    #!/usr/bin/env sh

    dask-scheduler --host=localhost --port=$DASK_SCHEDULER_PORT
  '';

  run-dask-worker = pkgs.writeScriptBin "run-dask-worker" ''
    #!/usr/bin/env sh

    dask-worker $DASK_SCHEDULER_URL --nthreads=$DASK_NUM_THREADS_PER_WORKER --dashboard-address=$DASK_DASHBOARD_ADDRESS '';

  run-notebook = pkgs.writeScriptBin "run-notebook" ''
    #!/usr/bin/env sh

    jupyter lab --port $JUPYTERLAB_PORT
  '';

  start-local-servers = pkgs.writeScriptBin "start-local-servers" ''
    #!/usr/bin/env python

    import os
    import subprocess
    import atexit
    import mpi4py

    comm = MPI.COMM_WORLD

    num_dask_worker_slots = int(os.getenv('DASK_NUM_MPI_SLOTS'))

    commands = [
      { "cmd": "run-dask-scheduler &> ./.logs/dask_scheduler.log", "copies": 1 },
      { "cmd": "run-dask-worker &> ./.logs/dask_workers.log", "copies": num_dask_worker_slots },
      { "cmd": "run-notebook &> ./.logs/notebook.log", "copies": 1 },
    ]
    
    def eval_process_spec(spec):
      processes = []

      if not os.path.exists('./.logs'):
          os.makedirs('./.logs')

      return subprocess.Popen([spec.get("cmd", "echo")]);

    processes = eval_process_spec(commands)

    def cleanup():
      for p in processes:
        p.kill();
        
    atexit.register(cleanup)

    for p in processes:
      p.wait();
  '';

  install-h5py-mpi = pkgs.writeScriptBin "install-h5py-mpi" ''
    #!/usr/bin/env sh

    [ -d $(pwd)/.venv/repos/h5py ] && exit 0

    pushd $(pwd)/.venv/repos
    ${pkgs.git}/bin/git clone https://github.com/h5py/h5py
    pushd $(pwd)/h5py
    export CC=${mpi}/bin/mpicc
    export HDF5_DIR=${hdf5}
    export HDF5_MPI=ON

    export NUMPY_INCLUDE=$(python -c 'import numpy; print(numpy.get_include())')
    export CPATH="$NUMPY_INCLUDE:$CPATH"
    export CPATH="${hdf5.dev}/include:$CPATH"
    export CPATH="$(pwd)/lzf:$CPATH"

    python -m pip install .
    popd
    popd
  '';

  pip-freeze = pkgs.writeScriptBin "pip-freeze" ''
    #!/usr/bin/env sh

    python -m pip freeze | grep -v h5py > $PROJECT_DIR/requirements.txt
  '';

  check-cuda = pkgs.writeScriptBin "check-cuda" ''
    #!/usr/bin/env sh

    python -c 'import torch; print(torch.cuda.is_available())'
  '';
}
