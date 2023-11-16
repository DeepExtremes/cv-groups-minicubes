import Pkg; Pkg.activate(".")
Pkg.instantiate()

using Distances, NearestNeighbors, CSV, StaticArrays

using PlotlyJS, DataFrames, Colors, ColorSchemes

#Helper function that parses the location string from the registry in a length 2 SVector
function locstringtopoint(s)
    x,y = split(s,"_")
    @SVector [parse(Float64,x),parse(Float64,y)]
end

"""
Helper function that collects a list of `location`s into clusters while making sure that the distance between 
    locations from different clusters is always larger than `radius` using the Haversine distance. Here, `location`s is
    a vector of vectors providing the locations in (lon, lat) oder using the Haversine distance.
"""
function compute_clusters(locations,radius)
    #First build a Ball Tree for fast 
    tree = BallTree(locations,Haversine())
    #And collect all location indices in a set
    rem_locations = Set(1:length(locations))
    #Initialize the clusters
    clusters = typeof(rem_locations)[]
    while !isempty(rem_locations)
        #Pick a site that is not yet in a cluster and init a new cluster
        site = pop!(rem_locations)
        group = Set([site])
        #Get all sites within a radius
        nearby_location_inds = Set(inrange(tree,locations[site],radius))
        #While keeping only the new ones (the orevious statement will also return the initial site itself)
        setdiff!(nearby_location_inds,group)
        while !isempty(nearby_location_inds)
            # We add the close locations to the cluster
            union!(group,nearby_location_inds)
            # And look for close locations of these new ones
            for i in copy(nearby_location_inds) 
                a = inrange(tree,locations[i],radius)
                union!(nearby_location_inds,a)
            end
            # And again we only keep the newly found locations
            nearby_location_inds = setdiff!(nearby_location_inds,group)
        end
        #Here no new nearby locations are found anymore, the cluster is finished
        push!(clusters,group)
        #And we remove the sites in the cluster from the pool of locations
        setdiff!(rem_locations,group)
    end
    # Sanity check that all locations ended up in exactly one cluster
    @assert sum(length,clusters) == length(locations)
    # And return the clusters
    clusters
end


"""
    group_locations(locations,num_groups,radius)

Function to split the geographical locations given in vector of vectors `locations` into `num_groups` subgroups while making sure 
a member of each group has minimum distance of `radius` to the members of all other groups. Returns the point indices for each group.
"""
function group_locations(locations,num_groups,radius)
    #First compute clusters of sites
    clusters = compute_clusters(locations,Float64(radius))
    # Sort them by length
    sort!(clusters, by=length)

    target_group_size = ceil(Int,length(locations)/num_groups)
    groups = [Int[] for _ in 1:num_groups]

    if length(last(clusters)) > target_group_size
        throw(ArgumentError("Unable to distribute into groups, largest cluster is too large"))
    end

    # And add clusters to the groups, starting with the largest ones, always adding the largest cluster to the smallest group
    while !isempty(clusters)
        cluster = pop!(clusters)
        _,i = findmin(length,groups)
        append!(groups[i],cluster)
    end

    groups
end

"""
    plot_groups(df_loc)
"""
function plot_groups(df_loc, ng, dist, filt; kwargs...)
    mcol = @isdefined(marker_color) ? marker_color : df_loc[!,:group]
    colscale = @isdefined(colorscale) ? colorscale : "Viridis"
    trace = scattergeo(;lat=df_loc[!,:lat], lon=df_loc[!,:lon], 
        marker_color = mcol,
        marker_size = 2,
        colorscale = colscale,
        )
    geo = attr(scope="world")
    # create fig
    layout = Layout(; title="DeepExtremes $filt minicubes - $ng groups distant of at least $dist km",
     showlegend=false, geo=geo)
    plot(trace, layout)
end

function filter_group(alldata, ng::Int, dist::Number, filt::String)
    ind = [occursin(filt, d.path) for d in alldata]

    locations = [locstringtopoint(d.location_id) for d in alldata]
    mc_id = [d.mc_id for d in alldata]

    # create groups
    groups = group_locations(locations[ind],ng,dist*1e3)

    # create output data frame
    df_loc = DataFrame(mc_id = String[], lon=Float64[], lat=Float64[])
    map( (x,y) -> push!(df_loc,[x,y...]), mc_id[ind],locations[ind])

    # attach groups
    df_loc[!, :group] .= 0;
    for g in 1:length(groups)
        # filter df_loc
        df_loc[groups[g], :group] .= g
    end

    return df_loc
end

alldata = CSV.Rows("../registry_2023_11_03_11_20_21.csv")

ng = 10
dist = 50
filt = "full"
df_loc = filter_group(alldata, ng, dist, filt)
 
# save groups
CSV.write("../demc_$(filt)_$(ng)groups_$(dist)km.csv", df_loc)

# plot groups

cols = colorschemes[:viridis][range(0,(ng-1))/(ng-1)]

p = plot_groups(df_loc, ng, dist, filt, colorscale = "Jet")
mkdir("./fig")
savefig(p, "./fig/map_demc_$(filt)_$(ng)groups_$dist.png")

for g in 1:ng
    p1 = plot_groups(filter(:group => x -> x==g, df_loc), ng, dist, filt, marker_color = g, colorscale = cols[g])
    savefig(p1, "./fig/map_demc_$(filt)_$(g)of$(ng)groups_$dist.png")
end

