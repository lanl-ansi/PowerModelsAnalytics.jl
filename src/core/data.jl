"converts nan values to 0.0"
_convert_nan(x) = isnan(x) ? 0.0 : x
_replace_nan(v) = map(x -> isnan(x) ? zero(x) : x, v)


""
function hasprop(graph::PowerModelsGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol) where T <: LightGraphs.AbstractGraph
    if haskey(graph.metadata, obj)
        return haskey(graph.metadata[obj], key)
    else
        return false
    end
end


""
function set_property!(graph::PowerModelsGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol, property::Any) where T <: LightGraphs.AbstractGraph
    if !haskey(graph.metadata, obj)
        graph.metadata[obj] = Dict{Symbol,Any}()
    end

    graph.metadata[obj][key] = property
end


""
function set_properties!(graph::PowerModelsGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, properties::Dict{Symbol,<:Any}) where T <: LightGraphs.AbstractGraph
    if !haskey(graph.metadata, obj)
        graph.metadata[obj] = Dict{Symbol,Any}()
    end

    merge!(graph.metadata[obj], properties)
end


""
function get_property(graph::PowerModelsGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol, default::Any) where T <: LightGraphs.AbstractGraph
    return get(get(graph.metadata, obj, Dict{Symbol,Any}()), key, default)
end


""
function add_edge!(graph::PowerModelsGraph{T}, i::Int, j::Int) where T <: LightGraphs.AbstractGraph
    LightGraphs.add_edge!(graph.graph, i, j)
end


""
function vertices(graph::PowerModelsGraph{T}) where T <: LightGraphs.AbstractGraph
    return LightGraphs.vertices(graph.graph)
end


""
function edges(graph::PowerModelsGraph{T}) where T <: LightGraphs.AbstractGraph
    return LightGraphs.edges(graph.graph)
end


""
function properties(graph::PowerModelsGraph{T}, node::Int) where T <: LightGraphs.AbstractGraph
    return get(graph.metadata, node)
end
