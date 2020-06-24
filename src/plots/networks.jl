"""
    plot_network(graph; kwargs...)

Plots a network `graph`. Returns `PowerModelsGraph` and `Plots.AbstractPlot`.

# Parameters

* `graph::PowerModelsGraph{<:LightGraphs.AbstractGraph}`

    Network graph

* `filename::Union{Nothing,String}`

    Default: `nothing`. File to output the plot to, will use user-set Plots.jl backend.

* `label_nodes::Bool`

    Default: `false`. Plot labels on nodes.

* `label_edges::Bool`

    Default: `false`. Plot labels on edges.

* `colors::Dict{String,<:Colors.AbstractRGB}`

    Default: `Dict()`. Changes to default colors, see `default_colors` for available components.

* `load_color_range::Union{Nothing,Vector{<:Colors.AbstractRGB}}`

    Default: `nothing`. Range of colors for load statuses to be displayed in.

* `node_size_lims::Array`

    Default: `[10, 25]`. Min/Max values for the size of nodes.

* `edge_width_lims::Array`

    Default: `[1, 2.5]`. Min/Max values for the width of edges.

* `positions::Union{Dict, PowerModelsGraph}`

    Default: `Dict()`. Used to specify node locations of graph (avoids running layout algorithm every time).

* `use_buscoords::Bool`

    Default: `false`. Use buscoord field on buses for node positions.

* `spring_const::Float64`

    Default: `1e-3`. Only used if buscoords=true. Spring constant to be used to force-direct-layout buses with no buscoord field.

* `apply_spring_layout::Bool`

    Default: `false`. Apply spring layout after initial layout.

* `fontsize::Real`

    Default: `12`. Fontsize of labels.

* `fontfamily::String`

    Default: `"Arial"`. Font Family of labels.

* `fontcolor::Union{Symbol,<:Colors.AbstractRGB}`

    Default: `:black`. Color of the labels.

* `textalign::Symbol`

    Default: `:center`. Alignment of text.

* `plot_size::Tuple{Int,Int}`

    Default: `(300, 300)`. Size of the plot in pixels.

* `dpi::Int`

    Default: `100`. Dots-per-inch of the plot.

# Returns

* `graph::PowerModelsGraph`

    PowerModelsGraph of the network
"""
function plot_network(graph::PowerModelsGraph{T};
                      filename::Union{Nothing,String}=nothing,
                      label_nodes::Bool=false,
                      label_edges::Bool=false,
                      colors::Dict{String,<:Colors.Colorant}=Dict{String,Colors.Colorant}(),
                      load_color_range::Union{Nothing,Vector{<:Colors.AbstractRGB}}=nothing,
                      node_size_lims::Array=[2, 2.5],
                      edge_width_lims::Array=[0.5, 0.75],
                      positions::Union{Dict,PowerModelsGraph}=Dict(),
                      use_buscoords::Bool=false,
                      spring_const::Float64=2e-1,
                      apply_spring_layout::Bool=true,
                      fontsize::Real=12,
                      fontfamily::String="Arial",
                      fontcolor::Union{Symbol,<:Colors.Colorant}=:black,
                      textalign::Symbol=:center,
                      plot_size::Tuple{Int,Int}=(300,300),
                      dpi::Int=100) where T <: LightGraphs.AbstractGraph

    apply_plot_network_metadata!(graph; colors=colors, load_color_range=load_color_range, node_size_lims=node_size_lims, edge_width_lims=edge_width_lims)

    # Graph Layout
    if isa(positions, PowerModelsGraph)
        positions = Dict(node => [get_property(positions, node, :x, 0.0), get_property(positions, node, :y, 0.0)] for node in vertices(positions))
    end

    for (node, (x, y)) in positions
        set_properties!(graph, node, Dict(:x=>x, :y=>y))
    end

    if !all(hasprop(graph, node, :x) && hasprop(graph, node, :y) for node in vertices(graph))
        layout_graph!(graph, kamada_kawai_layout; use_buscoords=use_buscoords, apply_spring_layout=apply_spring_layout, spring_const=spring_const)
    end

    # Plot
    fig = plot_graph(graph; label_nodes=label_nodes, label_edges=label_edges, fontsize=fontsize, fontfamily=fontfamily, fontcolor=fontcolor, textalign=textalign, plot_size=plot_size, dpi=dpi)

    if !isnothing(filename)
        Plots.savefig(fig, filename)
    else
        Plots.display(fig)
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
                ),
                "solar" => Dict{String,String}(
                    "label" => "pv",
                    "size" => "pg",
                ),
                "storage" => Dict{String,String}(
                    "label" => "S",
                    "size" => "ps",
                ),
                "voltage_source" => Dict{String,String}(
                    "label" => "V"
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
    graph = build_graph_load_blocks(case; edge_types=edge_types, gen_types=gen_types, exclude_gens=exclude_gens, switch=switch)

    if isa(positions, PowerModelsGraph)
        positions = Dict(node => [get_property(positions, node, :x, 0.0), get_property(positions, node, :y, 0.0)] for node in vertices(positions))
    end

    for (node, (x, y)) in positions
        set_properties!(graph, node, Dict(:x=>x, :y=>y))
    end

    graph = plot_network(graph; kwargs...)
    return graph
end
