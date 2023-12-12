# prepare for earthnet
import Pkg; Pkg.activate(".")
Pkg.instantiate()

using DataFrames, CSV
using Zarr, YAXArrays
import Random
import Statistics

# mcrepo 
# "/Volumes/bgi/work_2/scratch/DeepExtremes/minicubes_leipzig/"
# "/Net/Groups/BGI/work_2/scratch/DeepExtremes/minicubes_leipzig/"
# "/Net/Groups/BGI/work_2/scratch/DeepExtremes/fromharddrive/dx-minicubes/"
mcrepo = "/Volumes/bgi/work_2/scratch/DeepExtremes/minicubes_leipzig/" # 

groups = CSV.read("./results/demc_full_10groups_50km.csv", DataFrame)
mc = CSV.read("./mc_registry_v4.csv", DataFrame)

# train_start: random 1 to 4
Random.seed!(42);groups[!,:train_start] = rand(1:4, size(groups)[1]);

# join groups and path
groups = leftjoin!(groups, mc[:,1:2], on = :mc_id)
map!(x -> SubString(x, 23), groups[!,:path], groups[!,:path])
# data quality check:
# open each mc
groups[!,:check] .= 0
groups[!,:s2_check] .= missing
groups[!,:cloud_check] .= missing
groups[!,:cloud_free] .= missing
groups[!,:era_check] .= 0
groups[!,:dem_check] .= 0
groups[!,:start_date] .= DateTime(2016)

# helper functions
nanormis = function(array){
    return map(x -> isnan(x) | ismissing(x), array)
}

# check that variable is present, compute mean over time and space
for i in size(groups,1)
    try
        minicube = open_dataset(mcrepo * groups[i,:path]);
    catch
        groups[i,:check] = 1
        continue
    end

    # data check
    # read data only once with readcubedata(cube)
    # s2
    B8A = readcubedata(minicube.B8A)
    B04 = readcubedata(minicube.B04)
    cm  = readcubedata(minicube.cloudmask_en)
    SCL = readcubedata(minicube.SCL)


    try
        # s2 data: if mean ndvi is not NaN32, OK
        if isnan(
            Statistics.mean((B8A .- B04) ./ (B8A .+ B04))
            # if NaN32
        )
            groups[i,:check] = 3
            continue
        end
    catch
        # data can't even be accessed
        groups[i,:check] = 2
        continue
    end
    # actual number of s2 dates where it is not all NaN
    tmp = any(map(!isnan, B8A), dims = (1,2))
    groups[i,:s2_check] = sum(tmp)

    # number of s2 dates w/o cloud mask
    groups[i,:cloud_check] = sum(! (cm.Time in SCL.Time))

    # number of dates with >25% cloud free (free sky == 0)
    tmp = sum(minicube.cloudmask_en .== 0, dims = (1,2)) 
    groups[i,:cloud_free] = sum(tmp .> 0.25 * 128 * 128)

    
    # per era5 var:
    # number of missing observations
    # check that they are all not NaN/missing

    # dem: number NaN or missing
    groups[i,dem_check] = sum(nanormis(minicube.cop_dem))

    # start_date
    # first s2 observation in trimester
    # 1: MAM, 2: JJA, 3: SON, 4: DJF
    groups[i, :start_date] = minicube.SCL.Time[findfirst(minicube.SCL.Time .>= DateTime(2017, groups[i, :train_start]*3))]
end


