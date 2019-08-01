# PowerModelsAnalytics.jl

Tools for the analysis and visualization of PowerModels data and results.

**BETA / IN ACTIVE DEVELOPMENT: Features will change quickly and without warning**

## Backends for Plotting

This package relies on Plots.jl for plotting, so you must choose an appropriate backend for the style of plot you desire. See the Plots.jl [Documentation](http://docs.juliaplots.org/latest/install/) for additional information.

### Creating a PDF backend for `plot_network`

The `plot_network` function currently operates slightly different than other functions, because it currently relies on GraphPlot.jl. In order to plot with this function, a backend must be created separately and passed as an argument to the function:

```julia
import Cairo, Fontconfig
using Compose

backend = Compose.PDF("test.pdf", 10cm, 10cm)

plot_network(network_case, backend)
```

## License

This code is provided under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project, LA-CC-13-108.
