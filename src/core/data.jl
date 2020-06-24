"converts nan values to 0.0"
_convert_nan(x) = isnan(x) ? 0.0 : x
_replace_nan(v) = map(x -> isnan(x) ? zero(x) : x, v)


"Returns true if PowerModelsGraph `graph` has a `property` on an edge or a node `obj`"
function hasprop(graph::PowerModelsGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, property::Symbol) where T <: LightGraphs.AbstractGraph
    if haskey(graph.metadata, obj)
        return haskey(graph.metadata[obj], property)
    else
        return false
    end
end


"Sets a `property` in the metadata at `key` of `graph` on `obj`"
function set_property!(graph::PowerModelsGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol, property::Any) where T <: LightGraphs.AbstractGraph
    if !haskey(graph.metadata, obj)
        graph.metadata[obj] = Dict{Symbol,Any}()
    end

    graph.metadata[obj][key] = property
end


"Sets multiple `properties` in the metadata of `graph` on `obj` at `key`"
function set_properties!(graph::PowerModelsGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, properties::Dict{Symbol,<:Any}) where T <: LightGraphs.AbstractGraph
    if !haskey(graph.metadata, obj)
        graph.metadata[obj] = Dict{Symbol,Any}()
    end

    merge!(graph.metadata[obj], properties)
end


"Gets the property in the metadata of `graph` on `obj` at `key`. If property doesn't exist, returns `default`"
function get_property(graph::PowerModelsGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol, default::Any) where T <: LightGraphs.AbstractGraph
    return get(get(graph.metadata, obj, Dict{Symbol,Any}()), key, default)
end


"Adds an edge defined by `i` & `j` to `graph`"
function add_edge!(graph::PowerModelsGraph{T}, i::Int, j::Int) where T <: LightGraphs.AbstractGraph
    LightGraphs.add_edge!(graph.graph, i, j)
end


"Returns an iterator of all of the nodes/vertices in `graph`"
function vertices(graph::PowerModelsGraph{T}) where T <: LightGraphs.AbstractGraph
    return LightGraphs.vertices(graph.graph)
end


"Returns an iterator of all the edges in `graph`"
function edges(graph::PowerModelsGraph{T}) where T <: LightGraphs.AbstractGraph
    return LightGraphs.edges(graph.graph)
end


"Returns all of the metadata for `obj` in `graph`"
function properties(graph::PowerModelsGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}) where T <: LightGraphs.AbstractGraph
    return get(graph.metadata, obj)
end


""
function identify_blocks(case::Dict{String,<:Any})::Dict{Int,Set{Any}}
    cc = calc_connected_components(case)

    return Dict{Int,Set{Any}}(i => s for (i,s) in enumerate(cc))
end


""
function calc_connected_components(data::Dict{String,<:Any}; edges=["line", "transformer", "switch"])::Set{Set{Any}}
    active_bus = Dict{Any,Dict{String,Any}}(x for x in data["bus"] if Int(x.second["status"]) == 1)
    active_bus_ids = Set{Any}([i for (i,bus) in active_bus])

    neighbors = Dict{Any,Vector{Any}}(i => [] for i in active_bus_ids)
    for edge_type in edges
        for (id, edge_obj) in get(data, edge_type, Dict{Any,Dict{String,Any}}())
            if edge_type == "switch"
                status = Int(edge_obj["status"]) == 1 && Int(edge_obj["state"]) == 1
                if status
                    push!(neighbors[edge_obj["f_bus"]], edge_obj["t_bus"])
                    push!(neighbors[edge_obj["t_bus"]], edge_obj["f_bus"])
                end
            else
                status = Int(edge_obj["status"]) == 1
                if status
                    if edge_type == "line" || (edge_type == "transformer" && haskey(edge_obj, "f_bus") && haskey(edge_obj, "t_bus"))
                        push!(neighbors[edge_obj["f_bus"]], edge_obj["t_bus"])
                        push!(neighbors[edge_obj["t_bus"]], edge_obj["f_bus"])
                    else
                        for f_bus in edge_obj["bus"]
                            for t_bus in edge_obj["bus"]
                                if f_bus != t_bus
                                    push!(neighbors[f_bus], t_bus)
                                    push!(neighbors[t_bus], f_bus)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    component_lookup = Dict(i => Set{Any}([i]) for i in active_bus_ids)
    touched = Set{Any}()

    for i in active_bus_ids
        if !(i in touched)
            PowerModels._cc_dfs(i, neighbors, component_lookup, touched)
        end
    end

    ccs = (Set(values(component_lookup)))

    return ccs
end


""
function is_energized(case::Dict{String,<:Any}, block::Set{<:Any})::Bool
    for bus in block
        for gen_type in ["voltage_source", "generator", "solar", "storage"]
            for (_,obj) in get(case, gen_type, Dict{Any,Dict{String,Any}}())
                if bus == obj["bus"] && Int(obj["status"]) == 1
                    return true
                end
            end
        end
    end
    return false
end
