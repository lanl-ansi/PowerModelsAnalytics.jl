module PowerModelsAnalytics
    import LightGraphs

    import Vega
    import Setfield: @set!
    import Colors
    import Colors: @colorant_str
    import ColorVectorSpace

    import LinearAlgebra: norm
    import Random: rand
    import Statistics: mean, std

    import Compat: isnothing

    import PyCall

    const nx = PyCall.PyNULL()
    const scipy = PyCall.PyNULL()

    function __init__()
        copy!(nx, PyCall.pyimport_conda("networkx", "networkx"))
        copy!(scipy, PyCall.pyimport_conda("scipy", "scipy"))
    end

    include("core/types.jl")  # must be first to properly define new types
    include("core/options.jl")

    include("core/data.jl")
    include("core/parameters.jl")

    include("vega/default_specs.jl")

    include("graph/common.jl")
    include("graph/metrics.jl")

    include("layouts/common.jl")
    include("layouts/networkx.jl")

    include("plots/graph.jl")
    include("plots/analytics.jl")
    include("plots/networks.jl")

    include("core/export.jl")  # must be last to properly export all functions
end
