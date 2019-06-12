default_colors = Dict{String,Colors.Colorant}("open switch" => colorant"yellow",
                                              "closed switch" => colorant"green",
                                              "fixed open switch" => colorant"red",
                                              "fixed closed switch" => colorant"blue",
                                              "enabled line" => colorant"black",
                                              "disabled line" => colorant"orange",
                                              "energized bus" => colorant"green",
                                              "generator bus" => colorant"orange",
                                              "unenergized bus" => colorant"red")

function plot_branch_impedance(data::Dict{String,Any})
    r = [branch["br_r"] for (i,branch) in data["branch"]]
    x = [branch["br_x"] for (i,branch) in data["branch"]]

    s = Plots.scatter(r, x, xlabel="resistance (p.u.)", ylabel="reactance (p.u.)", label="")
    r_h = Plots.histogram(r, xlabel="resistance (p.u.)", ylabel="branch count", label="", reuse=false)
    x_h = Plots.histogram(x, xlabel="reactance (p.u.)", ylabel="branch count", label="", reuse=false)
end


function plot_network(data::Dict{String,Any}, backend::Compose.Backend; load_blocks=false, buscoords=false, exclude_gens=nothing, node_label=false, edge_label=false, colors=default_colors, edge_types=["branch", "trans"], gen_types=Dict("gen" => "pg", "storage"=>"ps"))
    connected_buses = Set(br[k] for k in ["f_bus", "t_bus"] for br in values(get(data, "branch", Dict())))

    graph = MetaGraphs.MetaGraph(length(connected_buses))
    bus_graph_map = Dict(bus["bus_i"] => i for (i, bus) in enumerate(values(get(data, "bus", Dict()))))

    if load_blocks
    else
        for edge_type in edge_types
            for edge in values(get(data, edge_type, Dict()))
                MetaGraphs.add_edge!(graph, bus_graph_map[edge["f_bus"]], bus_graph_map[edge["t_bus"]])
                props = Dict(:i => edge["index"],
                             :switch => get(edge, "dispatchable", false),
                             :status => get(edge, "br_status", 1),
                             :fixed => get(edge, "fixed", false))
                MetaGraphs.set_props!(graph, MetaGraphs.Edge(bus_graph_map[edge["f_bus"]], bus_graph_map[edge["t_bus"]]), props)
            end
        end

        for (gen_type, pg) in gen_types
            for gen in values(get(data, gen_type, Dict()))
                MetaGraphs.set_prop!(graph, gen["$(gen_type)_bus"], :pg, get(gen, pg, 0.0))
            end
            pgs = [(node, MetaGraphs.get_prop(graph, node, :pg)) for node in MetaGraphs.vertices(graph) if MetaGraphs.has_prop(graph, node, :pg)]
            if length(pgs) > 0
                pmin, pmax = minimum(Float64[v[2] for v in pgs]), maximum(Float64[v[2] for v in pgs])
                for (node, value) in pgs
                    MetaGraphs.set_prop!(graph, node, :pg, (value - pmin) / (pmax - pmin) * (2.5 - 1.0) + 1.0)
                end
            end
        end

        islands = PowerModels.connected_components(data; edges=edge_types)
        for island in islands
            is_energized = any(MetaGraphs.has_prop(graph, bus_graph_map[bus], :pg) && MetaGraphs.get_prop(graph, bus_graph_map[bus], :pg) > 0.0 for bus in island)
            for bus in island
                MetaGraphs.set_prop!(graph, bus_graph_map[bus], :energized, is_energized)
            end
        end

        node_membership = [MetaGraphs.has_prop(graph, node, :pg) ? 3 : MetaGraphs.get_prop(graph, node, :energized) ? 2 : 1 for node in MetaGraphs.vertices(graph)]
        node_colors = [colors[k] for k in ["unenergized bus", "energized bus", "generator bus"]]
        node_fills = node_colors[node_membership]
        node_sizes = [MetaGraphs.has_prop(graph, bus, :pg) ? sum(MetaGraphs.get_prop(graph, bus, :pg)) : 1.0 for bus in MetaGraphs.vertices(graph)]
        node_labels = node_label ? collect(MetaGraphs.vertices(graph)) : ["" for i in 1:length(MetaGraphs.vertices(graph))]

        edge_membership = []
        for edge in MetaGraphs.edges(graph)
            switch = Bool(MetaGraphs.get_prop(graph, edge, :switch))
            status = Bool(MetaGraphs.get_prop(graph, edge, :status))
            fixed = Bool(MetaGraphs.get_prop(graph, edge, :fixed))
            push!(edge_membership, switch && !status && !fixed ? 1 : switch && status && !fixed ? 2 : switch && !status && fixed ? 3 : switch && status && fixed ? 4 : !switch && status ? 5 : 6)
        end
        edge_colors = [colors[k] for k in ["open switch", "closed switch", "fixed open switch", "fixed closed switch", "enabled line", "disabled line"]]
        edge_strokes = edge_colors[edge_membership]
        edge_weights = [MetaGraphs.get_prop(graph, edge, :switch) ? 1.0 : 0.25 for edge in MetaGraphs.edges(graph)]
        edge_labels = edge_label ? [MetaGraphs.get_prop(graph, edge, :i) for edge in MetaGraphs.edges(graph)] : ["" for i in 1:length(MetaGraphs.edges(graph))]

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

        Compose.draw(backend, GraphPlot.gplot(graph, loc_x, loc_y, nodelabel=node_labels, edgelabel=edge_labels, edgestrokec=edge_strokes, edgelinewidth=edge_weights, nodesize=node_sizes, nodefillc=node_fills, EDGELABELSIZE=2))
    end
end


