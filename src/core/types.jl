"""
"""
mutable struct PowerModelsGraph{T<:LightGraphs.AbstractGraph}
    graph::LightGraphs.AbstractGraph

    metadata::Dict{Union{Int,LightGraphs.AbstractEdge},Dict{Symbol,<:Any}}
end


function PowerModelsSimpleGraph(vertices::Int)
    graph = LightGraphs.SimpleGraph(vertices)

    metadata = Dict{Union{Int,LightGraphs.AbstractEdge},Dict{Symbol,<:Any}}()

    return PowerModelsGraph{LightGraphs.SimpleGraph}(graph, metadata)
end
