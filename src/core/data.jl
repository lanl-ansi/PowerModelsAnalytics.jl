"converts nan values to 0.0"
_convert_nan(x) = isnan(x) ? 0.0 : x
_replace_nan(v) = map(x -> isnan(x) ? zero(x) : x, v)


"Returns true if InfrastructureGraph `graph` has a `property` on an edge or a node `obj`"
function hasprop(graph::InfrastructureGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, property::Symbol) where T <: LightGraphs.AbstractGraph
    if haskey(graph.metadata, obj)
        return haskey(graph.metadata[obj], property)
    else
        return false
    end
end


"Sets a `property` in the metadata at `key` of `graph` on `obj`"
function set_property!(graph::InfrastructureGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol, property::Any) where T <: LightGraphs.AbstractGraph
    if !haskey(graph.metadata, obj)
        graph.metadata[obj] = Dict{Symbol,Any}()
    end

    graph.metadata[obj][key] = property
end


"Sets multiple `properties` in the metadata of `graph` on `obj` at `key`"
function set_properties!(graph::InfrastructureGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, properties::Dict{Symbol,<:Any}) where T <: LightGraphs.AbstractGraph
    if !haskey(graph.metadata, obj)
        graph.metadata[obj] = Dict{Symbol,Any}()
    end

    merge!(graph.metadata[obj], properties)
end


"Gets the property in the metadata of `graph` on `obj` at `key`. If property doesn't exist, returns `default`"
function get_property(graph::InfrastructureGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}, key::Symbol, default::Any) where T <: LightGraphs.AbstractGraph
    return get(get(graph.metadata, obj, Dict{Symbol,Any}()), key, default)
end


"Adds an edge defined by `i` & `j` to `graph`"
function add_edge!(graph::InfrastructureGraph{T}, i::Int, j::Int) where T <: LightGraphs.AbstractGraph
    LightGraphs.add_edge!(graph.graph, i, j)
end


"Returns an iterator of all of the nodes/vertices in `graph`"
function vertices(graph::InfrastructureGraph{T}) where T <: LightGraphs.AbstractGraph
    return LightGraphs.vertices(graph.graph)
end


"Returns an iterator of all the edges in `graph`"
function edges(graph::InfrastructureGraph{T}) where T <: LightGraphs.AbstractGraph
    return LightGraphs.edges(graph.graph)
end


"Returns all of the metadata for `obj` in `graph`"
function properties(graph::InfrastructureGraph{T}, obj::Union{Int,LightGraphs.AbstractEdge}) where T <: LightGraphs.AbstractGraph
    return get(graph.metadata, obj)
end


""
function identify_blocks(case::Dict{String,<:Any}; node_settings::Dict{String,<:Any}=default_node_settings_math, edge_settings::Dict{String,<:Any}=default_edge_settings_math)::Dict{Int,Set{Any}}
    cc = calc_connected_components(case; node_settings=node_settings, edge_settings=edge_settings)

    return Dict{Int,Set{Any}}(i => s for (i,s) in enumerate(cc))
end


""
function calc_connected_components(data::Dict{String,<:Any}; node_settings::Dict{String,<:Any}=default_node_settings_math, edge_settings::Dict{String,<:Any}=default_edge_settings_math)::Set{Set{Any}}
    if Int(get(data, "data_model", 1)) == 0
        if node_settings == default_node_settings_math
            node_settings = default_node_settings_eng
        end

        if edge_settings == default_edge_settings_math
            edge_settings = default_edge_settings_eng
        end
    end

    active_node = Dict{Any,Dict{String,Any}}(x for x in data[get(node_settings, "node", "bus")] if Int(x.second[get(node_settings, "disabled", "bus_type" => 4)[1]]) != get(node_settings, "disabled", "bus_type" => 4))
    active_node_ids = Set{Any}([i for (i,node) in active_node])

    neighbors = Dict{Any,Vector{Any}}(i => [] for i in active_node_ids)
    for (type, settings) in edge_settings
        for (id, obj) in get(data, type, Dict{Any,Dict{String,Any}}())
            (disabled_key, disabled_value) = get(settings, "disabled", "status" => 0)
            (open_key, open_value) = get(settings, "open", "state" => 0)

            f_key = get(settings, "fr_node", "f_bus")
            t_key = get(settings, "to_node", "t_bus")
            nodes_key = get(settings, "nodes", "")

            status = Int(get(obj, disabled_key, 1)) != disabled_value && Int(get(obj, open_key, 1)) != open_value

            if status
                if !isempty(nodes_key) && haskey(obj, nodes_key)
                    edges_set = Set{Any}()
                    for f_node in obj[nodes_key]
                        for t_node in obj[nodes_key]
                            if f_node != t_node
                                push!(edges_set, Set([f_node, t_node]))
                            end
                        end
                    end

                    for (f_node, t_node) in edges_set
                        push!(neighbors["$f_node"], "$t_node")
                        push!(neighbors["$t_node"], "$f_node")
                    end
                else
                    push!(neighbors["$(obj[f_key])"], "$(obj[t_key])")
                    push!(neighbors["$(obj[t_key])"], "$(obj[f_key])")
                end
            end
        end
    end

    component_lookup = Dict(i => Set{Any}([i]) for i in active_node_ids)
    touched = Set{Any}()

    for i in active_node_ids
        if !(i in touched)
            _cc_dfs(i, neighbors, component_lookup, touched)
        end
    end

    ccs = (Set(values(component_lookup)))

    return ccs
end


"DFS on a graph"
function _cc_dfs(i, neighbors, component_lookup, touched)
    push!(touched, i)
    for j in neighbors[i]
        if !(j in touched)
            for k in  component_lookup[j]
                push!(component_lookup[i], k)
            end
            for k in component_lookup[j]
                component_lookup[k] = component_lookup[i]
            end
            _cc_dfs(j, neighbors, component_lookup, touched)
        end
    end
end


"""
    `ans = is_active`

    Determines if block is "active", e.g. energized, based on criteria in `sources`

    Arguements:

    `case::Dict{String,<:Any}`: Network case
    `block::Set{<:Any}`: block of node ids
    `sources::Dict{String,<:Dict{String,<:Any}}`: sources with settings that define criteria for active

    Returns:

    `ans::Bool`
"""
function is_active(case::Dict{String,<:Any}, block::Set{<:Any}; sources::Dict{String,<:Any}=default_sources_math)::Bool
    if Int(get(case, "data_model", 1)) == 0 && sources == default_sources_math
        sources = default_sources_eng
    end

    for node in block
        for (type,settings) in sources
            node_key = get(settings, "node", "bus")

            (disabled_key, disabled_value) = get(settings, "disabled", "status" => 0)
            (inactive_real_key, inactive_real_value) = get(settings, "inactive_real", "" => 0)
            (inactive_imaginary_key, inactive_imaginary_value) = get(settings, "inactive_imaginary", "" => 0)

            for (_,obj) in get(case, type, Dict{Any,Dict{String,Any}}())
                if node == obj[node_key] && Int(obj[disabled_key]) != disabled_value
                    if (!isempty(inactive_real_key) && haskey(obj, inactive_real_key) && any(obj[inactive_real_key] .!= inactive_real_value)) || (!isempty(inactive_imaginary_key) && haskey(obj, inactive_imaginary_key) && any(obj[inactive_imaginary_key] .!= inactive_imaginary_value))
                        return true
                    end
                end
            end
        end
    end
    return false
end
