"Default plot colors, including all supported component variations"
const default_colors = Dict{String,Colors.Colorant}(
    "enabled open free edge" => colorant"gold",
    "enabled open fixed edge" => colorant"red",
    "enabled closed free edge" => colorant"green",
    "enabled closed fixed edge" => colorant"black",
    "disabled open fixed edge" => colorant"orange",
    "disabled open free edge" => colorant"orange",
    "disabled closed fixed edge" => colorant"orange",
    "disabled closed free edge" => colorant"orange",
    "connector" => colorant"lightgrey",

    "enabled active extra node" => colorant"cyan",
    "enabled inactive extra node" => colorant"orange",
    "disabled inactive extra node" => colorant"red",
    "disabled active extra node" => colorant"red",

    "enabled node wo demand" => colorant"darkgrey",
    "disabled node wo demand" => colorant"grey95",
    "enabled node w demand" => colorant"green3",
    "disabled node w demand" => colorant"gold",
)

"default color range for partially loaded buses"
const default_demand_color_range = Colors.range(default_colors["disabled node w demand"], default_colors["enabled node w demand"], length=11)

"default edge types for eng data structure"
const default_edge_settings_eng = Dict{String,Any}(
    "line" => Dict{String,Any}(
        "fr_node" => "f_bus",
        "to_node" => "t_bus",
        "disabled" => "status" => 0,
    ),
    "transformer" => Dict{String,Any}(
        "fr_node" => "f_bus",
        "to_node" => "t_bus",
        "nodes" => "bus",
        "disabled" => "status" => 0,
    ),
    "switch" => Dict{String,Any}(
        "fr_node" => "f_bus",
        "to_node" => "t_bus",
        "disabled" => "status" => 0,
        "open" => "state" => 0,
        "dispatchable" => "dispatchable" => 1,
    )
)

"default edge types for math data structure (PowerModels, PowerModelsDistribution"
const default_edge_settings_math = Dict{String,Any}(
    "branch" => Dict{String,Any}(
        "fr_node" => "f_bus",
        "to_node" => "t_bus",
        "disabled" => "br_status" => 0,
    ),
    "transformer" => Dict{String,Any}(
        "fr_node" => "f_bus",
        "to_node" => "t_bus",
        "disabled" => "br_status" => 0,
    ),
    "dcline" => Dict{String,Any}(
        "fr_node" => "f_bus",
        "to_node" => "t_bus",
        "disabled" => "br_status" => 0,
    ),
    "switch" => Dict{String,Any}(
        "fr_node" => "f_bus",
        "to_node" => "t_bus",
        "disabled" => "status" => 0,
    )
)

"default edge type between blocks (PowerModels, PowerModelsDistribution"
const default_block_connectors = Dict{String,Any}(
    "switch" => Dict{String,Any}(
        "fr_node" => "f_bus",
        "to_node" => "t_bus",
        "disabled" => "status" => 0,
    ),
)

"default node object to plot for eng data structure (PowerModelsDistribution)"
const default_extra_nodes_eng = Dict{String,Any}(
    "generator" => Dict{String,Any}(
        "node" => "bus",
        "label" => "~",
        "size" => "pg",
        "inactive_real" => "pg" => 0,
        "inactive_imaginary" => "qg" => 0,
    ),
    "solar" => Dict{String,Any}(
        "node" => "bus",
        "label" => "!",
        "size" => "pg",
        "inactive_real" => "pg" => 0,
        "inactive_imaginary" => "qg" => 0,
    ),
    "storage" => Dict{String,Any}(
        "node" => "bus",
        "label" => "S",
        "size" => "ps",
        "inactive_real" => "ps" => 0,
        "inactive_imaginary" => "qs" => 0,
    ),
    "voltage_source" => Dict{String,Any}(
        "node" => "bus",
        "label" => "V",
        "size" => "pg",
        "inactive_real" => "pg" => 0,
        "inactive_imaginary" => "qg" => 0,
    )
)

