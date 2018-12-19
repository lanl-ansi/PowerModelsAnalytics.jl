### Checks parameters in PowerModels components ###

function parameter_check_summary(data::Dict{String,Any})
    if InfrastructureModels.ismultinetwork(data)
        error("parameter_check_summary does not yet support multinetwork data")
    end

    if !(haskey(data, "per_unit") && data["per_unit"])
        error("parameter_check_summary requires data in per_unit")
    end

    messages = Dict{String,Any}()

    messages["bus"] = _parameter_check_bus(data)
    messages["load"] = _parameter_check_load(data)
    messages["shunt"] = _parameter_check_shunt(data)
    messages["gen"] = _parameter_check_gen(data)
    messages["branch"] = _parameter_check_branch(data)

    return messages
end


function _parameter_check_bus(data::Dict{String,Any})
    messages = Dict{Symbol,Set{Int}}()

    messages[:vm_bounds] = Set{Int}()
    messages[:vm_start] = Set{Int}()
    messages[:ref_bus] = Set{Int}()

    for (i,bus) in data["bus"]
        index = bus["index"]

        if bus["vmin"] <= 0.8 || bus["vmax"] >= 1.2
            warn(LOGGER, "bus $(i) voltage magnitude bounds $(bus["vmin"]) - $(bus["vmax"]) are out side of typical bounds 0.8 - 1.2")
            push!(messages[:vm_bounds], index)
        end

        if bus["vm"] < bus["vmin"] || bus["vm"] > bus["vmax"]
            warn(LOGGER, "bus $(i) voltage magnitude start is not within given bounds $(bus["vmin"]) - $(bus["vmax"])")
            push!(messages[:vm_start], index)
        end

        if bus["bus_type"] == 3 && !isapprox(bus["va"], 0.0)
            warn(LOGGER, "reference bus $(i) voltage angle start is not zero $(bus["va"])")
            push!(messages[:ref_bus], index)
        end
    end

    return messages
end


function _parameter_check_load(data::Dict{String,Any})
    messages = Dict{Symbol,Set{Int}}()

    messages[:p_source] = Set{Int}()
    messages[:q_source] = Set{Int}()

    for (i,load) in data["load"]
        index = load["index"]

        if load["pd"] < 0.0
            warn(LOGGER, "load $(i) is acting as an active power source")
            push!(messages[:p_source], index)
        end

        if load["qd"] < 0.0
            warn(LOGGER, "load $(i) is acting as a reactive power source")
            push!(messages[:q_source], index)
        end
    end

    return messages
end


function _parameter_check_shunt(data::Dict{String,Any})
    messages = Dict{Symbol,Set{Int}}()

    messages[:sign_mismatch] = Set{Int}()

    for (i,shunt) in data["shunt"]
        index = shunt["index"]

        if shunt["gs"] < 0.0 && shunt["bs"] < 0.0 || shunt["gs"] > 0.0 && shunt["bs"] > 0.0
            warn(LOGGER, "shunt $(i) admittance has matching signs $(shunt["gs"] + shunt["bs"]im)")
            push!(messages[:sign_mismatch], index)
        end
    end

    return messages
end


function _parameter_check_gen(data::Dict{String,Any})
    messages = Dict{Symbol,Set{Int}}()

    messages[:p_demand] = Set{Int}()

    messages[:qg_bounds_nonzero] = Set{Int}()
    messages[:qg_bounds_large] = Set{Int}()
    messages[:qg_bounds_shape] = Set{Int}()

    messages[:cost_negative] = Set{Int}()


    for (i,gen) in data["gen"]
        index = gen["index"]
        max_pg_mag = max(abs(gen["pmin"]), abs(gen["pmax"]))

        if gen["pmin"] < 0.0 
            warn(LOGGER, "generator $(i) can behave as an active power demand")
            push!(messages[:p_demand], index)
        end

        if gen["qmin"] > 0.0 || gen["qmax"] < 0.0
            warn(LOGGER, "generator $(i) reactive power bounds $(gen["qmin"]) - $(gen["qmax"]) do not include 0.0")
            push!(messages[:qg_bounds_nonzero], index)
        end

        # filter out reactive support devices
        if !isapprox(max_pg_mag, 0.0)
            if abs(gen["qmin"]) > max_pg_mag || abs(gen["qmax"]) > max_pg_mag
                warn(LOGGER, "generator $(i) reactive power capabilities $(gen["qmin"]) - $(gen["qmax"]) exceed active power capabilities $(gen["pmin"]) - $(gen["pmax"])")
                push!(messages[:qg_bounds_large], index)
            end

            if gen["qmin"] < -max_pg_mag/12.0 && gen["qmax"] > max_pg_mag/4.0
                warn(LOGGER, "generator $(i) reactive power capabilities $(gen["qmin"]) - $(gen["qmax"]) to do not match the 1/12 - 1/4 rule of active power capabilities")
                push!(messages[:qg_bounds_shape], index)
            end
        end

        if haskey(gen, "model") && haskey(gen, "cost")
            if gen["model"] == 1

            else
                @assert gen["model"] == 2
                if any(x < 0 for x in gen["cost"])
                    warn(LOGGER, "generator $(i) has negative cost coefficients $(gen["cost"])")
                    push!(messages[:cost_negative], index)
                end
            end
        end
    end

    return messages
