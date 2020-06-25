"""
    InfrastructureGraph{T<:LightGraphs.AbstractGraph}

A structure containing a graph of a PowerModels or PowerModelsDistribution network in
the format of a LightGraphs.AbstractGraph and corresponding metadata necessary for
analysis / plotting.
"""
mutable struct InfrastructureGraph{T<:LightGraphs.AbstractGraph}
    graph::LightGraphs.AbstractGraph

    metadata::Dict{Union{Int,LightGraphs.AbstractEdge},Dict{Symbol,<:Any}}
end


"""
    InfrastructureGraph(nvertices)

Constructor for the InfrastructureGraph struct, given a number of vertices `nvertices`
"""
function InfrastructureGraph(nvertices::Int)
    graph = LightGraphs.SimpleDiGraph(nvertices)

    metadata = Dict{Union{Int,LightGraphs.AbstractEdge},Dict{Symbol,<:Any}}()

    return InfrastructureGraph{LightGraphs.SimpleDiGraph}(graph, metadata)
end
