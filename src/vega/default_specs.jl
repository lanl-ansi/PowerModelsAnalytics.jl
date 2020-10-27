"Vega spec for network graph plot (base)"
const default_network_graph_spec = Vega.loadvgspec(joinpath(dirname(pathof(PowerModelsAnalytics)), "vega", "network_graph.json"))

"Vega spec for extension to network graph spec for labeling nodes"
const default_node_label_spec = Vega.loadvgspec(joinpath(dirname(pathof(PowerModelsAnalytics)), "vega", "node_labels.json"))

"Vega spec for extension to network graph spec for labeling edges"
const default_edge_label_spec = Vega.loadvgspec(joinpath(dirname(pathof(PowerModelsAnalytics)), "vega", "edge_labels.json"))

"Vega spec for branch impedance plot"
const default_branch_impedance_spec = Vega.loadvgspec(joinpath(dirname(pathof(PowerModelsAnalytics)), "vega", "branch_impedance.json"))

"Vega spec for Source Demand Summary Plot"
const default_source_demand_summary_spec = Vega.loadvgspec(joinpath(dirname(pathof(PowerModelsAnalytics)), "vega", "source_demand_summary.json"))
