# pynx = PyCall.pyimport_conda("networkx", "networkx")

function kamada_kawai_layout(graph; dist=nothing, pos=nothing, weight="weight", scale=1.0, center=nothing, dim=2)
    G = nx.Graph()
    for edge in MetaGraphs.edges(graph)
        G.add_edge(edge.src, edge.dst)
    end
    for node in MetaGraphs.vertices(graph)
        G.add_node(node)
    end

    positions = nx.kamada_kawai_layout(G, dist=dist, pos=pos, weight=weight, scale=scale, center=center, dim=dim)

    loc_x = [-positions[n][2] for n in 1:length(positions)]
    loc_y = [ positions[n][1] for n in 1:length(positions)]

    return [loc_x, loc_y]
end


function spring_layout(graph; k=nothing, pos=nothing, fixed=nothing, iterations=50, threshold=0.0001, weight="weight", scale=1, center=nothing, dim=2, seed=nothing)
    G = nx.Graph()
    for edge in MetaGraphs.edges(graph)
        G.add_edge(edge.src, edge.dst)
    end

    for node in MetaGraphs.vertices(graph)
        G.add_node(node)
    end

    positions = nx.spring_layout(G, k=k, pos=pos, fixed=fixed, iterations=iterations, threshold=threshold, weight=weight, scale=scale, center=center, dim=dim, seed=seed)
    loc_x = [positions[n][2] for n in sort(collect(keys(positions)))]
    loc_y = [positions[n][1] for n in sort(collect(keys(positions)))]

    return [loc_x, loc_y]
end
