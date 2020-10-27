"""
    `layout_graph!(graph::InfrastructureGraph, layout_engine::Function; kwargs...)`

    A routine to assign positions to all nodes of a `graph` for plotting using `layout_engine`.
    Positions are assigned to the metadata of each node at `:x` and `:y`.

    Arguments:

    `graph::InfrastructureGraph`: Network graph
    `layout_engine`: Layout Function to use. Applies only when not using `use_coordinates`
    `use_coordinates::Bool`: If `true`, `spring_layout` will be used instead of `layout_engine`
    `apply_spring_layout::Bool`: If `true`, `spring_layout` will be applied after `layout_engine` to ensure separation of overlapping nodes
    `spring_constant::Real`: Spring constant to be used by `spring_layout`
    `kwargs`: Keyword arguments to be used in `layout_engine`
"""
function layout_graph!(graph::InfrastructureGraph{T}, layout_engine::Function=kamada_kawai_layout;
                       use_coordinates::Bool=false,
                       apply_spring_layout::Bool=false,
                       spring_constant::Real=default_spring_constant,
                       kwargs...) where T <: LightGraphs.AbstractGraph
    if use_coordinates
        pos = Dict{Int,Union{Missing,Vector{Real}}}(node => get_property(graph, node, :coordinate, missing) for node in vertices(graph))
        fixed = [node for (node, p) in pos if !ismissing(p)]

        avg_x, avg_y = mean(hcat(skipmissing([v for v in values(pos)])...), dims=2)
        std_x, std_y = std(hcat(skipmissing([v for v in values(pos)])...), dims=2)
        for (v, p) in pos
            if ismissing(p)
                pos[v] = [avg_x+std_x*rand(), avg_y+std_y*rand()]
            end
        end
        positions = spring_layout(graph; pos=pos, fixed=fixed, k=spring_constant*sqrt(length(pos)), iterations=100)
    else
        positions = layout_engine(graph; kwargs...)
        if apply_spring_layout
            positions = spring_layout(graph; pos=positions, k=spring_constant*sqrt(length(positions)), iterations=100)
        end
    end

    for (node, (x, y)) in positions
        set_property!(graph, node, :x, x)
        set_property!(graph, node, :y, y)
    end
end
