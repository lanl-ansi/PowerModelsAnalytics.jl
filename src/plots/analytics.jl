""
function plot_branch_impedance(data::Dict{String,Any})
    r = [branch["br_r"] for (i,branch) in data["branch"]]
    x = [branch["br_x"] for (i,branch) in data["branch"]]

    s = Plots.scatter(r, x, xlabel="resistance (p.u.)", ylabel="reactance (p.u.)", label="")
    r_h = Plots.histogram(r, xlabel="resistance (p.u.)", ylabel="branch count", label="", reuse=false)
    x_h = Plots.histogram(x, xlabel="reactance (p.u.)", ylabel="branch count", label="", reuse=false)
end


"""
    plot_load_summary(file, result, case; kwargs...)

Plots total generation, total load served, and total forecasted load for a given `case` and `result`, saving to `file`

# Parameters

* `file::String`

    file path to saved figure

* `result::Dict{String,Any}`

    multinetwork solution data (contains load statuses)

* `case::Dict{String,Any}`

    Original case file (without calcuated loads) for forecasted loads

* `log::Bool`

    Default: `false`. If true, plots y-axis on log scale

* `intermediate::Bool`

    Default: `false`. If true, plots intermediate steps of plot (for animations).

* `legend_position::Symbol`

    Default: `:best`. Position of legend, accepts the following symbols: `:right`, `:left`, `:top`, `:bottom`, `:inside`,
    `:best`, `:legend`, `:topright`, `:topleft`, `:bottomleft`, `:bottomright`
"""
function plot_load_summary(file::String, result::Dict{String,Any}, case::Dict{String,Any};
                           log::Bool=false,
                           intermediate::Bool=false,
                           legend_position::Symbol=:best)
    x = 0:length(result["nw"])-1
    generation = [x for (n, x) in sort([(parse(Int, n), sum(sum(_replace_nan(gen["pg"]))*nw["baseMVA"] for (i, gen) in nw["gen"])) for (n, nw) in result["nw"]]; by=x->x[1])]
    storage = [x for (n, x) in sort([(parse(Int, n), sum(sum(_replace_nan(strg["ps"]))*nw["baseMVA"] for (i, strg) in nw["storage"])) for (n, nw) in result["nw"]]; by=x->x[1])]
    total_generated = generation .+ storage
    total_load_served = [x for (n, x) in sort([(parse(Int, n), sum(sum(_replace_nan(load["status"]*case["nw"]["$n"]["load"]["$i"]["pd"]))*nw["baseMVA"] for (i, load) in nw["load"])) for (n, nw) in result["nw"]]; by=x->x[1])]
    total_load_forecast = [x for (n, x) in sort([(parse(Int, n), sum(sum(_replace_nan(load["pd"]))*case["nw"]["$n"]["baseMVA"] for (i, load) in nw["load"])) for (n, nw) in case["nw"]]; by=x->x[1])]

    @debug "" total_generated total_load_served total_load_forecast

    if intermediate
        for i in x
            Plots.plot(x[1:i+1], total_generated[1:i+1], label="Total Generation", legend=legend_position, xlims=[x[1], x[end]])
            Plots.plot!(x[1:i+1], total_load_served[1:i+1], label="Total Load Served", legend=legend_position)
            Plots.plot!(x[1:i+1], total_load_forecast[1:i+1], label="Total Load Forecasted", legend=legend_position)

            Plots.xaxis!("Step")
            if log
                Plots.yaxis!("Power (MW)", :log10)
            else
                Plots.yaxis!("Power (MW)")
            end

            filename_parts = split(file, ".")
            filename = join(filename_parts[1:end-1], ".")
            ext = filename_parts[end]

            fileout = "$(filename)_$(lpad(i, Int(ceil(log10(length(x)))), "0")).$(ext)"

            Plots.savefig(fileout)
        end
    end

    Plots.plot(x, total_generated, label="Total Generation", legend=:bottomright)
    Plots.plot!(x, total_load_served, label="Total Load Served", legend=:bottomright)
    Plots.plot!(x, total_load_forecast, label="Total Load Forecasted", legend=:bottomright)

    Plots.xaxis!("Step")
    if log
        Plots.yaxis!("Power (MW)", :log10)
    else
        Plots.yaxis!("Power (MW)")
    end

    Plots.savefig(file)
end


""
function plot_load_summary(file::String, mn_case::Dict{String,<:Any}; log_scale::Bool=false, plot_intermediate_frames::Bool=false, legend_position::Symbol=:best, generators::Dict{String,<:String}=Dict{String,String}("generator"=>"pg", "solar"=>"pg", "voltage_source"=>"pg","storage"=>"ps"))
    @assert Int(get(mn_case, "data_model", 1)) == 0

    x = 1:length(mn_case["nw"])
    total_generated = [sum(sum(get(gen_obj, gen_key, 0.0)) for (gen_type, gen_key) in generators for (_,gen_obj) in get(mn_case["nw"]["$i"], gen_type, Dict())) for i in x]
    total_load_served = [sum(sum(get(load, "pd", 0.0)) for (_,load) in get(mn_case["nw"]["$i"], "load", Dict())) for i in x]
    total_load_forecast = [sum(sum(get(load, "pd_nom", 0.0)) for (_,load) in get(mn_case["nw"]["$i"], "load", Dict())) for i in x]

    max_digits = maximum([length(n) for (n,_) in mn_case["nw"]])

    power_scale_factor = mn_case["settings"]["power_scale_factor"]
    units_str = power_scale_factor == 1.0 ? "W" : power_scale_factor == 1e3 ? "kW" : power_scale_factor == 1e6 ? "MW" : "$power_scale_factor W"

    if plot_intermediate_frames
        for i in x
            Plots.plot(x[1:i], total_generated[1:i], label="Total Generation", legend=legend_position, xlims=[x[1], x[end]])
            Plots.plot!(x[1:i], total_load_served[1:i], label="Total Load Served", legend=legend_position)
            Plots.plot!(x[1:i], total_load_forecast[1:i], label="Total Load Forecasted", legend=legend_position)

            Plots.xaxis!("Step")
            if log_scale
                Plots.yaxis!("Power ($units_str)", :log10)
            else
                Plots.yaxis!("Power ($units_str)")
            end

            filename_parts = split(file, ".")
            filename = join(filename_parts[1:end-1], ".")
            ext = filename_parts[end]

            fileout = "$(filename)_$(lpad(i, max_digits, "0")).$(ext)"

            Plots.savefig(fileout)
        end
    end

    Plots.plot(x, total_generated, label="Total Generation", legend=:bottomright)
    Plots.plot!(x, total_load_served, label="Total Load Served", legend=:bottomright)
    Plots.plot!(x, total_load_forecast, label="Total Load Forecasted", legend=:bottomright)

    Plots.xaxis!("Step")
    if log_scale
        Plots.yaxis!("Power ($units_str)", :log10)
    else
        Plots.yaxis!("Power ($units_str)")
    end

    Plots.savefig(file)
end
