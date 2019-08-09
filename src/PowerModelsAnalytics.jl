module PowerModelsAnalytics

    import InfrastructureModels
    import PowerModels

    import LightGraphs

    import Plots
    import Colors
    import Colors: @colorant_str
    import ColorVectorSpace

    import Statistics: mean, std
    import Random: rand

    import PyCall

    const nx = PyCall.PyNULL()
    const scipy = PyCall.PyNULL()

    function __init__()
        copy!(nx, PyCall.pyimport_conda("networkx", "networkx"))
        copy!(scipy, PyCall.pyimport_conda("scipy", "scipy"))
    end

    include("core/types.jl")  # must be first to properly define new types

    include("core/data.jl")
    include("core/parameters.jl")
    include("core/options.jl")

    include("graph/common.jl")
    include("graph/metrics.jl")

    include("layouts/common.jl")
    include("layouts/networkx.jl")

    include("plots/graph.jl")
    include("plots/analytics.jl")
    include("plots/networks.jl")

    include("core/export.jl")  # must be last to properly export all functions
end
