using AWSS3, AWS, FilePathsBase;
# using Dates

aws = global_aws_config(; region="eu-central-1") # pass keyword arguments to change defaults
BUCKET="s3://deepextremes-minicubes"
REGISTRY_PATH="mc_registry_v4.csv"

# global_aws_config() is also the default if no `config` argument is passed
p = S3Path("$BUCKET", config=global_aws_config());

readdir(p)

file = joinpath(p, REGISTRY_PATH)
stat(file)
  
# copy file
# write("mc_registry_$(Dates.format(now(), "yyyy_mm_dd_HH_MM_SS")).csv", read(file))
write(REGISTRY_PATH, read(file))