end


function _parameter_check_branch(data::Dict{String,Any})
    messages = Dict{Symbol,Set{Int}}()

    messages[:s_limit_decreasing] = Set{Int}()
    messages[:impedance] = Set{Int}()
    messages[:reactance] = Set{Int}()
    messages[:admittance_fr] = Set{Int}()
    messages[:admittance_to] = Set{Int}()

    messages[:rx_ratio_line] = Set{Int}()
    messages[:bx_fr_ratio] = Set{Int}()
    messages[:bx_to_ratio] = Set{Int}()

    messages[:rx_ratio_xfer] = Set{Int}()


    for (i,branch) in data["branch"]
        index = branch["index"]

        if branch["rate_a"] > branch["rate_b"] || branch["rate_b"] > branch["rate_c"]
            warn(LOGGER, "branch $(i) thermal limits are decreasing")
            push!(messages[:s_limit_decreasing], index)
        end

        if branch["br_r"] < 0.0 || branch["br_x"] < 0.0
            warn(LOGGER, "branch $(i) impedance $(branch["br_r"] + branch["br_z"]im) is non-positive")
            push!(messages[:impedance], index)
        end

        if branch["g_fr"] > 0.0 || branch["b_fr"] < 0.0
            warn(LOGGER, "branch $(i) from-side admittance $(branch["g_fr"] + branch["b_fr"]im) signs may be incorrect")
            push!(messages[:admittance_fr], index)
        end

        if branch["g_to"] > 0.0 || branch["b_to"] < 0.0
            warn(LOGGER, "branch $(i) to-side admittance $(branch["g_to"] + branch["b_to"]im) signs may be incorrect")
            push!(messages[:admittance_to], index)
        end

        if isapprox(branch["br_x"], 0.0)
            warn(LOGGER, "branch $(i) reactance $(branch["br_x"]) is zero")
            push!(messages[:reactance], index)
            continue
        end

        rx_ratio = abs(branch["br_r"]/branch["br_x"])
        if !branch["transformer"]
            if rx_ratio >= 0.5
                warn(LOGGER, "branch $(i) r/x ratio $(rx_ratio) is above 0.5")
                push!(messages[:rx_ratio], index)
            end

            if !isapprox(branch["b_fr"], 0.0)
                bx_ratio = abs(branch["b_fr"]/branch["br_x"])

                if bx_ratio > 0.5 || bx_ratio < 0.04
                    warn(LOGGER, "branch $(i) from-side b/x ratio $(bx_ratio) is outside the range 0.04 - 0.5")
                    push!(messages[:bx_fr_ratio], index)
                end
            end

            if !isapprox(branch["b_to"], 0.0)
                bx_ratio = abs(branch["b_to"]/branch["br_x"])

                if bx_ratio > 0.5 || bx_ratio < 0.04
                    warn(LOGGER, "branch $(i) to-side b/x ratio $(bx_ratio) is outside the range 0.04 - 0.5")
                    push!(messages[:bx_to_ratio], index)
                end
            end

        else # transformer specific checks
            rx_ratio = abs(branch["br_r"]/branch["br_x"])
            if rx_ratio >= 0.05
                warn(LOGGER, "transformer branch $(i) r/x ratio $(rx_ratio) is above 0.05")
                push!(messages[:rx_ratio_xfer], index)
            end
        end
    end

    return messages
end

