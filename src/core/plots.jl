default_colors = Dict{String,Colors.Colorant}("open switch" => colorant"yellow",
                                              "closed switch" => colorant"green",
                                              "fixed open switch" => colorant"red",
                                              "fixed closed switch" => colorant"blue",
                                              "enabled line" => colorant"black",
                                              "disabled line" => colorant"orange",
                                              "energized bus" => colorant"green",
                                              "energized generator" => colorant"green",
                                              "energized synchronous condenser" => colorant"yellow",
                                              "enabled generator" => colorant"orange",
                                              "disabled generator" => colorant"red",
                                              "unloaded enabled bus" => colorant"black",
                                              "unloaded disabled bus" => colorant"grey",
                                              "loaded disabled bus" => colorant"red",
                                              "loaded enabled bus" => colorant"green",
                                              "connector" => colorant"lightgrey")

convert_nan(x) = isnan(x) ? 0.0 : x

function plot_branch_impedance(data::Dict{String,Any})
    r = [branch["br_r"] for (i,branch) in data["branch"]]
    x = [branch["br_x"] for (i,branch) in data["branch"]]

    s = Plots.scatter(r, x, xlabel="resistance (p.u.)", ylabel="reactance (p.u.)", label="")
    r_h = Plots.histogram(r, xlabel="resistance (p.u.)", ylabel="branch count", label="", reuse=false)
    x_h = Plots.histogram(x, xlabel="reactance (p.u.)", ylabel="branch count", label="", reuse=false)
end


