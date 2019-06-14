default_colors = Dict{String,Colors.Colorant}("open switch" => colorant"yellow",
                                              "closed switch" => colorant"green",
                                              "fixed open switch" => colorant"red",
                                              "fixed closed switch" => colorant"blue",
                                              "enabled line" => colorant"black",
                                              "disabled line" => colorant"orange",
                                              "energized bus" => colorant"green",
                                              "energized generator" => colorant"green",
                                              "enabled generator" => colorant"orange",
                                              "disabled generator" => colorant"red",
                                              "unenergized bus" => colorant"red",
                                              "connector" => colorant"lightgrey")


function plot_branch_impedance(data::Dict{String,Any})
    r = [branch["br_r"] for (i,branch) in data["branch"]]
    x = [branch["br_x"] for (i,branch) in data["branch"]]

    s = Plots.scatter(r, x, xlabel="resistance (p.u.)", ylabel="reactance (p.u.)", label="")
    r_h = Plots.histogram(r, xlabel="resistance (p.u.)", ylabel="branch count", label="", reuse=false)
    x_h = Plots.histogram(x, xlabel="reactance (p.u.)", ylabel="branch count", label="", reuse=false)
end


function plot_network(data::Dict{String,Any}, backend::Compose.Backend; load_blocks=false, buscoords=false, exclude_gens=nothing, node_label=false, edge_label=false, colors=default_colors, edge_types=["branch", "trans"], gen_types=Dict("gen" => "pg", "storage"=>"ps"))
    connected_buses = Set(br[k] for k in ["f_bus", "t_bus"] for br in values(get(data, "branch", Dict())))
    gens = [(key, gen) for key in keys(gen_types) for gen in values(get(data, key, Dict()))]
    n_buses = length(connected_buses)
    n_gens = length(gens)

    graph = MetaGraphs.MetaGraph(n_buses + n_gens)
    bus_graph_map = Dict(bus["bus_i"] => i for (i, bus) in enumerate(values(get(data, "bus", Dict()))))
    gen_graph_map = Dict("$(gen_type)_$(gen["index"])" => i for (i, (gen_type, gen)) in zip(n_buses+1:n_buses+n_gens, gens))

    if load_blocks
    else
        for edge_type in edge_types
            for edge in values(get(data, edge_type, Dict()))
                MetaGraphs.add_edge!(graph, bus_graph_map[edge["f_bus"]], bus_graph_map[edge["t_bus"]])

                switch = get(edge, "dispatchable", false)
                fixed = get(edge, "fixed", false)
                status = Bool(get(edge, "br_status", 1))

                props = Dict(:i => edge["index"],
                             :switch => switch,
                             :status => status,
                             :fixed => fixed,
                             :label => edge_label ? edge["index"] : "",
                             :edge_membership => switch && status && !fixed ? "closed switch" : switch && !status && !fixed ? "open switch" : switch && status && fixed ? "fixed closed switch" : switch && !status && fixed ? "fixed open switch" : !switch && status ? "enabled line" : "disabled line")
                MetaGraphs.set_props!(graph, MetaGraphs.Edge(bus_graph_map[edge["f_bus"]], bus_graph_map[edge["t_bus"]]), props)
            end
        end

        for (gen_type, pg) in gen_types
            for gen in values(get(data, gen_type, Dict()))
                MetaGraphs.add_edge!(graph, gen_graph_map["$(gen_type)_$(gen["index"])"], bus_graph_map[gen["$(gen_type)_bus"]])
                node_props = Dict(:label => gen_type[1],
                                  :energized => get(gen, pg, 0.0) > 0 ? true : false,
                                  :pg => get(gen, pg, 0.0),
                                  :node_membership => get(gen, "$(gen_type)_status", 1) == 0 ? "disabled generator" : get(gen, pg, 0.0) > 0 ? "energized generator" : "enabled generator")
                MetaGraphs.set_props!(graph, gen_graph_map["$(gen_type)_$(gen["index"])"], node_props)

                edge_props = Dict(:label => "",
                                  :i => 0,
                                  :switch => false,
                                  :status => 1,
                                  :fixed => true,
                                  :edge_membership => "connector")
                MetaGraphs.set_props!(graph, MetaGraphs.Edge(gen_graph_map["$(gen_type)_$(gen["index"])"], bus_graph_map[gen["$(gen_type)_bus"]]), edge_props)
            end
            pgs = [(node, MetaGraphs.get_prop(graph, node, :pg)) for node in MetaGraphs.vertices(graph) if MetaGraphs.has_prop(graph, node, :pg)]
            if length(pgs) > 0
                pmin, pmax = minimum(Float64[v[2] for v in pgs]), maximum(Float64[v[2] for v in pgs])
                for (node, value) in pgs
                    MetaGraphs.set_prop!(graph, node, :pg, (value - pmin) / (pmax - pmin) * (2.5 - 1.0) + 1.0)
                end
            end
        end

        islands = try
            islands = PowerModels.calc_connected_components(data; edges=edge_types)
        catch
            islands = PowerModels.connected_components(data, edges=edge_types)
        end

        for island in islands
            is_energized = any(get(gen, pg, 0.0) > 0 for (gen_type, pg) in gen_types for gen in values(get(data, gen_type, Dict())) if gen["$(gen_type)_bus"] in island)
            for bus in island
                node_props = Dict(:label => node_label ? "$bus" : "",
                                  :energized => is_energized,
                                  :node_membership => is_energized ? "energized bus" : "unenergized bus")
                MetaGraphs.set_props!(graph, bus_graph_map[bus], node_props)
            end
        end

        node_fills = [colors[MetaGraphs.get_prop(graph, node, :node_membership)] for node in MetaGraphs.vertices(graph)]
        node_sizes = [MetaGraphs.has_prop(graph, bus, :pg) ? sum(MetaGraphs.get_prop(graph, bus, :pg)) : 1.0 for bus in MetaGraphs.vertices(graph)]
        node_labels = [MetaGraphs.get_prop(graph, node, :label) for node in MetaGraphs.vertices(graph)]

        edge_strokes = [colors[MetaGraphs.get_prop(graph, edge, :edge_membership)] for edge in MetaGraphs.edges(graph)]
        edge_weights = [MetaGraphs.get_prop(graph, edge, :switch) ? 1.0 : 0.25 for edge in MetaGraphs.edges(graph)]
        edge_labels = [MetaGraphs.get_prop(graph, edge, :label) for edge in MetaGraphs.edges(graph)]

        if buscoords
            pos = Dict(n => get(get(data["bus"], "$n", Dict()), "buscoord", missing) for n in MetaGraphs.vertices(graph))
            avg_x, avg_y = mean(hcat(skipmissing([v for v in values(pos)])...), dims=2)
            for (v, p) in pos
                if ismissing(p)
                    pos[v] = [avg_x, avg_y]
                end
            end
            fixed = [n for n in MetaGraphs.vertices(graph) if "buscoord" in keys(get(data["bus"], "$n", Dict()))]
            loc_x, loc_y = spring_layout(graph; pos=pos, fixed=fixed, k=0.1, iterations=200)
        else
            loc_x, loc_y = kamada_kawai_layout(graph)
        end

        Compose.draw(backend, GraphPlot.gplot(graph, loc_x, loc_y, nodelabel=node_labels, edgelabel=edge_labels,
                                              edgestrokec=edge_strokes, edgelinewidth=edge_weights, nodesize=node_sizes,
                                              nodefillc=node_fills, EDGELABELSIZE=4, edgelabeldistx=0.6, edgelabeldisty=0.6))
    end
end
