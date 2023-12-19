# PowerModelsAnalytics.jl

![CI](https://github.com/lanl-ansi/PowerModelsAnalytics.jl/workflows/CI/badge.svg) ![Documentation](https://github.com/lanl-ansi/PowerModelsAnalytics.jl/workflows/Documentation/badge.svg)

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

will save a network plot to a file using Vega.jl.

## Plotting

This package relies on Vega.jl for plotting. See the Vega [Documentation](https://vega.github.io/) for additional information about how to build new Specifications.

## License

This code is provided under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project, C15024.
