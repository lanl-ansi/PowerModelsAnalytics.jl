"""
"""
mutable struct PowerModelsGraph{T<:LightGraphs.AbstractGraph}
    graph::LightGraphs.AbstractGraph

    metadata::Dict{Union{Int,LightGraphs.AbstractEdge},Dict{Symbol,<:Any}}
end


function PowerModelsGraph(vertices::Int)
    graph = LightGraphs.SimpleDiGraph(vertices)

    metadata = Dict{Union{Int,LightGraphs.AbstractEdge},Dict{Symbol,<:Any}}()

    return PowerModelsGraph{LightGraphs.SimpleDiGraph}(graph, metadata)
end