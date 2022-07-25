using PowerModelsAnalytics

import LightGraphs
import Colors

import PowerModels
import PowerModelsDistribution

PowerModels.silence()

using Test

@testset "PowerModelsAnalytics" begin
    data = PowerModels.parse_file("$(joinpath(dirname(pathof(PowerModels)), ".."))/test/data/matpower/case5.m")

    mp_data = PowerModels.parse_file("$(joinpath(dirname(pathof(PowerModels)), ".."))/test/data/matpower/case5.m")
    PowerModelsDistribution.make_multiconductor!(mp_data, 3)

    n_graph = build_network_graph(data)
    n_graph_load_colors = build_network_graph(data)
    n_mp_graph = build_network_graph(mp_data)
    lb_graph = build_network_graph(data; block_graph=true)
    lb_mp_graph = build_network_graph(data; block_graph=true)


    @testset "graphs" begin
        for graph in [n_graph, n_mp_graph, lb_graph, lb_mp_graph]
            @test isa(graph, InfrastructureGraph{T} where T<:LightGraphs.AbstractGraph)
        end

        apply_plot_network_metadata!(n_graph)
        @test all(hasprop(n_graph, node, :node_color) && hasprop(n_graph, node, :node_size) for node in vertices(n_graph))
        @test all(hasprop(n_graph, edge, :edge_color) && hasprop(n_graph, edge, :edge_size) for edge in edges(n_graph))

        @testset "load_color_range" begin
            load_color_range = Colors.range(default_colors["disabled node w demand"], default_colors["enabled node w demand"], length=11)
            @test_nowarn apply_plot_network_metadata!(n_graph_load_colors; demand_color_range=load_color_range)
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

    @testset "identify_blocks" begin
        node_settings = Dict{String,Any}(
            "node" => "bus",
                "disabled" => "status" => 0,  # changed to status from bus_type
                "x" => "lon",
                "y" => "lat",
        )
        case = PowerModels.parse_file("$(joinpath(dirname(pathof(PowerModels)), ".."))/test/data/matpower/case5.m")
        for (busid,bus) in case["bus"]  
            bus["status"] = 0 # set all nodes inactive
        end
        blocks = identify_blocks(case; node_settings)

        @test isempty(blocks)  # no active nodes, should be no blocks in network
    end

end