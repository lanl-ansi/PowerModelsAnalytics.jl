"""
    plot_network(network, backend; kwargs...)

Plots a whole `network` at the bus-level to `backend`. Returns `MetaGraph` and `positions`.

kwargs
------
    label_nodes::Bool
        Plot labels on nodes (Default: false)
    label_edges::Bool
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
    scale_nodes::Array
        Lower and Upper bound of size of nodes (Default: [1, 2.5])
    scale_edges::Array
        Lower and Upper bound of size of edges (Default: [1, 2.5])
    fontsize_nodes::Real
        Fontsize of node labels (Default: 2)
    fontsize_edges::Real
        Fontsize of edge labels (Default: 2)
    label_offset_edges::Array
        Offset of edge labels [x, y] (Default: [0, 0])
"""
function plot_network(graph::PowerModelsGraph{T}; filename::Union{Nothing,String}=nothing,
                        label_nodes::Bool=false,
                        label_edges::Bool=false,
                        colors::Dict=Dict(),
                        use_buscoords::Bool=false,
                        spring_const::Float64=1e-3,
                        positions::Union{Nothing,Array}=nothing,
                        scale_nodes::Array=[10, 25],
                        scale_edges::Array=[1, 2.5],
                        fontsize::Real=12,
                        apply_spring_layout::Bool=false) where T <: LightGraphs.AbstractGraph

    colors = merge(default_colors, colors)
    load_color_range = Colors.range(colors["loaded disabled bus"], colors["loaded enabled bus"], length=11)

    apply_plot_network_metadata!(graph, colors, load_color_range, scale_nodes, scale_edges)

    # Debug
    for node in vertices(graph)
        @debug node properties(graph, node)
    end

    # Collect Node properties (color fill, sizes, labels)
    node_fills = [get_property(graph, node, :node_color, colorant"black") for node in vertices(graph)]
    node_sizes = [sum(get_property(graph, bus, :node_size, scale_nodes[1])) for bus in vertices(graph)]
    node_labels = [label_nodes ? get_property(graph, node, :label, "") : "" for node in vertices(graph)]

    # Collect Edge properties (stroke color, edge weights, labels)
    edge_strokes = [get_property(graph, edge, :edge_color, colorant"black") for edge in edges(graph)]
    edge_weights = [get_property(graph, edge, :edge_size, 1) for edge in edges(graph)]
    edge_labels = [label_edges ? get_property(graph, edge, :label, "") : "" for edge in edges(graph)]

    # Graph Layout
    if !all(hasprop(graph, node, :x) && hasprop(graph, node, :y) for node in vertices(graph))
        layout_graph!(graph, kamada_kawai_layout; use_buscoords=use_buscoords, apply_spring_layout=apply_spring_layout, spring_const=spring_const)
    end

    # Plot
    fig = plot_graph(graph; label_nodes=label_nodes, label_edges=label_edges, fontsize=fontsize)

    if !isnothing(filename)
        Plots.savefig(fig, filename)
    end

    return graph
end


function plot_network(case::Dict{String,Any};
                      edge_types::Array{String}=["branch", "dcline", "trans"],
                      gen_types::Dict{String,Dict{String,String}}=Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"),
                                                                       "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status")),
                      exclude_gens::Union{Nothing,Array{String}}=nothing,
                      switch::String="switchable",
                      positions::Union{Dict,PowerModelsGraph}=Dict(),
                      kwargs...)
    graph = build_graph_network(case; edge_types=edge_types, gen_types=gen_types, exclude_gens=exclude_gens, switch=switch)

    if isa(positions, PowerModelsGraph)
        positions = Dict(node => [get_property(positions, node, :x, 0.0), get_property(positions, node, :y, 0.0)] for node in vertices(positions))
    end

    for (node, (x, y)) in positions
        set_properties!(graph, node, Dict(:x=>x, :y=>y))
    end

    graph = plot_network(graph; kwargs...)
    return graph
end


"""
    plot_load_blocks(network, backend; kwargs...)

Plots a power `network` at the load-block-level on `backend`. Returns `MetaGraph` and `positions`.

kwargs
------
    label_nodes::Bool
        Plot labels on nodes (Default: false)
    label_edges::Bool
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
function plot_load_blocks(graph::PowerModelsGraph{T};
                            filename::String,
                            label_nodes::Bool=false,
                            label_edges::Bool=false,
                            fontsize::Real=12,
                            colors::Dict{String,Colors.Colorant}=Dict{String,Colors.Colorant}(),
                            apply_spring_layout::Bool=false,
                            spring_const::Float64=1e-3,
                            scale_nodes::Array=[10, 25],
                            scale_edges::Array=[1, 2.5]) where T <: LightGraphs.AbstractGraph

    # Setup Colors
    colors = merge(default_colors, colors)
    load_color_range = Colors.range(colors["loaded disabled bus"], colors["loaded enabled bus"], length=11)

    apply_plot_network_metadata!(graph, colors, load_color_range, scale_nodes, scale_edges)

    # Graph Layout
    if !all(hasprop(graph, node, :x) && hasprop(graph, node, :y) for node in vertices(graph))
        layout_graph!(graph, kamada_kawai_layout; apply_spring_layout=apply_spring_layout, spring_const=spring_const)
    end

    # Plot
    fig = plot_graph(graph; label_nodes=label_nodes, label_edges=label_edges, fontsize=fontsize)

    if !isnothing(filename)
        Plots.savefig(fig, filename)
    end

    return graph
end


function plot_load_blocks(case::Dict{String,Any};
                          edge_types::Array{String}=["branch", "dcline", "trans"],
                          gen_types::Dict{String,Dict{String,String}}=Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"),
                                                                           "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status")),
                          exclude_gens::Union{Nothing,Array{String}}=nothing,
                          switch::String="switchable",
                          positions::Union{Dict,PowerModelsGraph}=Dict(),
                          kwargs...
                         )
    graph = build_graph_load_blocks(case; edge_types=edge_types, gen_types=gen_types, exclude_gens=exclude_gens, switch=switch)

    if isa(positions, PowerModelsGraph)
        positions = Dict(node => [get_property(positions, node, :x, 0.0), get_property(positions, node, :y, 0.0)] for node in vertices(positions))
    end

    for (node, (x, y)) in positions
        set_properties!(graph, node, Dict(:x=>x, :y=>y))
    end

    graph = plot_load_blocks(graph; kwargs...)
    return graph
end
