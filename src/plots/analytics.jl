"Plots branch impedances"
function plot_branch_impedance(data::Dict{String,Any}; branch_key::Any="branch", resistance_key::String="br_r", reactance_key::String="br_x")::Vega.VGSpec
    spec = deepcopy(default_branch_impedance_spec)

    scatter_data = [Dict("resistance" => sum(sum(branch["br_r"])), "reactance" => sum(sum(branch["br_x"])), "id" => id) for (id, branch) in data["branch"]]

    sort!(scatter_data; by=x -> parse(Int, x["id"]))

    @set! spec.data = []

    pushfirst!(spec.data, Dict("name" => "branch-impedances", "values" => scatter_data))

    resistance = Float64[x["resistance"] for x in scatter_data]
    reactance = Float64[x["reactance"] for x in scatter_data]

    for (field, _data) in zip(["resistance", "reactance"], [resistance, reactance])
        push!(spec.data, Dict(
            "name" => "binned-$field",
            "source" => "branch-impedances",
            "transform" => [
                Dict(
                    "type" => "bin", "field" => field,
                    "extent" => [minimum(_data), maximum(_data)],
                    "anchor" => mean(_data),
                    "step" => std(_data) / 2,
                    "nice" => true
                ),
                Dict(
                    "type" => "aggregate",
                    "key" => "bin0",
                    "groupby" => ["bin0", "bin1"],
                    "fields" => ["bin0"],
                    "ops" => ["count"],
                    "as" => ["count"]
                )
            ]
        )
        )
    end

    return spec
end


"""
    `plot_load_summary(file, result, case; kwargs...)`

    Plots total generation, total load served, and total forecasted load for a given `case` and `result`, saving to `file`

    Arguments:

    `file::String`: file path to saved figure
    `result::Dict{String,Any}`: multinetwork solution data (contains load statuses)
    `case::Dict{String,Any}`: Original case file (without calcuated loads) for forecasted loads
    `log::Bool`: If `true`, plots y-axis on log scale
    `intermediate::Bool`: If `true`, plots intermediate steps of plot (for animations).
    `legend_position::Symbol`: Position of legend, accepts the following symbols: `:right`, `:left`, `:top`, `:bottom`, `:inside`, `:best`, `:legend`, `:topright`, `:topleft`, `:bottomleft`, `:bottomright`
"""
function plot_load_summary(file::String, result::Dict{String,Any}, case::Dict{String,Any}; log::Bool=false, intermediate::Bool=false, legend_position::Symbol=:best)::Vega.VGSpec
    @assert Int(get(case, "data_model", 1)) == 1 && get(case, "per_unit", true) "This function only supports plotting MATHEMATICAL data models in per-unit representation"

    spec = Vega.loadvgspec("src/vega/load_summary.json")

    x = 0:length(result["nw"]) - 1
    generation = [x for (n, x) in sort([(parse(Int, n), sum(sum(_replace_nan(gen["pg"])) * nw["baseMVA"] for (i, gen) in nw["gen"])) for (n, nw) in result["nw"]]; by=x -> x[1])]
    storage = [x for (n, x) in sort([(parse(Int, n), sum(sum(_replace_nan(strg["ps"])) * nw["baseMVA"] for (i, strg) in nw["storage"])) for (n, nw) in result["nw"]]; by=x -> x[1])]
    total_generated = generation .+ storage
    total_load_served = [x for (n, x) in sort([(parse(Int, n), sum(sum(_replace_nan(load["status"] * case["nw"]["$n"]["load"]["$i"]["pd"])) * nw["baseMVA"] for (i, load) in nw["load"])) for (n, nw) in result["nw"]]; by=x -> x[1])]
    total_load_forecast = [x for (n, x) in sort([(parse(Int, n), sum(sum(_replace_nan(load["pd"])) * case["nw"]["$n"]["baseMVA"] for (i, load) in nw["load"])) for (n, nw) in case["nw"]]; by=x -> x[1])]

    max_digits = max_digits = maximum([length("$n") for n in x])
    @debug "" total_generated total_load_served total_load_forecast

    spec = deepcopy(default_source_demand_summary_spec)

    power_summary_data = [
        Dict(
            "x" => x[i],
            "y" => y[i],
            "c" => c - 1,
        ) for (c, y) in enumerate([total_generated, total_load_served, total_load_forecast]) for i in 1:length(x)
    ]

    @set! spec.data = [
        Dict(
            "name" => "table",
            "values" => power_summary_data,
            "transform" => [
                Dict(
                    "type" => "stack",
                    "groupby" => ["x"],
                    "sort" => Dict(
                        "field" => "c"
                    ),
                    "field" => "y"
                )
            ]
        )
    ]

    @set! spec.axes[2]["title"] = "Power (MW)"

    if log
        @set! spec.scales[2]["type"] = "log"
    end

    if intermediate
        _tmp_data = []
        for (i, _data) in enumerate(eachrow(reshape(power_summary_data, :, 3)))
            append!(_tmp_data, _data)
            @set! spec.data = [
                Dict(
                    "name" => "table",
                    "values" => _tmp_data,
                    "transform" => [
                        Dict(
                            "type" => "stack",
                            "groupby" => ["x"],
                            "sort" => Dict(
                                "field" => "c"
                            ),
                            "field" => "y"
                        )
                    ]
                )
            ]

            filename_parts = split(file, ".")
            filename = join(filename_parts[1:end-1], ".")
            ext = filename_parts[end]

            _fileout = "$(filename)_$(lpad(i, max_digits, "0")).$(ext)"

            Vega.save(_fileout, spec)
        end
    else
        Vega.save(file, spec)
    end

    return spec
