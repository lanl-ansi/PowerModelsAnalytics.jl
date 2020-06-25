"""
    `apply_plot_network_metadata!(graph; kwargs...)`

    Builds metadata properties, i.e. color/size of nodes/edges, for plotting based on graph metadata

    Arguments:

    `graph::InfrastructureGraph`: Graph of power network
    `colors::Dict{String,<:Colors.Colorant}`: Dictionary of colors to be changed from `default_colors`
    `load_color_range::Vector{<:Colors.Colorant}`: Range of colors for load statuses
    `node_size_limitss::Vector{<:Real}`: Min/Max values for the size of nodes
    `edge_width_limits::Vector{<:Real}`: Min/Max values for the width of edges
"""
function apply_plot_network_metadata!(graph::InfrastructureGraph{T};
    colors::Dict{String,<:Colors.Colorant}=default_colors,
    color_range::Vector{<:Colors.AbstractRGB}=default_color_range,
    node_size_limits::Vector{<:Real}=default_node_size_limits,
    edge_width_limits::Vector{<:Real}=default_edge_width_limits
    ) where T <: LightGraphs.AbstractGraph

    colors = merge(default_colors, colors)

    for edge in edges(graph)
        set_property!(graph, edge, :edge_color, colors[get_property(graph, edge, :edge_membership, "enabled closed fixed edge")])
        set_property!(graph, edge, :edge_size, get_property(graph, edge, :switch, false) ? 2 : 1)
    end

    for node in vertices(graph)
        node_membership = get_property(graph, node, :node_membership, "enabled node wo demand")
        set_property!(graph, node, :node_color, colors[node_membership])
        set_property!(graph, node, :node_size, node_size_limits[1])
        if hasprop(graph, node, :size)
            set_property!(graph, node, :node_size, get_property(graph, node, :size, 0.0))
        elseif hasprop(graph, node, :active_power)
            active_powers = [(node, get_property(graph, node, :active_power, 0.0)) for node in vertices(graph) if hasprop(graph, node, :active_power)]
            reactive_powers = [(node, get_property(graph, node, :reactive_power, 0.0)) for node in vertices(graph) if hasprop(graph, node, :reactive_power)]
            pmin, pmax = length(active_powers) > 0 ? minimum(filter(!isnan,Float64[v[2] for v in active_powers])) : 0.0, length(active_powers) > 0 ? maximum(filter(!isnan,Float64[v[2] for v in active_powers])) : 0.0
            qmin, qmax = length(reactive_powers) > 0 ? minimum(filter(!isnan,Float64[v[2] for v in reactive_powers])) : 0.0, length(reactive_powers) > 0 ? maximum(filter(!isnan,Float64[v[2] for v in reactive_powers])) : 0.0
            if any(abs.([pmin, pmax, qmin, qmax]) .> 0)
                    amin, amax = minimum(filter(!isnan,Float64[pmin, qmin])), maximum(filter(!isnan,Float64[pmax, qmax]))
                for (node, value) in active_powers
                    set_property!(graph, node, :node_size, (value - amin) / (amax - amin) * (node_size_limits[2] - node_size_limits[1]) + node_size_limits[1])
                end
            end
        end

        if hasprop(graph, node, :load_status)
            load_status = get_property(graph, node, :load_status, 11)
            set_property!(graph, node, :node_color, occursin("disabled", node_membership) || occursin("wo demand", node_membership) ? colors[node_membership] : color_range[load_status])
        end
    end

    node_sizes = [get_property(graph, node, :node_size, 0.0) for node in vertices(graph)]
    for node in vertices(graph)
        set_property!(graph, node, :node_size, (get_property(graph, node, :node_size, 0.0)-minimum(node_sizes)) / (maximum(node_sizes) - minimum(node_sizes)) * (node_size_limits[2] - node_size_limits[1]) + node_size_limits[1])
    end
end


