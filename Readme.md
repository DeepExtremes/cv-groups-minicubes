# Minicube-Splitter

Collection of scripts to split the minicubes into cross-validation folds

### Usage

````julia
julia cluster_cubes.jl
````

When running the script, all dependencies will be installed automatically through `Pkg.instaniate`, just run the program with a recent Julia version. Currently the script assumes that the minicube registry is stored in the parent folder of the script and it will write the groups into the parent folder as well. Please adjust the paths as necessary. 

# Authors

Melanie Weynants, Fabian Gans

Credits go to Jake Nelson and Basil Kraft who did the original python implementation of this splitter that this program was derived from. 
