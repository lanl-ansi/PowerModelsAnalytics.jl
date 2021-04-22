"""
    `spec = plot_graph(graph::InfrastructureGraph; kwargs...)`

    Builds a figure sepcification. Returns `Vega.VGSpec`.

    Arguments:

    `graph::InfrastructureGraph{<:LightGraphs.AbstractGraph}`: Network graph
    `label_nodes::Bool`: Plot labels on nodes
    `label_edges::Bool`: Plot labels on edges
    `fontsize::Real`: Fontsize of labels
    `fontfamily::String`: Font Family of labels
    `fontcolor::Union{Symbol,<:Colors.Colorant}`: Color of the labels
    `textalign::Symbol`: Alignment of text: "left", "center", "right"
    `plot_size::Tuple{Int,Int}`: Size of the plot in pixels
    `plot_dpi::Int`: Dots-per-inch of the plot

    Returns:

    `spec<:Vega.VGSpec`: Vega.jl figure specification
"""
function plot_graph(graph::InfrastructureGraph{T};
    label_nodes::Bool=false,
    label_edges::Bool=false,
    fontsize::Real=default_fontsize,
    fontfamily::String=default_fontfamily,
    fontcolor::Union{Symbol,Colors.Colorant}=default_fontcolor,
    textalign::Symbol=default_textalign,
    plot_size::Tuple{Int,Int}=default_plot_size,
    plot_dpi::Int=default_plot_dpi,
    kwargs...) where T <: LightGraphs.AbstractGraph

    nodes = [
        Dict(
            "id"=>node,
            "x"=>get_property(graph, node, :x, 0),
            "y"=>get_property(graph, node, :y, 0),
            "color"=>"#$(Colors.hex(get_property(graph, node, :node_color, colorant"black")))",
            "size"=>get_property(graph, node, :size, 10),
            "label"=>get_property(graph, node, :label, "")
        ) for node in vertices(graph)
    ]
    vert2node = Dict(node["id"] => i for (i, node) in enumerate(nodes))

    links = [
        Dict(
            "source"=>vert2node[LightGraphs.src(edge)]-1,
            "target"=>vert2node[LightGraphs.dst(edge)]-1,
            "color"=>"#$(Colors.hex(get_property(graph, edge, :edge_color, colorant"black")))",
            "size"=>get_property(graph, edge, :edge_size, 1),
            "label"=>get_property(graph, edge, :label, "")
        ) for (n, edge) in enumerate(edges(graph))
    ]

    has_layout = all(hasprop(graph, node, :x) && hasprop(graph, node, :y) for node in vertices(graph))
    if !has_layout
        @error "no layout, cannot plot"
    end
    spec = deepcopy(default_network_graph_spec)

    push!(spec.data, Dict("name"=>"node-data", "values"=>nodes))
    push!(spec.data, Dict("name"=>"link-data", "values"=>links))

    width, height = plot_size
    @set! spec.width = width
    @set! spec.height = height

    if label_nodes
        # TODO add "label" transformation (requires Vega > v5.16+)
        node_labels = deepcopy(default_node_label_spec)

        @set! node_labels.encode.enter.fontSize = Dict("value" => fontsize)
        @set! node_labels.encode.enter.font = Dict("value" => fontfamily)
        @set! node_labels.encode.enter.fill = Dict("value" => "#$(isa(fontcolor, Symbol) ? Colors.hex(Colors.color(String(fontcolor))) : Colors.hex(fontcolor))")
        @set! node_labels.encode.enter.align = textalign

        push!(spec.marks, node_labels)
    end

    if label_edges
        # TODO this is currently broken, I think it needs "label" transformation (requires Vega > v5.16+)
        edge_labels = deepcopy(default_edge_label_spec)

        @set! edge_labels.encode.update.fontSize = Dict("value" => fontsize)
        @set! edge_labels.encode.update.font = Dict("value" => fontfamily)
        @set! edge_labels.encode.update.fill = Dict("value" => "#$(isa(fontcolor, Symbol) ? Colors.hex(Colors.color(String(fontcolor))) : Colors.hex(fontcolor))")
        @set! edge_labels.encode.update.align = textalign

        push!(spec.marks, edge_labels)
    end

    return spec
end