function plot_network(data::Dict{String,Any}, backend::Compose.Backend; load_blocks=false, buscoords=false, exclude_gens=nothing, node_label=false, edge_label=false, colors=default_colors, edge_types=["branch", "trans"], gen_types=Dict("gen" => ["pg", "qg"], "storage"=>["ps", "qs"]))
    connected_buses = Set(br[k] for k in ["f_bus", "t_bus"] for br in values(get(data, "branch", Dict())))
    gens = [(key, gen) for key in keys(gen_types) for gen in values(get(data, key, Dict()))]
    n_buses = length(connected_buses)
    n_gens = length(gens)

    graph = MetaGraphs.MetaGraph(n_buses + n_gens)
    bus_graph_map = Dict(bus["bus_i"] => i for (i, bus) in enumerate(values(get(data, "bus", Dict()))))
    gen_graph_map = Dict("$(gen_type)_$(gen["index"])" => i for (i, (gen_type, gen)) in zip(n_buses+1:n_buses+n_gens, gens))

    if load_blocks
        plot_load_blocks(data, backend; exclude_gens=exclude_gens, node_label=node_label, colors=colors, edge_types=edge_types, gen_types=gen_types)
    else
        for edge_type in edge_types
            for edge in values(get(data, edge_type, Dict()))
                MetaGraphs.add_edge!(graph, bus_graph_map[edge["f_bus"]], bus_graph_map[edge["t_bus"]])

                switch = get(edge, "dispatchable", false)
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

        for (gen_type, (pg, qg)) in gen_types
            for gen in values(get(data, gen_type, Dict()))
                MetaGraphs.add_edge!(graph, gen_graph_map["$(gen_type)_$(gen["index"])"], bus_graph_map[gen["$(gen_type)_bus"]])
                node_membership = get(gen, "$(gen_type)_status", 1) == 0 ? "disabled generator" : get(gen, pg, 0.0) > 0 ? "energized generator" : get(gen, pg, 0.0) == 0 && get(gen, qg, 0.0) > 0 ? "energized synchronous condenser" : "enabled generator"
                label = gen_type == "storage" ? "S" : occursin("condenser", node_membership) ? "C" : "~"
                node_props = Dict(:label => label,
                                  :energized => gen["gen_status"] == 1 && (get(gen, pg, 0.0) > 0 || get(gen, qg, 0.0) > 0) ? true : false,
                                  :pg => convert_nan(get(gen, pg, 0.0)),
                                  :qg => convert_nan(get(gen, qg, 0.0)),
                                  :node_membership => node_membership,
                                  :node_color => colors[node_membership])
                MetaGraphs.set_props!(graph, gen_graph_map["$(gen_type)_$(gen["index"])"], node_props)

                edge_props = Dict(:label => "",
                                  :switch => false,
                                  :edge_membership => "connector",
                                  :edge_color => colors["connector"])
                MetaGraphs.set_props!(graph, MetaGraphs.Edge(gen_graph_map["$(gen_type)_$(gen["index"])"], bus_graph_map[gen["$(gen_type)_bus"]]), edge_props)
            end

            pgs = [(node, MetaGraphs.get_prop(graph, node, :pg)) for node in MetaGraphs.vertices(graph) if MetaGraphs.has_prop(graph, node, :pg)]
            qgs = [(node, MetaGraphs.get_prop(graph, node, :qg)) for node in MetaGraphs.vertices(graph) if MetaGraphs.has_prop(graph, node, :qg)]
            if length(pgs) > 0 || length(qgs) > 0
                pmin, pmax = minimum(filter(!isnan,Float64[v[2] for v in pgs])), maximum(filter(!isnan,Float64[v[2] for v in pgs]))
                qmin, qmax = minimum(filter(!isnan,Float64[v[2] for v in qgs])), maximum(filter(!isnan,Float64[v[2] for v in qgs]))
                amin, amax = minimum(filter(!isnan,Float64[pmin, qmin])), maximum(filter(!isnan,Float64[pmax, qmax]))
                for (node, value) in pgs
                    MetaGraphs.set_prop!(graph, node, :g, (value - amin) / (amax - amin) * (2.0 - 1.0) + 1.0)
                end
            end
        end

        islands = try
            islands = PowerModels.calc_connected_components(data; edges=edge_types)
        catch
            islands = PowerModels.connected_components(data, edges=edge_types)
        end

        for island in islands
            is_energized = any(gen["gen_status"] == 1 && (get(gen, pg, 0.0) > 0 || get(gen, qg, 0.0) > 0) for (gen_type, (pg, qg)) in gen_types for gen in values(get(data, gen_type, Dict())) if gen["$(gen_type)_bus"] in island)
            for bus in island
                node_membership = data["bus"]["$bus"]["bus_type"] == 4 ? "unloaded disabled bus" : "unloaded enabled bus"
                node_props = Dict(:label => node_label ? "$bus" : "",
                                  :energized => is_energized,
                                  :node_membership => node_membership,
                                  :node_color => colors[node_membership])
                MetaGraphs.set_props!(graph, bus_graph_map[bus], node_props)
            end
        end

        for load in values(get(data, "load", Dict()))
            color_range = Colors.range(colors["loaded disabled bus"], colors["loaded enabled bus"], length=101)
            load_status = trunc(Int, round(get(load, "status", 1.0) * 100)) + 1

            bus_type = data["bus"]["$(load["load_bus"])"]["bus_type"]
            energized = MetaGraphs.get_prop(graph, bus_graph_map[load["load_bus"]], :energized)

            node_membership = "unloaded disabled bus"
            if load["pd"] > 0 || load["qd"] > 0
                if bus_type == 4 || !energized
                    node_membership = "loaded disabled bus"
                elseif bus_type != 4 && energized
                    node_membership = "loaded enabled bus"
                end
            else
                if energized && bus_type != 4
                    node_membership = "unloaded enabled bus"
                end
            end

            node_props = Dict(:node_membership => node_membership,
                              :node_color => occursin("disabled", node_membership) ? colors[node_membership] : color_range[load_status])
            MetaGraphs.set_props!(graph, bus_graph_map[load["load_bus"]], node_props)
        end

        for node in MetaGraphs.vertices(graph)
            @debug node MetaGraphs.props(graph, node)
        end

        node_fills = [MetaGraphs.get_prop(graph, node, :node_color) for node in MetaGraphs.vertices(graph)]
        node_sizes = [MetaGraphs.has_prop(graph, bus, :g) ? sum(MetaGraphs.get_prop(graph, bus, :g)) : 1.0 for bus in MetaGraphs.vertices(graph)]
        node_labels = [MetaGraphs.get_prop(graph, node, :label) for node in MetaGraphs.vertices(graph)]

        edge_strokes = [MetaGraphs.get_prop(graph, edge, :edge_color) for edge in MetaGraphs.edges(graph)]
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


function plot_load_blocks(data::Dict{String,Any}, backend::Compose.Backend; exclude_gens=nothing, node_label=false, edge_label=false, colors=default_colors, edge_types=["branch", "trans"], gen_types=Dict("gen" => "pg", "storage"=>"ps"))
    Compose.draw(backend, GraphPlot.gplot())
end
