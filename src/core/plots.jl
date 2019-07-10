default_colors = Dict{String,Colors.Colorant}("open switch" => colorant"yellow",
                                              "closed switch" => colorant"green",
                                              "fixed open switch" => colorant"red",
                                              "fixed closed switch" => colorant"blue",
                                              "enabled line" => colorant"black",
                                              "disabled line" => colorant"orange",
                                              "energized bus" => colorant"green",
                                              "energized generator" => colorant"cyan",
                                              "energized synchronous condenser" => colorant"yellow",
                                              "enabled generator" => colorant"orange",
                                              "disabled generator" => colorant"red",
                                              "unloaded enabled bus" => colorant"darkgrey",
                                              "unloaded disabled bus" => colorant"grey95",
                                              "loaded disabled bus" => colorant"gold",
                                              "loaded enabled bus" => colorant"green3",
                                              "connector" => colorant"lightgrey")

"converts nan values to 0.0"
convert_nan(x) = isnan(x) ? 0.0 : x


""
function plot_branch_impedance(data::Dict{String,Any})
    r = [branch["br_r"] for (i,branch) in data["branch"]]
    x = [branch["br_x"] for (i,branch) in data["branch"]]

    s = Plots.scatter(r, x, xlabel="resistance (p.u.)", ylabel="reactance (p.u.)", label="")
    r_h = Plots.histogram(r, xlabel="resistance (p.u.)", ylabel="branch count", label="", reuse=false)
    x_h = Plots.histogram(x, xlabel="reactance (p.u.)", ylabel="branch count", label="", reuse=false)
end


