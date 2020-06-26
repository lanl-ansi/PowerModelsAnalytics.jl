"""
    `plot_network(graph; kwargs...)`

    Plots a network `graph`. Returns `InfrastructureGraph` and `Plots.AbstractPlot`.

    Arguments:

    `graph::InfrastructureGraph{<:LightGraphs.AbstractGraph}`: Network graph
    `filename::String`: File to output the plot to, will use user-set Plots.jl backend
    `label_nodes::Bool`: Plot labels on nodes
    `label_edges::Bool`: Plot labels on edges
    `colors::Dict{String,<:Colors.Colorant}`: Changes to default colors, see `default_colors` for available components
    `load_color_range::Vector{<:Colors.Colorant}}`: Range of colors for load statuses
    `node_size_limits::Vector{<:Real}`: Min/Max values for the size of nodes
    `edge_width_limits::Vector{<:Real}`: Min/Max values for the width of edges
    `positions::Union{Dict{Int,<:Real}, InfrastructureGraph}`: Used to specify node locations of graph (avoids running layout algorithm every time)
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

    `graph::InfrastructureGraph`: InfrastructureGraph of the network
"""
function plot_network(graph::InfrastructureGraph{T};
    filename::String="",
    label_nodes::Bool=false,
    label_edges::Bool=false,
    colors::Dict{String,<:Colors.Colorant}=default_colors,
    demand_color_range::Vector{<:Colors.Colorant}=default_demand_color_range,
    node_size_limits::Vector{<:Real}=default_node_size_limits,
    edge_width_limits::Vector{<:Real}=default_edge_width_limits,
    positions::Union{Dict{Int,<:Real},InfrastructureGraph}=Dict{Int,Real}(),
    use_coordinates::Bool=false,
    spring_constant::Real=default_spring_constant,
    apply_spring_layout::Bool=false,
    fontsize::Real=default_fontsize,
    fontfamily::String=default_fontfamily,
    fontcolor::Union{Symbol,<:Colors.Colorant}=default_fontcolor,
    textalign::Symbol=default_textalign,
    plot_size::Tuple{<:Int,<:Int}=default_plot_size,
    plot_dpi::Int=default_plot_dpi,
    kwargs...
    ) where T <: LightGraphs.AbstractGraph

    apply_plot_network_metadata!(graph;
        colors=colors,
        demand_color_range=demand_color_range,
        node_size_limits=node_size_limits,
        edge_width_limits=edge_width_limits
    )

    # Graph Layout
    if isa(positions, InfrastructureGraph)
        positions = Dict{Int,Vector{Real}}(
            node => Vector{Real}([get_property(positions, node, :x, 0.0), get_property(positions, node, :y, 0.0)]) for node in vertices(positions)
        )
    end

    for (node, (x, y)) in positions
        set_properties!(graph, node, Dict{Symbol,Any}(
                :x=>x,
                :y=>y
            )
        )
    end

    if !all(hasprop(graph, node, :x) && hasprop(graph, node, :y) for node in vertices(graph))
        layout_graph!(graph, kamada_kawai_layout;
            use_coordinates=use_coordinates,
            apply_spring_layout=apply_spring_layout,
            spring_constant=spring_constant
        )
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
        plot_dpi=plot_dpi
    )

    if isempty(filename)
        Plots.display(fig)
    else
        Plots.savefig(fig, filename)
    end

    return graph
end


"""
    `graph = plot_network(case::Dict{String,<:Any}; kwargs...)`

    Plots a whole network `case` at the bus-level. Returns `InfrastructureGraph` and `Plots.AbstractPlot`.
    This function will build the graph from the `case`. Additional `kwargs` are passed to
    `plot_network(graph; kwargs...)`.

    Arguments:

    `case::Dict{String,Any}`: Network case data structure
    `positions::Union{Dict{Int,<:Any},InfrastructureGraph}`: Pre-set positions of graph vertices

    Returns:

    `graph::InfrastructureGraph`: InfrastructureGraph of the network
"""
function plot_network(case::Dict{String,<:Any}; positions::Union{Dict{Int,<:Any},InfrastructureGraph}=Dict{Int,Any}(), kwargs...)

    graph = build_network_graph(case; kwargs...)

    if isa(positions, InfrastructureGraph)
        positions = Dict(node => [get_property(positions, node, :x, 0.0), get_property(positions, node, :y, 0.0)] for node in vertices(positions))
    end

    for (node, (x, y)) in positions
        set_properties!(graph, node, Dict(:x=>x, :y=>y))
    end

    graph = plot_network(graph; kwargs...)

    return graph
end
