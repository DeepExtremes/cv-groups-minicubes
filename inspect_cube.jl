# inspect minicube
import Pkg; Pkg.activate(".")

using YAXArrays, EarthDataLab, Zarr

using AWSS3, AWS, FilePathsBase;
aws = global_aws_config(; region="eu-central-1") # pass keyword arguments to change defaults
bucket="deepextremes-minicubes"
p = S3Path("s3://$bucket", config=aws)
readdir(p)

registry_path = "mc_registry_v4.csv"
registry = joinpath(p, registry_path);
stat(registry)

s3_get_file(aws, "$bucket", registry_path, registry_path)

import CSV
alldata = CSV.Rows(registry_path)
mc_path = [d.path for d in alldata]
mc_path[end]

# open remote miniube
tmp = open_dataset(zopen(joinpath("s3://"*mc_path[end])))
