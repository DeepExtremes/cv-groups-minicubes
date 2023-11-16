import Pkg; Pkg.activate(".")
using CSV, DataFrames

run(`wget --no-parent -nH http://usmile.uv.es:8000/dx-minicubes/registry_2023_11_03_11_20_21.csv`)

df = CSV.read("./dx-minicubes/registry_2023_11_03_11_20_21.csv", DataFrame)

mc_path = DataFrames.filter(:path => x -> occursin("/full/", x), df, view=false)[!,"path"]

map(mc_path) do p
    run(`wget -r -q --no-parent -nH --reject="index.html*" http://usmile.uv.es:8000/dx-minicubes/$(p[24:end])`)
end
print("Minicubes downloaded in ./dx-minicubes/")