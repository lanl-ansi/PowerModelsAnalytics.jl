""
function layout_graph!(graph::PowerModelsGraph{T}, layout_engine=kamada_kawai_layout;
                       use_buscoords::Bool=false,
                       apply_spring_layout::Bool=false,
                       spring_const::Float64=1e-3) where T <: LightGraphs.AbstractGraph
    if use_buscoords
        pos = Dict(node => get_property(graph, node, :buscoord, missing) for node in vertices(graph))
        fixed = [node for (node, p) in pos if !ismissing(p)]

        avg_x, avg_y = mean(hcat(skipmissing([v for v in values(pos)])...), dims=2)
        std_x, std_y = std(hcat(skipmissing([v for v in values(pos)])...), dims=2)
        for (v, p) in pos
            if ismissing(p)
                pos[v] = [avg_x+std_x*rand(), avg_y+std_y*rand()]
            end
        end
        positions = spring_layout(graph; pos=pos, fixed=fixed, k=spring_const*minimum(std([p for p in values(pos)])), iterations=100)
    else
        positions = layout_engine(graph)
        if apply_spring_layout
            positions = spring_layout(graph; pos=positions, k=spring_const*minimum(std([p for p in values(positions)])), iterations=100)
        end
    end

    for (node, (x, y)) in positions
        set_property!(graph, node, :x, x)
        set_property!(graph, node, :y, y)
    end
end