"""
    plot_network(network, backend; kwargs...)

Plots a whole `network` at the bus-level to `backend`. Returns `MetaGraph` and `positions`.

kwargs
------
    nodel_label::Bool
        Plot labels on nodes (Default: false)
    edge_label::Bool
        Plot labels on edges (Default: false)
    colors::Dict{String,Colors.Colorant}
        Changes to default colors, see `default_colors` for available components. (Default: Dict())
    edge_types::Array{String}
        Types of edges (Default: ["branch", "dcline", "trans"])
    gen_types::Dict{String,Dict{String,String}}
        Defines the types of generator components, e.g. gen and storage, in the format
        Dict("gen_type"=>Dict("active"=>"active power field", "reactive"=>"reactive power field, "status"=>"status field))
    exclude_gens::Array{String}
        Names of generators to exclude
    switch::String
        Field that identifies an edge_type as a switch (Default: "swtichable")
    buscoords::Bool
        Use buscoord field on buses for node positions (Default: false)
    spring_const::Float64
        Only used if buscoords=true. Spring constant to be used to force-direct-layout buses with no buscoord field
    positions::Array{Float64, 2}
        Used to specify node locations of graph (avoids running layout algorithm every time)
"""
function plot_network(network::Dict{String,Any}, backend::Compose.Backend;
                        node_label::Bool=false,
                        edge_label::Bool=false,
                        colors::Dict=Dict(),
                        edge_types::Array{String}=["branch", "dcline", "trans"],
                        gen_types::Dict{String,Dict{String,String}}=Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"),
                                                                         "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status")),
                        exclude_gens::Union{Nothing,Array{String}}=nothing,
                        switch::String="switchable",
                        buscoords::Bool=false,
                        spring_const::Float64=1e-3,
                        positions::Union{Nothing,Array}=nothing,
                        node_size_limits=[1, 2.5],
                        fontsize=12)

    colors = merge(default_colors, colors)
    load_color_range = Colors.range(colors["loaded disabled bus"], colors["loaded enabled bus"], length=11)

    connected_buses = Set(edge[k] for k in ["f_bus", "t_bus"] for edge_type in edge_types for edge in values(get(network, edge_type, Dict())))
    gens = [(gen_type, gen) for gen_type in keys(gen_types) for gen in values(get(network, gen_type, Dict()))]
    n_buses = length(connected_buses)
    n_gens = length(gens)

    graph = MetaGraphs.MetaGraph(n_buses + n_gens)
    bus_graph_map = Dict(bus["bus_i"] => i for (i, bus) in enumerate(values(get(network, "bus", Dict()))))
    gen_graph_map = Dict("$(gen_type)_$(gen["index"])" => i for (i, (gen_type, gen)) in zip(n_buses+1:n_buses+n_gens, gens))

    graph_bus_map = Dict(v => k for (k, v) in bus_graph_map)
    graph_gen_map = Dict(v => k for (k, v) in gen_graph_map)
    graph_map = merge(graph_bus_map, graph_gen_map)

    for edge_type in edge_types
        for edge in values(get(network, edge_type, Dict()))
            MetaGraphs.add_edge!(graph, bus_graph_map[edge["f_bus"]], bus_graph_map[edge["t_bus"]])

            switch = get(edge, switch, false)
            fixed = get(edge, "fixed", false)
            status = Bool(get(edge, "br_status", 1))

            edge_membership = switch && status && !fixed ? "closed switch" : switch && !status && !fixed ? "open switch" : switch && status && fixed ? "fixed closed switch" : switch && !status && fixed ? "fixed open switch" : !switch && status ? "enabled line" : "disabled line"
            props = Dict(:i => edge["index"],
                        :switch => switch,
                        :status => status,
                        :fixed => fixed,
                        :label => edge_label ? edge["index"] : "",
                        :edge_membership => edge_membership,
                        :edge_color => colors[edge_membership])
            MetaGraphs.set_props!(graph, MetaGraphs.Edge(bus_graph_map[edge["f_bus"]], bus_graph_map[edge["t_bus"]]), props)
        end
    end

    # Add Generator Nodes
    for (gen_type, keymap) in gen_types
        for gen in values(get(network, gen_type, Dict()))
            MetaGraphs.add_edge!(graph, gen_graph_map["$(gen_type)_$(gen["index"])"], bus_graph_map[gen["$(gen_type)_bus"]])
            is_condenser = all(get(gen, get(keymap, "active_max", "pmax"), 0.0) .== 0) && all(get(gen, get(keymap, "active_min", "pmin"), 0.0) .== 0)
            node_membership = get(gen, get(keymap, "status", "gen_status"), 1) == 0 ? "disabled generator" : any(get(gen, get(keymap, "active", "pg"), 0.0) .> 0) ? "energized generator" : is_condenser || (all(get(gen, get(keymap, "active", "pg"), 0.0) .== 0) && any(get(gen, get(keymap, "reactive", "qg"), 0.0) .> 0)) ? "energized synchronous condenser" : "enabled generator"
            label = gen_type == "storage" ? "S" : occursin("condenser", node_membership) ? "C" : "~"
            node_props = Dict(:label => label,
                              :energized => get(gen, get(keymap, "status", "gen_status"), 1) > 0 && (any(get(gen, get(keymap, "active", "pg"), 0.0) .> 0) || any(get(gen, get(keymap, "reactive", "qg"), 0.0) .> 0)) ? true : false,
                              :active_power => convert_nan(sum(get(gen, get(keymap, "active", "pg"), 0.0))),
                              :reactive_power => convert_nan(sum(get(gen, get(keymap, "reactive", "qg"), 0.0))),
                              :node_membership => node_membership,
                              :node_color => colors[node_membership])
            MetaGraphs.set_props!(graph, gen_graph_map["$(gen_type)_$(gen["index"])"], node_props)

            edge_props = Dict(:label => "",
                              :switch => false,
                              :edge_membership => "connector",
                              :edge_color => colors["connector"])
            MetaGraphs.set_props!(graph, MetaGraphs.Edge(gen_graph_map["$(gen_type)_$(gen["index"])"], bus_graph_map[gen["$(gen_type)_bus"]]), edge_props)
        end

        # Normalize sizes of generator nodes by served total (active and reactive) power
        active_powers = [(node, MetaGraphs.get_prop(graph, node, :active_power)) for node in MetaGraphs.vertices(graph) if MetaGraphs.has_prop(graph, node, :active_power)]
        reactive_powers = [(node, MetaGraphs.get_prop(graph, node, :reactive_power)) for node in MetaGraphs.vertices(graph) if MetaGraphs.has_prop(graph, node, :reactive_power)]
        pmin, pmax = length(active_powers) > 0 ? minimum(filter(!isnan,Float64[v[2] for v in active_powers])) : 0.0, length(active_powers) > 0 ? maximum(filter(!isnan,Float64[v[2] for v in active_powers])) : 0.0
        qmin, qmax = length(reactive_powers) > 0 ? minimum(filter(!isnan,Float64[v[2] for v in reactive_powers])) : 0.0, length(reactive_powers) > 0 ? maximum(filter(!isnan,Float64[v[2] for v in reactive_powers])) : 0.0
        if any(abs.([pmin, pmax, qmin, qmax]) .> 0)
                amin, amax = minimum(filter(!isnan,Float64[pmin, qmin])), maximum(filter(!isnan,Float64[pmax, qmax]))
            for (node, value) in active_powers
                MetaGraphs.set_prop!(graph, node, :node_size, (value - amin) / (amax - amin) * (node_size_limits[2] - node_size_limits[1]) + node_size_limits[1])
            end
        end
    end

    # Check status of buses in islands (energized?)
    islands = PowerModels.calc_connected_components(network; edges=edge_types)
    for island in islands
        is_energized = any(get(gen, get(keymap, "status", "gen_status"), 1.0) != 0 && (any(get(gen, get(keymap, "active", "pg"), 0.0) .> 0) || any(get(gen, get(keymap, "reactive", "qg"), 0.0) .> 0)) for (gen_type, keymap) in gen_types for gen in values(get(network, gen_type, Dict())) if gen["$(gen_type)_bus"] in island)
        for bus in island
            if bus in connected_buses
                node_membership = get(get(get(network, "bus", Dict()), "$bus", Dict()), "bus_type", 1) == 4 ? "unloaded disabled bus" : "unloaded enabled bus"
                node_props = Dict(:label => node_label ? "$bus" : "",
                                :energized => is_energized,
                                :node_membership => node_membership,
                                :node_color => colors[node_membership])
                MetaGraphs.set_props!(graph, bus_graph_map[bus], node_props)
            end
        end
    end

    # Set color of buses based on mean served load
    for bus in values(get(network, "bus", Dict()))
        loads = [load for load in values(get(network, "load", Dict())) if load["load_bus"] == bus["bus_i"]]
        load_status = length(loads) > 0 ? trunc(Int, round(sum(mean(get(load, "status", 1.0) for load in loads) * 10))) + 1 : 1
        energized = MetaGraphs.get_prop(graph, bus_graph_map[bus["bus_i"]], :energized)
        node_membership = "unloaded disabled bus"
        if any(any(load["pd"] .> 0) for load in loads) || any(any(load["qd"] .> 0) for load in loads)
            if get(bus, "bus_type", 1) == 4 || !energized
                node_membership = "loaded disabled bus"
            elseif get(bus, "bus_type", 1) != 4 && energized
                node_membership = "loaded enabled bus"
            end
        else
            if energized && get(bus, "bus_type", 1) != 4
                node_membership = "unloaded enabled bus"
            end
        end
        node_props = Dict(:node_membership => node_membership,
                          :node_color => occursin("disabled", node_membership) || occursin("unloaded", node_membership) ? colors[node_membership] : load_color_range[load_status])
        MetaGraphs.set_props!(graph, bus_graph_map[bus["bus_i"]], node_props)
    end

    # Debug
    for node in MetaGraphs.vertices(graph)
        @debug node MetaGraphs.props(graph, node)
    end

    # Collect Node properties (color fill, sizes, labels)
    node_fills = [MetaGraphs.get_prop(graph, node, :node_color) for node in MetaGraphs.vertices(graph)]
    node_sizes = [MetaGraphs.has_prop(graph, bus, :node_size) ? sum(MetaGraphs.get_prop(graph, bus, :node_size)) : node_size_limits[1] for bus in MetaGraphs.vertices(graph)]
    node_labels = [MetaGraphs.get_prop(graph, node, :label) for node in MetaGraphs.vertices(graph)]

    # Collect Edge properties (stroke color, edge weights, labels)
    edge_strokes = [MetaGraphs.get_prop(graph, edge, :edge_color) for edge in MetaGraphs.edges(graph)]
    edge_weights = [MetaGraphs.get_prop(graph, edge, :switch) ? 1.0 : 0.25 for edge in MetaGraphs.edges(graph)]
    edge_labels = [MetaGraphs.get_prop(graph, edge, :label) for edge in MetaGraphs.edges(graph)]

    # Graph Layout
    if positions != nothing
        loc_x, loc_y = positions
    else
        # Use buscoords?
        if buscoords
            pos = Dict()
            fixed = []
            for n in MetaGraphs.vertices(graph)
                lookup = graph_map[n]
                if isa(lookup, String)
                    gen_type, i = split(lookup, "_")
                    gen_bus = network[gen_type][i]["$(gen_type)_bus"]
                    pos[n] = get(network["bus"]["$gen_bus"], "buscoord", missing)
                else
                    pos[n] = get(network["bus"]["$lookup"], "buscoord", missing)
                    if haskey(network["bus"]["$lookup"], "buscoord")
                        push!(fixed, n)
                    end
                end
            end
            avg_x, avg_y = mean(hcat(skipmissing([v for v in values(pos)])...), dims=2)
            std_x, std_y = std(hcat(skipmissing([v for v in values(pos)])...), dims=2)
            for (v, p) in pos
                if ismissing(p)
                    pos[v] = [avg_x+std_x*rand(), avg_y+std_y*rand()]
                end
            end
            loc_x, loc_y = spring_layout(graph; pos=pos, fixed=fixed, k=spring_const*minimum(std([p for p in values(pos)])), iterations=100)
        else
            loc_x, loc_y = kamada_kawai_layout(graph)
        end
    end

    # Plot
    Compose.draw(backend, GraphPlot.gplot(graph, loc_x, loc_y, nodelabel=node_labels, edgelabel=edge_labels,
                                            edgestrokec=edge_strokes, edgelinewidth=edge_weights, nodesize=node_sizes,
                                            nodefillc=node_fills, EDGELABELSIZE=4, edgelabeldistx=0.6, edgelabeldisty=0.6))

    # Return graph, positions
    return graph, [loc_x, loc_y]
