"NetworkX Kamada-Kawai layout function"
function kamada_kawai_layout(graph::InfrastructureGraph{T}; dist=nothing, pos=nothing, weight="weight", scale=1.0, center=nothing, dim=2) where T <: LightGraphs.AbstractGraph
    G = nx.Graph()
    for edge in edges(graph)
        G.add_edge(edge.src, edge.dst)
    end
    for node in vertices(graph)
        G.add_node(node)
    end

    positions = nx.kamada_kawai_layout(G, dist=dist, pos=pos, weight=weight, scale=scale, center=center, dim=dim)

    return positions
end


"NetworkX spring layout function"
function spring_layout(graph::InfrastructureGraph{T}; k=nothing, pos=nothing, fixed=nothing, iterations=50, threshold=0.0001, weight="weight", scale=1, center=nothing, dim=2, seed=nothing) where T <: LightGraphs.AbstractGraph
    G = nx.Graph()
    for edge in edges(graph)
        G.add_edge(edge.src, edge.dst)
    end

    for node in vertices(graph)
        G.add_node(node)
    end

    positions = nx.spring_layout(G, k=k, pos=pos, fixed=fixed, iterations=iterations, threshold=threshold, weight=weight, scale=scale, center=center, dim=dim, seed=seed)

    return positions
end
