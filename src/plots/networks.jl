"""
    `plot_network(graph; kwargs...)`

    Plots a network `graph`. Returns `PowerModelsGraph` and `Plots.AbstractPlot`.

    Arguments:

    `graph::PowerModelsGraph{<:LightGraphs.AbstractGraph}`: Network graph
    `filename::String`: File to output the plot to, will use user-set Plots.jl backend
    `label_nodes::Bool`: Plot labels on nodes
    `label_edges::Bool`: Plot labels on edges
    `colors::Dict{String,<:Colors.Colorant}`: Changes to default colors, see `default_colors` for available components
    `load_color_range::Vector{<:Colors.Colorant}}`: Range of colors for load statuses
    `node_size_limits::Vector{<:Real}`: Min/Max values for the size of nodes
    `edge_width_limits::Vector{<:Real}`: Min/Max values for the width of edges
    `positions::Union{Dict{Int,<:Real}, PowerModelsGraph}`: Used to specify node locations of graph (avoids running layout algorithm every time)
    `use_coordinates::Bool`: Use buscoord field on buses for node positions
    `spring_constant::Real`: Only used if buscoords=true. Spring constant to be used to force-direct-layout buses with no buscoord field
    `apply_spring_layout::Bool`: Apply spring layout after initial layout
    `fontsize::Real`: Fontsize of labels
    `fontfamily::String`: Font Family of labels
    `fontcolor::Union{Symbol,<:Colors.Colorant}`: Color of the labels
    `textalign::Symbol`: Alignment of text
    `plot_size::Tuple{Int,Int}`: Size of the plot in pixels
    `plot_dpi::Int`: Dots-per-inch of the plot

    Returns:

    `graph::PowerModelsGraph`: PowerModelsGraph of the network
"""
function plot_network(graph::PowerModelsGraph{T};
    filename::String="",
    label_nodes::Bool=false,
    label_edges::Bool=false,
    colors::Dict{String,<:Colors.Colorant}=default_colors,
    color_range::Vector{<:Colors.Colorant}=default_color_range,
    node_size_limits::Vector{<:Real}=default_node_size_limits,
    edge_width_limits::Vector{<:Real}=default_edge_width_limits,
    positions::Union{Dict{Int,<:Real},PowerModelsGraph}=Dict{Int,Real}(),
    use_coordinates::Bool=false,
    spring_constant::Real=default_spring_constant,
    apply_spring_layout::Bool=false,
    fontsize::Real=default_fontsize,
    fontfamily::String=default_fontfamily,
    fontcolor::Union{Symbol,<:Colors.Colorant}=default_fontcolor,
    textalign::Symbol=default_textalign,
    plot_size::Tuple{<:Int,<:Int}=default_plot_size,
    dpi::Int=default_plot_dpi
    ) where T <: LightGraphs.AbstractGraph

    apply_plot_network_metadata!(graph; colors=colors, color_range=color_range, node_size_limits=node_size_limits, edge_width_limits=edge_width_limits)

    # Graph Layout
    if isa(positions, PowerModelsGraph)
        positions = Dict(node => [get_property(positions, node, :x, 0.0), get_property(positions, node, :y, 0.0)] for node in vertices(positions))
    end

    for (node, (x, y)) in positions
        set_properties!(graph, node, Dict(:x=>x, :y=>y))
    end

    if !all(hasprop(graph, node, :x) && hasprop(graph, node, :y) for node in vertices(graph))
        layout_graph!(graph, kamada_kawai_layout; use_coordinates=use_coordinates, apply_spring_layout=apply_spring_layout, spring_constant=spring_constant)
    end

    # Plot
    fig = plot_graph(graph;
        label_nodes=label_nodes,
        label_edges=label_edges,
        fontsize=fontsize,
        fontfamily=fontfamily,
        fontcolor=fontcolor,
        textalign=textalign,
        plot_size=plot_size,
        dpi=dpi)

    if isempty(filename)
        Plots.display(fig)
    else
        Plots.savefig(fig, filename)
    end

    return graph
end