end


"""
    `plot_source_demand_summary(file::String, mn_case::Dict{String,<:Any}; kwargs...)`

    Plots the total delivery from sources (generation) and total receipts by demands (load)

    Arguments:

    `fileout::String`: path to file where plot will be saved
    `mn_case::Dict{String,<:Any}`: a multinetwork case
    `yscale::Symbol`: To set log scale, `:log10`, else `:identity`
    `save_intermediate_frames::Bool`: if `true`, each frame of the multinetwork will be saved separately
    `legend_position::Symbol`: Position of legend, accepts the following symbols: `:right`, `:left`, `:top`, `:bottom`, `:inside`, `:best`, `:legend`, `:topright`, `:topleft`, `:bottomleft`, `:bottomright`
    `sources::Dict{String,<:Any}`: information about sources (e.g. generators)
    `demands::Dict{String,<:Any}`: information about demands (e.g. loads)
    `totals::Symbol`: Choose `:real`, `:imaginary`, `:complex`
"""
function plot_source_demand_summary(fileout::String, mn_case::Dict{String,<:Any};
    yscale::Symbol=:identity,
    save_intermediate_frames::Bool=false,
    legend_position::Symbol=:best,
    sources::Dict{String,<:Any}=default_sources_eng,
    demands::Dict{String,<:Any}=default_demands_eng,
    totals::Symbol=:real,
    )::Vega.VGSpec

    x = 1:length(mn_case["nw"])
    total_generated = Vector{Real}(undef, length(x))

    for (n, nw) in get(mn_case, "nw", Dict())
        value = Complex(0.0, 0.0)

        for (type, settings) in sources
            real_key = get(settings, "inactive_real", "" => 0)[1]
            imag_key = get(settings, "inactive_imaginary", "" => 0)[1]

            for (_,obj) in get(nw, type, Dict())
                if totals == :real
                    v_real = get(obj, real_key, 0.0)
                    v_imag = 0.0
                elseif totals == :imaginary
                    v_real = 0.0
                    v_imag = get(obj, imag_key, 0.0)
                else
                    v_real = get(obj, real_key, 0.0)
                    v_imag = get(obj, imag_key, 0.0)
                end

                value += sum(Complex.(v_real, v_imag))
            end
        end

        total_generated[parse(Int, n)] = norm(value)
    end

    total_demand_served = Vector{Real}(undef, length(x))
    total_demand_forecast = Vector{Real}(undef, length(x))
    for (n, nw) in get(mn_case, "nw", Dict())
        served_value = Complex(0.0, 0.0)
        forecast_value = Complex(0.0, 0.0)

        for (type, settings) in demands
            served_real_key = get(settings, "inactive_real", "" => 0)[1]
            served_imag_key = get(settings, "inactive_imaginary", "" => 0)[1]

            forecast_real_key = get(settings, "original_demand_real", "")
            forecast_imag_key = get(settings, "original_demand_imaginary", "")

            for (_,obj) in get(nw, type, Dict())
                if totals == :real
                    v_served_real = get(obj, served_real_key, 0.0)
                    v_served_imag = 0.0
                    v_forecast_real = get(obj, forecast_real_key, 0.0)
                    v_forecast_imag = 0.0
                elseif totals == :imaginary
                    v_served_real = 0.0
                    v_served_imag = get(obj, served_imag_key, 0.0)
                    v_forecast_real = 0.0
                    v_forecast_imag = get(obj, forecast_imag_key, 0.0)
                else
                    v_served_real = get(obj, served_real_key, 0.0)
                    v_served_imag = get(obj, served_imag_key, 0.0)
                    v_forecast_real = get(obj, forecast_real_key, 0.0)
                    v_forecast_imag = get(obj, forecast_imag_key, 0.0)
                end

                served_value += sum(Complex.(v_served_real, v_served_imag))
                forecast_value += sum(Complex.(v_forecast_real, v_forecast_imag))
            end
        end

        total_demand_served[parse(Int, n)] = norm(served_value)
        total_demand_forecast[parse(Int, n)] = norm(forecast_value)
    end

    max_digits = maximum([length(n) for (n,_) in mn_case["nw"]])

    power_scale_factor = mn_case["settings"]["power_scale_factor"]
    units_str = power_scale_factor == 1.0 ? "W" : power_scale_factor == 1e3 ? "kW" : power_scale_factor == 1e6 ? "MW" : "$power_scale_factor W"

    spec = deepcopy(default_source_demand_summary_spec)

    power_summary_data = [
        Dict(
            "x" => x[i],
            "y" => y[i],
            "c" => c - 1,
        ) for (c, y) in enumerate([total_generated, total_demand_served, total_demand_forecast]) for i in 1:length(x)
    ]

    @set! spec.data = [
        Dict(
            "name" => "table",
            "values" => power_summary_data,
            "transform" => [
                Dict(
                    "type" => "stack",
                    "groupby" => ["x"],
                    "sort" => Dict("field" => "c"),
                    "field" => "y"
                )
            ]
        )
    ]

    @set! spec.axes[2]["title"] = "Power ($units_str)"

    if save_intermediate_frames
        _tmp_data = []
        for (i, _data) in enumerate(eachrow(reshape(power_summary_data, :, 3)))
            append!(_tmp_data, _data)
            @set! spec.data = [
                Dict(
                    "name" => "table",
                    "values" => _tmp_data,
                    "transform" => [
                        Dict(
                            "type" => "stack",
                            "groupby" => ["x"],
                            "sort" => Dict("field" => "c"),
                            "field" => "y"
                        )
                    ]
                )
            ]

            filename_parts = split(fileout, ".")
            filename = join(filename_parts[1:end-1], ".")
            ext = filename_parts[end]

            _fileout = "$(filename)_$(lpad(i, max_digits, "0")).$(ext)"

            Vega.save(_fileout, spec)
        end
    else
        Vega.save(fileout, spec)
    end

    return spec
end