"default node object to plot for math data structure (PowerModels, PowerModelsDistribution)"
const default_extra_nodes_math = Dict{String,Any}(
    "gen" => Dict{String,Any}(
        "node" => "gen_bus",
        "label" => "~",
        "size" => "pg",
        "inactive_real" => "pg" => 0,
        "inactive_imaginary" => "qg" => 0
    ),
    "storage" => Dict{String,Any}(
        "node" => "storage_bus",
        "label" => "S",
        "size" => "ps",
        "inactive_real" => "ps",
        "inactive_imaginary" => "qs"
    )
)

"default node information for math model (PowerModels, PowerModelsDistribution)"
const default_node_settings_math = Dict{String,Any}(
    "node" => "bus",
    "disabled" => "bus_type" => 4,
    "x" => "lon",
    "y" => "lat",
)

"default node information for eng model (PowerModelsDistribution)"
const default_node_settings_eng = Dict{String,Any}(
    "node" => "bus",
    "disabled" => "status" => 0,
    "x" => "lon",
    "y" => "lat"
)

"default sources (generators) for the math model (PowerModels,PowerModelsDistribution)"
const default_sources_math = Dict{String,Any}(
    "gen" => Dict{String,Any}(
        "node" => "gen_bus",
        "disabled" => "gen_status" => 0,
        "inactive_real" => "pg" => 0,
        "inactive_imaginary" => "qg" => 0,
    ),
    "storage" => Dict{String,Any}(
        "node" => "storage_bus",
        "disabled" => "storage_status" => 0,
        "inactive_real" => "ps" => 0,
        "inactive_imaginary" => "qs" => 0,
    )
)

"default sources (generators) for the eng model (PowerModelsDistribution)"
const default_sources_eng = Dict{String,Any}(
    "generator" => Dict{String,Any}(
        "node" => "bus",
        "disabled" => "status" => 0,
        "inactive_real" => "pg" => 0,
        "inactive_imaginary" => "qg" => 0,
    ),
    "storage" => Dict{String,Any}(
        "node" => "bus",
        "disabled" => "status" => 0,
        "inactive_real" => "ps" => 0,
        "inactive_imaginary" => "qs" => 0,
    ),
    "solar" => Dict{String,Any}(
        "node" => "bus",
        "disabled" => "status" => 0,
        "inactive_real" => "pg" => 0,
        "inactive_imaginary" => "pg" => 0,
    ),
    "voltage_source" => Dict{String,Any}(
        "node" => "bus",
        "disabled" => "status" => 0,
        "inactive_real" => "pg" => 0,
        "inactive_imaginary" => "pg" => 0,
    ),
)

"default demands (loads) for eng model (PowerModelsDistribution)"
const default_demands_eng = Dict{String,Any}(
    "load" => Dict{String,Any}(
        "node" => "bus",
        "disabled" => "status" => 0,
        "inactive_real" => "pd" => 0,
        "inactive_imaginary" => "qd" => 0,
        "original_demand_real" => "pd_nom",
        "original_demand_imaginary" => "qd_nom",
        "status" => "status"
    )
)

"default demands (loads) for math model (PowerModels, PowerModelsDistribution)"
const default_demands_math = Dict{String,Any}(
    "load" => Dict{String,Any}(
        "node" => "load_bus",
        "disabled" => "load_status" => 0,
        "inactive_real" => "pd" => 0,
        "inactive_imaginary" => "qd" => 0,
        "status" => "load_status"
    )
)

"default dpi of plots"
const default_plot_dpi = 100

"default size of plots in pixels"
const default_plot_size = Tuple{Int,Int}((300,300))

"default fontsize in pt"
const default_fontsize = 10

"default fontcolor"
const default_fontcolor = :black

"default fontfamily"
const default_fontfamily = "Times"

"default text alignemtn"
const default_textalign = :center

"default upper and lower bound of the size of nodes"
const default_node_size_limits = Vector{Real}([2, 2.5])

"default upper and lower bound of the width of edges"
const default_edge_width_limits = Vector{Real}([0.5, 0.75])

"default spring constant for spring_layout"
const default_spring_constant = 0.2
