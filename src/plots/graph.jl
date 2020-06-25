"""
    `fig = plot_graph(graph::InfrastructureGraph; kwargs...)`

    Plots a graph. Returns `Plots.AbstractPlot`.

    Arguments:

    `graph::InfrastructureGraph{<:LightGraphs.AbstractGraph}`: Network graph
    `label_nodes::Bool`: Plot labels on nodes
    `label_edges::Bool`: Plot labels on edges
    `fontsize::Real`: Fontsize of labels
    `fontfamily::String`: Font Family of labels
    `fontcolor::Union{Symbol,<:Colors.Colorant}`: Color of the labels
    `textalign::Symbol`: Alignment of text
    `plot_size::Tuple{Int,Int}`: Size of the plot in pixels
    `plot_dpi::Int`: Dots-per-inch of the plot

    Returns:

    `fig<:Plots.AbstractPlot`: Plots.jl figure
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

    fig = Plots.plot(legend=false, xaxis=false, yaxis=false, grid=false, size=plot_size, dpi=plot_dpi)

    nodes = Dict(node => [get_property(graph, node, :x, 0.0), get_property(graph, node, :y, 0.0)] for node in vertices(graph))
    node_keys = sort(collect(keys(nodes)))
    node_x = [nodes[node][1] for node in node_keys]
    node_y = [nodes[node][2] for node in node_keys]
    node_labels = [Plots.text(label_nodes || hasprop(graph, node, :force_label) ? get_property(graph, node, :label, "") : "", fontsize, fontcolor, textalign, fontfamily) for node in node_keys]
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
