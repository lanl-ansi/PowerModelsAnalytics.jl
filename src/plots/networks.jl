"""
    plot_network(graph; kwargs...)

Plots a network `graph`. Returns `PowerModelsGraph` and `Plots.AbstractPlot`.

*Parameters*
    graph::PowerModelsGraph{<:LightGraphs.AbstractGraph}
        Network graph
    filename::String
        Optional. File to output the plot to, will use user-set Plots.jl backend.
    label_nodes::Bool
        Optional. Plot labels on nodes (Default: `false`)
    label_edges::Bool
        Optional. Plot labels on edges (Default: `false`)
    colors::Dict{String,<:Colors.AbstractRGB}
        Optional. Changes to default colors, see `default_colors` for available components. (Default: `Dict()`)
    load_color_range::Union{Nothing,AbstractRange}
        Optional. Range of colors for load statuses to be displayed in. (Default: `nothing`)
    node_size_lims::Array
        Optional. Min/Max values for the size of nodes. (Default: `[10, 25]`)
    edge_width_lims::Array
        Optional. Min/Max values for the width of edges. (Default: `[1, 2.5]`)
    positions::Union{Dict, PowerModelsGraph}
        Optional. Used to specify node locations of graph (avoids running layout algorithm every time) (Default: `Dict()`)
    use_buscoords::Bool
        Optional. Use buscoord field on buses for node positions (Default: `false`)
    spring_const::Float64
        Optional. Only used if buscoords=true. Spring constant to be used to force-direct-layout buses with no buscoord field (Default: `1e-3`)
    apply_spring_layout::Bool
        Optional. Apply spring layout after initial layout (Default: `false`)
    fontsize::Real
        Optional. Fontsize of labels (Default: `12`)
    fontfamily::String
        Optional. Font Family of labels (Default: `"Arial"`)
    fontcolor::Union{Symbol,<:Colors.AbstractRGB}
        Optional. Color of the labels (Default: `:black`)
    textalign::Symbol
        Optional. Alignment of text. (Default: `:center`)
    plot_size::Tuple{Int,Int}
        Optional. Size of the plot in pixels (Default: `(600, 600)`)
    dpi::Int
        Optional. Dots-per-inch of the plot (Default: `300`)

*Returns*
    graph::PowerModelsGraph
        PowerModelsGraph of the network
    fig<:Plots.AbstractPlot
        Plots.jl figure
"""
function plot_network(graph::PowerModelsGraph{T};
                      filename::Union{Nothing,String}=nothing,
                      label_nodes::Bool=false,
                      label_edges::Bool=false,
                      colors::Dict{String,<:Colors.AbstractRGB}=Dict{String,Colors.AbstractRGB}(),
                      load_color_range::Union{Nothing,AbstractRange}=nothing,
                      node_size_lims::Array=[10, 25],
                      edge_width_lims::Array=[1, 2.5],
                      positions::Union{Dict,PowerModelsGraph}=Dict(),
                      use_buscoords::Bool=false,
                      spring_const::Float64=1e-3,
                      apply_spring_layout::Bool=false,
                      fontsize::Real=12,
                      fontfamily::String="Arial",
                      fontcolor::Union{Symbol,<:Colors.AbstractRGB}=:black,
                      textalign::Symbol=:center,
                      plot_size::Tuple{Int,Int}=(600,600),
                      dpi::Int=300) where T <: LightGraphs.AbstractGraph

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

    return graph, fig
end


"""
    plot_network(case; kwargs...)

Plots a whole network `case` at the bus-level. Returns `PowerModelsGraph` and `Plots.AbstractPlot`.
This function will build the graph from the `case`. Additional `kwargs` are passed to
`plot_network(graph; kwargs...)`.

*Parameters*
    case::Dict{String,Any}
        Network case data structure
    edge_types::Array
        Optional. List of component types that are graph edges. Default: `["branch", "dcline", "trans"]`
    gen_types::Dict{String,Dict{String,String}}
        Optional. Dictionary containing information about different generator types, including basic `gen` and `storage`. Default: $(Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"), "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status")))
    exclude_gens::Union{Nothing,Array}
        Optional. A list of patterns of generator names to not include in the graph. Default: `nothing`
    aggregate_gens::Bool
        Optional. If `true`, generators will be aggregated by type for each bus. Default: `false`
    switch::String
        Optional. The keyword that indicates branches are switches. Default: `"breaker"`
    kwargs
        Optional. Passed to `plot_network(graph; kwargs...)`

*Returns*
    graph::PowerModelsGraph
        PowerModelsGraph of the network
    fig<:Plots.AbstractPlot
        Plots.jl figure
"""
function plot_network(case::Dict{String,Any};
                      edge_types::Array{String}=["branch", "dcline", "trans"],
                      gen_types::Dict{String,Dict{String,String}}=Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"),
                                                                       "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status")),
                      exclude_gens::Union{Nothing,Array{String}}=nothing,
                      aggregate_gens::Bool=false,
                      switch::String="breaker",
                      positions::Union{Dict,PowerModelsGraph}=Dict(),
                      kwargs...)
    graph = build_graph_network(case; edge_types=edge_types, gen_types=gen_types, exclude_gens=exclude_gens, aggregate_gens=aggregate_gens, switch=switch)

    if isa(positions, PowerModelsGraph)
        positions = Dict(node => [get_property(positions, node, :x, 0.0), get_property(positions, node, :y, 0.0)] for node in vertices(positions))
    end

    for (node, (x, y)) in positions
        set_properties!(graph, node, Dict(:x=>x, :y=>y))
    end

    graph, fig = plot_network(graph; kwargs...)
    return graph, fig
end


"""
    plot_load_blocks(case; kwargs...)

Plots a whole network `case` at the load-block-level where islands are determined via
disabled and switch branches. Returns `PowerModelsGraph` and `Plots.AbstractPlot`. This
function will build the graph from the `case`. Additional `kwargs` are passed to
`plot_network(graph; kwargs...)`.

*Parameters*
    case::Dict{String,Any}
        Network case data structure
    edge_types::Array
        Optional. List of component types that are graph edges. Default: `["branch", "dcline", "trans"]`
    gen_types::Dict{String,Dict{String,String}}
        Optional. Dictionary containing information about different generator types, including basic `gen` and `storage`. Default: $(Dict("gen"=>Dict("active"=>"pg", "reactive"=>"qg", "status"=>"gen_status", "active_max"=>"pmax", "active_min"=>"pmin"), "storage"=>Dict("active"=>"ps", "reactive"=>"qs", "status"=>"status")))
    exclude_gens::Union{Nothing,Array}
        Optional. A list of patterns of generator names to not include in the graph. Default: `nothing`
    aggregate_gens::Bool
        Optional. If `true`, generators will be aggregated by type for each bus. Default: `false`
    switch::String
        Optional. The keyword that indicates branches are switches. Default: `"breaker"`
    kwargs
        Optional. Passed to `plot_network(graph; kwargs...)`

*Returns*
    graph::PowerModelsGraph
        PowerModelsGraph of the network
    fig<:Plots.AbstractPlot
        Plots.jl figure
"""
function plot_load_blocks(case::Dict{String,Any};
                          edge_types::Array{String}=["branch", "dcline", "trans"],
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

    graph, fig = plot_network(graph; kwargs...)
    return graph, fig
end
