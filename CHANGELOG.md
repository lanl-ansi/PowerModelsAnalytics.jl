# PowerModelsAnalytics.jl Change Log

## staged

- none

## v0.3.0

- Makes `build_network_graph` more agnostic to type of Infrastructure network being graphed
- Rename `build_graph_network` to `build_network_graph`
- Changes kwargs in functions
- Moves kwarg defaults to `src/core/options.jl`, and changes color defaults
- Changes type from `PowerModelsGraph` to `InfrastructureGraph`
- Removes `plot_load_blocks` and `build_graph_load_blocks` in favor of using kwarg `block_graph=true`

## v0.2.2

- Add additional compatible versions to dependencies
- Fix type enforcement for `load_color_range` (#8)

## v0.2.1

- Fix dependency issue for Julia < v1.3 of SpecialFunctions in Manifest.toml

## v0.2.0

- Support PowerModels v0.13 and PowerModelsDistribution v0.6.0

## v0.1.0

- Initial release with basic plotting tools and graph creation