end


"""
    plot_load_blocks(network, backend; kwargs...)

Plots a power `network` at the load-block-level on `backend`. Returns `MetaGraph` and `positions`.

kwargs
------
    nodel_label::Bool
        Plot labels on nodes (Default: false)
    edge_label::Bool
        Plot labels on edges (Default: false)
    colors::Dict{String,Colors.Colorant}
        Changes to default colors, see `default_colors` for available components. (Default: Dict())
    edge_types::Array{String}
        Types of edges (Default: ["branch", "dcline", "trans"])
    gen_types::Dict{String,Dict{String,String}}
        Defines the types of generator components, e.g. gen and storage, in the format
        Dict("gen_type"=>Dict("active"=>"active power field", "reactive"=>"reactive power field, "status"=>"status field))
    exclude_gens::Array{String}
        Names of generators to exclude
    switch::String
        Field that identifies an edge_type as a switch (Default: "swtichable")
    positions::Array{Float64, 2}
        Used to specify node locations of graph (avoids running layout algorithm every time)
"""
function plot_load_blocks(network::Dict{String,Any}, backend::Compose.Backend;
                            node_label::Bool=false,
                            edge_label::Bool=false,
                            colors::Dict{String,Colors.Colorant}=Dict{String,Colors.Colorant}(),
                            edge_types::Array{String}=["branch", "dcline", "trans"],
                            gen_types::Dict{String,Dict{String,String}}=Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"),
                                                                             "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status")),
                            exclude_gens::Union{Nothing,Array{String}}=nothing,
                            switch::String="switchable",
                            positions::Union{Nothing,Array}=nothing)

    # Setup Colors
    colors = merge(default_colors, colors)
    load_color_range = Colors.range(colors["loaded disabled bus"], colors["loaded enabled bus"], length=11)

    # Create copy of network to determine possible islands
     _network = deepcopy(network)
     for edge_type in edge_types
        for edge in values(get(_network, edge_type, Dict()))
            if get(edge, switch, false)
                edge["br_status"] = 0
            end
        end
    end

    # Build graph maps
    islands = PowerModels.calc_connected_components(_network, edges=edge_types)  # Possible Islands
    connected_islands = PowerModels.calc_connected_components(network, edges=edge_types)  # Actual Islands
    n_islands = length(islands)

    island_graph_map = Dict(island => i for (i, island) in enumerate(islands))
    graph_island_map = Dict(i => island for (island, i) in island_graph_map)
    connected_island_graph_map = Dict(i => connected_island for (island, i) in island_graph_map for bus in island for connected_island in connected_islands if bus in connected_island)
    bus_island_map = Dict(bus => i for (island, i) in island_graph_map for bus in island)

    gens = [(gen_type, gen) for gen_type in keys(gen_types) for gen in values(get(network, gen_type, Dict()))]
    n_gens = length(gens)

    gen_graph_map = Dict("$(gen_type)_$(gen["index"])" => i for (i, (gen_type, gen)) in zip(n_islands+1:n_islands+n_gens, gens))

    # Initialize MetaGraph
    graph = MetaGraphs.MetaGraph(n_islands + n_gens)

    # Add edges (of types in edge_types)
    for edge_type in edge_types
        for line in values(get(network, edge_type, Dict()))
            f_island = bus_island_map[line["f_bus"]]
            t_island = bus_island_map[line["t_bus"]]

            if f_island != t_island
                MetaGraphs.add_edge!(graph, f_island, t_island)

                fixed = Bool(all(get(line, "fixed", false)))
                status = Bool(get(line, "br_status", 1))

                edge_membership = !fixed && status ? "closed switch" : !fixed && !status ? "open switch" : fixed && status ? "fixed closed switch" : "fixed open switch"
                edge_props = Dict(:label => edge_label ? "$(line["index"])" : "",
                                  :switch => true,
                                  :fixed => false,
                                  :i => line["index"],
                                  :edge_membership => edge_membership,
                                  :edge_color => colors[edge_membership])

                MetaGraphs.set_props!(graph, MetaGraphs.Edge(f_island, t_island), edge_props)
            end
        end
    end

    # Add Generators to graph
    for (gen_type, keymap) in gen_types
        for gen in values(get(network, gen_type, Dict()))
            MetaGraphs.add_edge!(graph, gen_graph_map["$(gen_type)_$(gen["index"])"], bus_island_map[gen["$(gen_type)_bus"]])
            is_condenser = all(get(gen, get(keymap, "active_max", "pmax"), 0.0) .== 0) && all(get(gen, get(keymap, "active_min", "pmin"), 0.0) .== 0)
            node_membership = get(gen, get(keymap, "status", "gen_status"), 1) == 0 ? "disabled generator" : any(get(gen, get(keymap, "active", "pg"), 0.0) .> 0) ? "energized generator" : is_condenser || (all(get(gen, get(keymap, "active", "pg"), 0.0) .== 0) && any(get(gen, get(keymap, "reactive", "qg"), 0.0) .> 0)) ? "energized synchronous condenser" : "enabled generator"
            label = gen_type == "storage" ? "S" : occursin("condenser", node_membership) ? "C" : "~"
            node_props = Dict(:label => label,
                              :energized => get(gen, get(keymap, "status", "gen_status"), 1) > 0 && (any(get(gen, get(keymap, "active", "pg"), 0.0) .> 0) || any(get(gen, get(keymap, "reactive", "qg"), 0.0) .> 0)) ? true : false,
                              :active_power => convert_nan(sum(get(gen, get(keymap, "active", "pg"), 0.0))),
                              :reactive_power => convert_nan(sum(get(gen, get(keymap, "reactive", "qg"), 0.0))),
                              :node_membership => node_membership,
                              :node_color => colors[node_membership])
            MetaGraphs.set_props!(graph, gen_graph_map["$(gen_type)_$(gen["index"])"], node_props)

            edge_props = Dict(:label => "",
                              :switch => false,
                              :edge_membership => "connector",
                              :edge_color => colors["connector"])
            MetaGraphs.set_props!(graph, MetaGraphs.Edge(gen_graph_map["$(gen_type)_$(gen["index"])"], bus_island_map[gen["$(gen_type)_bus"]]), edge_props)
        end

        # Normalize node size of generators based on total power served
        active_powers = [(node, MetaGraphs.get_prop(graph, node, :active_power)) for node in MetaGraphs.vertices(graph) if MetaGraphs.has_prop(graph, node, :active_power)]
        reactive_powers = [(node, MetaGraphs.get_prop(graph, node, :reactive_power)) for node in MetaGraphs.vertices(graph) if MetaGraphs.has_prop(graph, node, :reative_power)]
        pmin, pmax = length(active_powers) > 0 ? minimum(filter(!isnan,Float64[v[2] for v in active_powers])) : 0.0, length(active_powers) > 0 ? maximum(filter(!isnan,Float64[v[2] for v in active_powers])) : 0.0
        qmin, qmax = length(reactive_powers) > 0 ? minimum(filter(!isnan,Float64[v[2] for v in reactive_powers])) : 0.0, length(reactive_powers) > 0 ? maximum(filter(!isnan,Float64[v[2] for v in reactive_powers])) : 0.0
        if any(abs.([pmin, pmax, qmin, qmax]) .> 0)
            amin, amax = minimum(filter(!isnan,Float64[pmin, qmin])), maximum(filter(!isnan,Float64[pmax, qmax]))
            for (node, value) in active_powers
                MetaGraphs.set_prop!(graph, node, :node_size, (value - amin) / (amax - amin) * (2.0 - 1.0) + 1.0)
            end
        end
    end

    # Color nodes based on average load served
    for node in MetaGraphs.vertices(graph)
        if !(node in values(gen_graph_map))
            actual_island = connected_island_graph_map[node]
            possible_island = graph_island_map[node]

            loads = [load for load in values(get(network, "load", Dict())) if load["load_bus"] in possible_island]
            load_status = length(loads) > 0 ? trunc(Int, round(sum(mean(get(load, "status", 1.0) for load in loads) * 10))) + 1 : 1

            has_load = length([load for load in loads if get(load, "status", 1.0) > 0]) > 0
            is_energized = any(get(gen, get(keymap, "status", "gen_status"), 1) != 0 && (any(get(gen, get(keymap, "active", "pg"), 0.0) .> 0) || any(get(gen, get(keymap, "reactive", "qg"), 0.0) .> 0)) for (gen_type, keymap) in gen_types for gen in values(get(network, gen_type, Dict())) if gen["$(gen_type)_bus"] in actual_island)

            node_membership = has_load && is_energized ? "loaded enabled bus" : has_load && !is_energized ? "loaded disabled bus" : !has_load && is_energized ? "unloaded enabled bus" : "unloaded disabled bus"
            node_props = Dict(:label => node_label ? "$node" : "",
                              :energized => is_energized,
                              :node_membership => node_membership,
                              :node_color => occursin("disabled", node_membership) || occursin("unloaded", node_membership) ? colors[node_membership] : load_color_range[load_status])

            MetaGraphs.set_props!(graph, node, node_props)
        end
    end

    # Debugging
    for node in MetaGraphs.vertices(graph)
        @debug node MetaGraphs.props(graph, node)
    end

    # Collect Node properties (labels, sizes, colors)
    node_labels = [MetaGraphs.get_prop(graph, node, :label) for node in MetaGraphs.vertices(graph)]
    node_sizes = [MetaGraphs.has_prop(graph, node, :node_size) ? MetaGraphs.get_prop(graph, node, :node_size) : 1.0 for node in MetaGraphs.vertices(graph)]
    node_fills = [MetaGraphs.get_prop(graph, node, :node_color) for node in MetaGraphs.vertices(graph)]

    # Collect Edge properties (labels, weights, colors)
    edge_labels = [MetaGraphs.get_prop(graph, edge, :label) for edge in MetaGraphs.edges(graph)]
    edge_weights = [MetaGraphs.get_prop(graph, edge, :switch) ? 1.0 : 0.25 for edge in MetaGraphs.edges(graph)]
    edge_strokes = [MetaGraphs.get_prop(graph, edge, :edge_color) for edge in MetaGraphs.edges(graph)]

    # Graph Layout
    if positions != nothing
        loc_x, loc_y = positions
    else
        loc_x, loc_y = kamada_kawai_layout(graph)
    end

    # Plot
    Compose.draw(backend, GraphPlot.gplot(graph, loc_x, loc_y, nodelabel=node_labels, edgelabel=edge_labels,
                                          edgestrokec=edge_strokes, edgelinewidth=edge_weights, nodesize=node_sizes,
                                          nodefillc=node_fills, EDGELABELSIZE=4, edgelabeldistx=0.6, edgelabeldisty=0.6))

    # Return Graph, Positions
    return graph, [loc_x, loc_y]
end
