module PowerModelsAnalytics

    import InfrastructureModels
    import PowerModels
    import Plots
    import Memento

    import MetaGraphs
    import GraphPlot

    import Colors
    import Colors: @colorant_str
    import ColorVectorSpace
    import FixedPointNumbers

    import Compose

    import Statistics: mean, std
    import Random: rand

    import PyCall

    # Create our module level logger
    const LOGGER = Memento.getlogger(@__MODULE__)

    const nx = PyCall.PyNULL()
    const scipy = PyCall.PyNULL()

    function __init__()
        Memento.register(LOGGER)

        copy!(nx, PyCall.pyimport_conda("networkx", "networkx"))
        copy!(scipy, PyCall.pyimport_conda("scipy", "scipy"))
    end

    include("core/layouts.jl")
    include("core/parameters.jl")
    include("core/plots.jl")

    include("graph/metrics.jl")

    include("core/export.jl")

end


