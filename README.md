# PowerModelsAnalytics.jl

Tools for the analysis and visualization of PowerModels data and results.

**BETA / IN ACTIVE DEVELOPMENT**: Features will change quickly and without warning

## Using PowerModelsAnalytics

To use the `plot_network` function for example, one must load a network case, e.g. using `parse_file` in PowerModels or PowerModelsDistribution, and then

```julia
using PowerModelsAnalytics

plot_network(network_case)
```

should plot the network using the currently enabled backend, or e.g.

```julia
plot_network(network_case; filename="network.pdf")
```

will save a network plot to a file using the current backend enabled for Plots.jl, as noted in the following section.

## Backends for Plotting

This package relies on Plots.jl for plotting, so you must choose an appropriate backend for the style of plot you desire. See the Plots.jl [Documentation](http://docs.juliaplots.org/latest/install/) for additional information.

## License

This code is provided under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project, LA-CC-13-108.