"""
    plot_network(case; kwargs...)

Plots a whole network `case` at the bus-level. Returns `PowerModelsGraph` and `Plots.AbstractPlot`.
This function will build the graph from the `case`. Additional `kwargs` are passed to
`plot_network(graph; kwargs...)`.

# Parameters

* `case::Dict{String,Any}`

    Network case data structure

* `edge_types::Array`

    Default: `["branch", "dcline", "transformer"]`. List of component types that are graph edges.

* `gen_types::Dict{String,Dict{String,String}}`

    Default:
    ```
    Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"),
                    "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status"))
    ```

    Dictionary containing information about different generator types, including basic `gen` and `storage`.

* `exclude_gens::Union{Nothing,Array}`

    Default: `nothing`. A list of patterns of generator names to not include in the graph.

* `aggregate_gens::Bool`

    Default: `false`. If `true`, generators will be aggregated by type for each bus.

* `switch::String`

    Default: `"breaker"`. The keyword that indicates branches are switches.

* `kwargs`

    Passed to `plot_network(graph; kwargs...)`

# Returns

* `graph::PowerModelsGraph`

    PowerModelsGraph of the network
"""
function plot_network(case::Dict{String,<:Any};
                      edge_types::Union{Missing,Vector{<:String}}=missing,
                      gen_types::Union{Missing,Dict{String,<:Dict{<:String,<:String}}}=missing,
                      exclude_gens::Union{Nothing,Vector{<:Any}}=nothing,
                      node_objects::Union{Missing,Dict{String,<:Dict{String,<:String}}}=missing,
                      aggregate_gens::Bool=false,
                      switch::String="breaker",
                      positions::Union{Dict{Int,<:Any},PowerModelsGraph}=Dict{Int,Any}(),
                      kwargs...)

    if Int(get(case, "data_model", 1)) == 0
        if ismissing(edge_types)
            edge_types = ["line", "transformer", "switch"]
        end

        if ismissing(node_objects)
            node_objects = Dict{String,Dict{String,String}}(
                "generator" => Dict{String,String}(
                    "label" => "~",
                    "size" => "pg",
                    "active_power" => "pg",
                    "reactive_power" => "qg",
                ),
                "solar" => Dict{String,String}(
                    "label" => "pv",
                    "size" => "pg",
                    "active_power" => "pg",
                    "reactive_power" => "qg",
                ),
                "storage" => Dict{String,String}(
                    "label" => "S",
                    "size" => "ps",
                    "active_power" => "ps",
                    "reactive_power" => "qs",
                ),
                "voltage_source" => Dict{String,String}(
                    "label" => "V",
                    "size" => "pg",
                    "active_power" => "pg",
                    "reactive_power" => "qg",
                )
            )
        end
        graph = build_graph_network_eng(case; edge_types=edge_types, node_objects=node_objects)
    else
        if ismissing(gen_types)
            gen_types = Dict(
                "gen" => Dict(
                    "active"=>"pg",
                    "reactive"=>"qg",
                    "status"=>"gen_status",
                    "active_max"=>"pmax",
                    "active_min"=>"pmin"
                ),
                "storage" => Dict(
                    "active"=>"ps",
                    "reactive"=>"qs",
                    "status"=>"status"
                )
            )
        end

        if ismissing(edge_types)
            edge_types = ["branch", "dcline", "transformer"]
        end
        graph = build_graph_network(case; edge_types=edge_types, gen_types=gen_types, exclude_gens=exclude_gens, aggregate_gens=aggregate_gens, switch=switch)
    end

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
    plot_load_blocks(case; kwargs...)

Plots a whole network `case` at the load-block-level where islands are determined via
disabled and switch branches. Returns `PowerModelsGraph` and `Plots.AbstractPlot`. This
function will build the graph from the `case`. Additional `kwargs` are passed to
`plot_network(graph; kwargs...)`.

# Parameters

* `case::Dict{String,Any}`

    Network case data structure

* `edge_types::Array`

    Default: `["branch", "dcline", "transformer"]`. List of component types that are graph edges.

* `gen_types::Dict{String,Dict{String,String}}`

    Default:
    ```
    Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"),
                    "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status"))
    ```

    Dictionary containing information about different generator types, including basic `gen` and `storage`.

* `exclude_gens::Union{Nothing,Array}`

    Default: `nothing`. A list of patterns of generator names to not include in the graph.

* `aggregate_gens::Bool`

    Default: `false`. If `true`, generators will be aggregated by type for each bus.

* `switch::String`

    Default: `"breaker"`. The keyword that indicates branches are switches.

* `kwargs`

    Passed to `plot_network(graph; kwargs...)`

# Returns

* `graph::PowerModelsGraph`

    PowerModelsGraph of the network
"""
function plot_load_blocks(case::Dict{String,Any};
                          edge_types::Array{String}=["branch", "dcline", "transformer"],
                          gen_types::Dict{String,Dict{String,String}}=Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"),
                                                                           "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status")),
                          exclude_gens::Union{Nothing,Array{String}}=nothing,
                          aggregate_gens::Bool=false,
                          switch::String="breaker",
                          positions::Union{Dict,PowerModelsGraph}=Dict(),
                          kwargs...)

    if Int(get(case, "data_model", 1)) == 0
        graph = build_graph_load_blocks_eng(case; edge_types=edge_types, node_objects=node_objects)
    else
        graph = build_graph_load_blocks(case; edge_types=edge_types, gen_types=gen_types, exclude_gens=exclude_gens, switch=switch)
    end

    if isa(positions, PowerModelsGraph)
        positions = Dict(node => [get_property(positions, node, :x, 0.0), get_property(positions, node, :y, 0.0)] for node in vertices(positions))
    end

    for (node, (x, y)) in positions
        set_properties!(graph, node, Dict(:x=>x, :y=>y))
    end

    graph = plot_network(graph; kwargs...)
    return graph
end