"""
    `graph = build_power_network_graph(case::Dict{String,<:Any}; kwargs...)`

    Builds a `InfrastructureGraph` from a power network `case`.

    Arguments:

    `case::Dict{String,<:Any}`: Network case
    `edge_types::Vector{<:String}`: Component types that are edges
    `block_connector_types::Vector{<:String}`: Types of edges that connect blocks (only used when `block_graph==true`)
    `node_objects::Dict{String,<:Dict{String,<:String}}`: Other non-bus components to include in the graph
    `block_graph::Bool`: If `true`, return block graph
    `aggregate_node_objects::Bool`: If `true`, if multiple node objects present at a bus, aggregate into a single vertex
    `exclusions::Vector{Any}`: Pattern for exclusion from graph

    Returns:

    `graph`: InfrastructureGraph
"""
function build_network_graph(case::Dict{String,<:Any};
    node_settings::Dict{String,<:Any}=default_node_settings_math,
    edge_settings::Dict{String,<:Any}=default_edge_settings_math,
    extra_nodes::Dict{String,<:Any}=default_extra_nodes_math,
    aggregate_extra_nodes::Bool=false,
    sources::Dict{String,<:Any}=default_sources_math,
    demands::Dict{String,<:Any}=default_demands_math,
    block_graph::Bool=false,
    block_connectors::Dict{String,<:Any}=default_block_connectors,
    exclusions::Dict{String,<:Vector{<:Any}}=Dict{String,Vector{Any}}(),
    kwargs...)::InfrastructureGraph

    if Int(get(case, "data_model", 1)) == 0
        if node_settings == default_node_settings_math
            node_settings = default_node_settings_eng
        end

        if edge_settings == default_edge_settings_math
            edge_settings = default_edge_settings_eng
        end

        if extra_nodes == default_extra_nodes_math
            extra_nodes = default_extra_nodes_eng
        end

        if sources == default_sources_math
            sources = default_sources_eng
        end

        if demands == default_demands_math
            demands = default_demands_eng
        end
    end

    node_key = get(node_settings, "node", "bus")
    node_x_key = get(node_settings, "x", "")
    node_y_key = get(node_settings, "y", "")
    (disabled_node_key, disabled_node_value) = get(node_settings, "disabled", "bus_type" => 4)

    if block_graph
        _case = deepcopy(case)
        for (type, settings) in block_connectors
            if haskey(_case, type)
                for (_,obj) in _case[type]
                    (k, v) = get(settings, "disabled", "status" => 0)
                    obj[k] = v
                end
            end
        end

        blocks = identify_blocks(_case)
        node2graph_map = Dict{Any,Int}(node_id => block_id for (block_id, block) in blocks for node_id in block)
    else
        blocks = identify_blocks(case)
        node2graph_map = Dict{Any,Int}(id => i for (i, (id,_)) in enumerate(case[node_key]))
    end

    n_nodes = block_graph ? length(blocks) : length(node2graph_map)
    n_extra_nodes = sum(Int[length(get(case, type, Dict())) for type in keys(extra_nodes)])

    # Generate blank graph
    graph = InfrastructureGraph(n_nodes + n_extra_nodes)

    extra_node2graph_map = Dict{String,Dict{Any,Int}}(type => Dict{Any,Int}() for type in keys(extra_nodes))
    n = n_nodes
    for (type,_) in extra_nodes
        for (id,_) in get(case, type, Dict())
            extra_node2graph_map[type][id] = n + 1
            n += 1
        end
    end

    # Add edges
    if block_graph
        edge_settings = block_connectors
    end

    for (type,settings) in edge_settings
        f_key = get(settings, "fr_node", "f_bus")
        t_key = get(settings, "to_node", "t_bus")
        nodes_key = get(settings, "nodes", "")
        (disabled_key, disabled_value) = get(settings, "disabled", "status" => 0)
        (open_key, open_value) = get(settings, "open", "state" => 0)
        (fixed_key, fixed_value) = get(settings, "fixed", "dispatchable" => 0)

        for (id,edge) in get(case, type, Dict())
            disabled = Int(get(edge, disabled_key, 1)) == disabled_value ? "disabled" : "enabled"
            open = Int(get(edge, open_key, 1)) == open_value ? "open" : "closed"
            fixed = Int(get(edge, fixed_key, 1)) == fixed_value ? "fixed" : "free"

            edge_props = Dict{Symbol,Any}(
                :label => id,
                :type => type,
                :edge_membership => "$disabled $open $fixed edge",
            )

            if !isempty(nodes_key) && haskey(edge, nodes_key)
                edges_set = Set{Any}()
                for f_node in edge[nodes_key]
                    for t_node in edge[nodes_key]
                        if f_node != t_node
                            push!(edges_set, Set{Any}([f_node, t_node]))
                        end
                    end
                end
            else
                edges_set = Set{Any}([Set([edge[f_key], edge[t_key]])])
            end

            for (f_node, t_node) in edges_set
                add_edge!(graph, node2graph_map["$f_node"], node2graph_map["$t_node"])
                set_properties!(graph, LightGraphs.Edge(node2graph_map["$f_node"], node2graph_map["$t_node"]), edge_props)
            end
        end
    end

    for (type, settings) in extra_nodes
        extra_node_key = get(settings, "node", "bus")
        @warn type settings extra_node_key
        (disabled_key, disabled_value) = get(settings, "disabled", "status" => 0)
        (inactive_real_key, inactive_real_value) = get(settings, "inactive_real", "" => 0)
        (inactive_imaginary_key, inactive_imaginary_value) = get(settings, "inactive_imaginary", "" => 0)

        for (id, obj) in get(case, type, Dict())
            f_vert = node2graph_map["$(obj[extra_node_key])"]
            t_vert = extra_node2graph_map[type][id]

            add_edge!(graph, f_vert, t_vert)
            edge_props = Dict{Symbol,Any}(
                :label => "",
                :edge_membership => "connector",
            )
            set_properties!(graph, LightGraphs.Edge(f_vert, t_vert), edge_props)

            disabled = Int(get(obj, disabled_key, 1)) == disabled_value ? "disabled" : "enabled"

            real_inactive = !isempty(inactive_real_key) && haskey(obj, inactive_real_key) && all(obj[inactive_real_key] .== inactive_real_value)
            imaginary_inactive = !isempty(inactive_imaginary_key) && haskey(obj, inactive_imaginary_key) && all(obj[inactive_imaginary_key] .== inactive_imaginary_value)

            inactive = real_inactive && imaginary_inactive ? "inactive" : "active"

            node_membership = "$disabled $inactive extra node"

            node_props = Dict{Symbol,Any}(
                :label => get(settings, "label", id),
                :node_membership => node_membership,
                :force_label => !isempty(get(settings, "label", ""))
            )

            if haskey(settings, "size")
                node_props[:size] = sum(get(obj, settings["size"], 0.0))
            end

            set_properties!(graph, t_vert, node_props)
        end
    end

    # Adds node coordinates if present
    if !block_graph && !isempty(node_x_key) && !isempty(node_y_key)
        for (node, vert) in node2graph_map
            obj = case[node_key][node]
            if haskey(obj, node_x_key) && haskey(obj, node_y_key)
                set_property!(graph, vert, :coordinate, [obj[node_x_key], obj[node_y_key]])
            end
        end
    end

    active_blocks = Dict{Int,Bool}(id => is_active(case, block) for (id,block) in blocks)
    node_has_demand = Dict{Any,Bool}(obj[get(settings, "node", "bus")] => true for (type, settings) in demands for (_,obj) in get(case, type, Dict()))
    block2node_map = block_graph ? Dict{Int,Any}(id => [id] for (id,block) in blocks) : blocks

    for (block_id, block) in blocks
        if block_graph
            disabled = "disabled"
            has_demand = "wo demand"
            for node_id in block
                disabled = Int(case[node_key][node_id][disabled_node_key]) != disabled_node_value ? "enabled" : disabled
                has_demand = get(node_has_demand, node_id, false) ? "w demand" : has_demand
            end
            node_membership = "$disabled node $has_demand"
            node_props = Dict{Symbol,Any}(
                :label => block_id,
                :node_membership => node_membership,
                :active => active_blocks[block_id],
            )
            set_properties!(graph, block_id, node_props)
        else
            for node_id in block
                disabled = Int(case[node_key][node_id][disabled_node_key]) == disabled_node_value ? "disabled" : "enabled"
                has_demand = get(node_has_demand, node_id, false) ? "w demand" : "wo demand"
                node_membership = "$disabled node $has_demand"
                node_props = Dict{Symbol,Any}(
                    :label => node_id,
                    :node_membership => node_membership,
                    :active => active_blocks[block_id]
                )
                set_properties!(graph, node2graph_map[node_id], node_props)
            end
        end
    end

    node_demand_status = Dict{Any,Vector{Real}}(obj[get(settings, "node", "bus")] => Vector{Real}() for (type,settings) in demands for (_,obj) in get(case, type, Dict()))
    for (type, settings) in demands
        demand_node_key = get(settings, "node", "bus")
        demand_status_key = get(settings, "status", "status")

        for (_,obj) in get(case, type, Dict())
            demand_status = get(obj, demand_status_key, 0)
            push!(node_demand_status[obj[demand_node_key]], isa(demand_status, Enum) ? Int(demand_status) : demand_status)
        end
        node_demand_status = Dict{Any,Real}(id => sum(v) / length(v) for (id, v) in node_demand_status if !isempty(v))

        if block_graph
            node_demand_status = Dict{Int,Real}(block_id => sum([get(node_demand_status, node, 0.0) for node in block]) for (block_id, block) in blocks)
        end

        for (id, status) in node_demand_status
            node_props = Dict{Symbol,Any}(
                :demand_status => trunc(Int, status * 10) + 1  # TODO: make generic
            )
            if block_graph
                set_properties!(graph, id, node_props)
            else
                set_properties!(graph, node2graph_map["$id"], node_props)
            end
        end
    end

    return graph
end
