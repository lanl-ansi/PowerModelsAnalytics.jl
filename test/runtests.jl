using PowerModelsAnalytics

import PowerModels
import LightGraphs
import Colors

PowerModels.silence()

using Test

@testset "PowerModelsAnalytics" begin
    data = PowerModels.parse_file("$(joinpath(dirname(pathof(PowerModels)), ".."))/test/data/matpower/case5.m")

    mp_data = PowerModels.parse_file("$(joinpath(dirname(pathof(PowerModels)), ".."))/test/data/matpower/case5.m")
    PowerModels.make_multiconductor!(mp_data, 3)

    n_graph = build_graph_network(data)
    n_graph_load_colors = build_graph_network(data)
    n_mp_graph = build_graph_network(mp_data)
    lb_graph = build_graph_load_blocks(data)
    lb_mp_graph = build_graph_load_blocks(data)


    @testset "graphs" begin
        for graph in [n_graph, n_mp_graph, lb_graph, lb_mp_graph]
            @test isa(graph, PowerModelsGraph{T} where T<:LightGraphs.AbstractGraph)
        end

        apply_plot_network_metadata!(n_graph)
        @test all(hasprop(n_graph, node, :node_color) && hasprop(n_graph, node, :node_size) for node in vertices(n_graph))
        @test all(hasprop(n_graph, edge, :edge_color) && hasprop(n_graph, edge, :edge_size) for edge in edges(n_graph))

        @testset "load_color_range" begin
            load_color_range = Colors.range(default_colors["loaded disabled bus"], default_colors["loaded enabled bus"], length=11)
            @test_nowarn apply_plot_network_metadata!(n_graph_load_colors; load_color_range=load_color_range)
        end
    end

    @testset "layout" begin
        layout_graph!(n_graph, kamada_kawai_layout)
        layout_graph!(n_mp_graph, spring_layout)

        @test all(hasprop(n_graph, node, :x) && hasprop(n_graph, node, :y) for node in vertices(n_graph))
        @test all(hasprop(n_mp_graph, node, :x) && hasprop(n_mp_graph, node, :y) for node in vertices(n_mp_graph))
    end

    @testset "plot" begin

    end

end