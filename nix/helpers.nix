{ pkgs ? import <nixpkgs> { } }:

with builtins;
with pkgs.lib;

{
  # Returns shell command string for taking a list of
  # python module derivation paths and copying them to the virtual env's repos
  # directory. Also updates the PYTHONPATH environment variable
  # with the copied repo's pat.
  install-python-modules = 
    let
      install-python-module =
        (pythonModule: ''

          [ ! -d $(pwd)/.venv/repos/$(basename ${pythonModule}) ] && cp -r ${pythonModule} $(pwd)/.venv/repos/

          export PYTHONPATH=$PYTHONPATH:$(pwd)/.venv/repos/$(basename ${pythonModule})

        '');
    in 
      (pythonModules: concatStrings (map install-python-module pythonModules));
}
