"converts nan values to 0.0"
_convert_nan(x) = isnan(x) ? 0.0 : x
_replace_nan(v) = map(x -> isnan(x) ? zero(x) : x, v)


""
function hasprop(graph::PowerModelsGraph, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol)
    if haskey(graph.metadata, obj)
        return haskey(graph.metadata[obj], key)
    else
        return false
    end
end


""
function set_property!(graph::PowerModelsGraph, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol, property::Any)
    if !haskey(graph.metadata, obj)
        graph.metadata[obj] = Dict{Symbol,<:Any}()
    end

    graph.metadata[obj][key] = property
end


""
function set_properties!(graph::PowerModelsGraph, obj::Union{Int,LightGraphs.AbstractEdge}, properties::Dict{Symbol,<:Any})
    if !haskey(graph.metadata, obj)
        graph.metadata[obj] = Dict{Symbol,<:Any}()
    end

    merge!(graph.metadata[obj], properties)
end


""
function get_property(graph::PowerModelsGraph, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol, default::Any)
    return get(get(graph.metadata, obj, Dict{Symbol,<:Any}()), key, default)
end
