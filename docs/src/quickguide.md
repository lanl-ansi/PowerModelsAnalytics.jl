# Quick Start Guide
Once PowerModelsAnalytics.jl is installed, Plots.jl is installed, and a Plots.jl backend is installed (we will use Plotly, which is included in Plots.jl, for this guide), and a network data file (e.g. `case5.m"` in the PowerModels.jl package folder under `./test/data/matpower`) has been acquired, the network can be plotted with,

```julia
using PowerModels, PowerModelsAnalytics
using Plots
plotly()

data = PowerModels.parse_file("$(joinpath(dirname(pathof(PowerModels)), ".."))/test/data/matpower/case5.m")
plot_network(data)
```
