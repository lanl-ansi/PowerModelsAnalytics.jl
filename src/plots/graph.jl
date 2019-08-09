"""
    plot_graph(graph; kwargs...)

Plots a graph. Returns `Plots.AbstractPlot`.

*Parameters*
    graph::PowerModelsGraph{<:LightGraphs.AbstractGraph}
        Network graph
    label_nodes::Bool
        Optional. Plot labels on nodes (Default: `false`)
    label_edges::Bool
        Optional. Plot labels on edges (Default: `false`)
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
    fig<:Plots.AbstractPlot
        Plots.jl figure
"""
function plot_graph(graph::PowerModelsGraph{T};
                    label_nodes=false,
                    label_edges=false,
                    fontsize=12,
                    fontfamily="Arial",
                    fontcolor=:black,
                    textalign=:center,
                    plot_size=(600,600),
                    dpi=300,
                    kwargs...) where T <: LightGraphs.AbstractGraph

    fig = Plots.plot(legend=false, xaxis=false, yaxis=false, grid=false, size=plot_size, dpi=dpi)

    nodes = Dict(node => [get_property(graph, node, :x, 0.0), get_property(graph, node, :y, 0.0)] for node in vertices(graph))
    node_keys = sort(collect(keys(nodes)))
    node_x = [nodes[node][1] for node in node_keys]
    node_y = [nodes[node][2] for node in node_keys]
    node_labels = [Plots.text(label_nodes ? get_property(graph, node, :label, "") : "", fontsize, fontcolor, textalign, fontfamily) for node in node_keys]
    node_colors = [get_property(graph, node, :node_color, :black) for node in node_keys]
    node_sizes = [get_property(graph, node, :node_size, 1) for node in node_keys]

    for edge in edges(graph)
        edge_x, edge_y = [], []
        edge_color = get_property(graph, edge, :edge_color, :black)
        edge_width = get_property(graph, edge, :edge_size, 1)
        edge_style = get_property(graph, edge, :edge_membership, "") == "connector" ? :dot : :solid
        for n in [LightGraphs.src(edge), LightGraphs.dst(edge)]
            push!(edge_x, nodes[n][1])
            push!(edge_y, nodes[n][2])
        end

        Plots.plot!(edge_x, edge_y; line=(edge_width, edge_style, edge_color))
        Plots.annotate!(mean(edge_x), mean(edge_y), Plots.text(label_edges ? get_property(graph, edge, :label, "") : "", fontsize, fontcolor, textalign, fontfamily))
    end

    Plots.scatter!(node_x, node_y; color=node_colors, markerstrokewidth=0, markersize=node_sizes, series_annotations=node_labels)

    return fig
end
