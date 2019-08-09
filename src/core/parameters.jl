### Checks parameters in PowerModels components ###
""
function parameter_check_summary(data::Dict{String,Any})
    if InfrastructureModels.ismultinetwork(data)
        error("parameter_check_summary does not yet support multinetwork data")
    end

    if haskey(data, "conductors")
        error("parameter_check_summary does not yet support multiconductor data")
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

    messages["network"] = _parameter_check_network(data)

    return messages
end


""
function _parameter_check_bus(data::Dict{String,Any})
    messages = Dict{Symbol,Set{Int}}()

    messages[:vm_bounds] = Set{Int}()
    messages[:vm_start] = Set{Int}()
    messages[:ref_bus] = Set{Int}()

    for (i,bus) in data["bus"]
        index = bus["index"]

        if bus["vmin"] <= 0.8 || bus["vmax"] >= 1.2
            Memento.warn(LOGGER, "bus $(i) voltage magnitude bounds $(bus["vmin"]) - $(bus["vmax"]) are out side of typical bounds 0.8 - 1.2")
            push!(messages[:vm_bounds], index)
        end

        if bus["vm"] < bus["vmin"] || bus["vm"] > bus["vmax"]
            Memento.warn(LOGGER, "bus $(i) voltage magnitude start is not within given bounds $(bus["vmin"]) - $(bus["vmax"])")
            push!(messages[:vm_start], index)
        end

        if bus["bus_type"] == 3 && !isapprox(bus["va"], 0.0)
            Memento.warn(LOGGER, "reference bus $(i) voltage angle start is not zero $(bus["va"])")
            push!(messages[:ref_bus], index)
        end
    end

    return messages
end


""
function _parameter_check_load(data::Dict{String,Any})
    messages = Dict{Symbol,Set{Int}}()

    messages[:p_source] = Set{Int}()
    messages[:q_source] = Set{Int}()

    for (i,load) in data["load"]
        index = load["index"]

        if load["pd"] < 0.0
            Memento.warn(LOGGER, "load $(i) is acting as an active power source")
            push!(messages[:p_source], index)
        end

        if load["qd"] < 0.0
            Memento.warn(LOGGER, "load $(i) is acting as a reactive power source")
            push!(messages[:q_source], index)
        end
    end

    return messages
end


""
function _parameter_check_shunt(data::Dict{String,Any})
    messages = Dict{Symbol,Set{Int}}()

    messages[:sign_mismatch] = Set{Int}()

    for (i,shunt) in data["shunt"]
        index = shunt["index"]

        if shunt["gs"] < 0.0 && shunt["bs"] < 0.0 || shunt["gs"] > 0.0 && shunt["bs"] > 0.0
            Memento.warn(LOGGER, "shunt $(i) admittance has matching signs $(shunt["gs"] + shunt["bs"]im)")
            push!(messages[:sign_mismatch], index)
        end
    end

    return messages
end


""
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
            Memento.warn(LOGGER, "generator $(i) can behave as an active power demand")
            push!(messages[:p_demand], index)
        end

        if gen["qmin"] > 0.0 || gen["qmax"] < 0.0
            Memento.warn(LOGGER, "generator $(i) reactive power bounds $(gen["qmin"]) - $(gen["qmax"]) do not include 0.0")
            push!(messages[:qg_bounds_nonzero], index)
        end

        # filter out reactive support devices
        if !isapprox(max_pg_mag, 0.0)
            if abs(gen["qmin"]) > max_pg_mag || abs(gen["qmax"]) > max_pg_mag
                Memento.warn(LOGGER, "generator $(i) reactive power capabilities $(gen["qmin"]) - $(gen["qmax"]) exceed active power capabilities $(gen["pmin"]) - $(gen["pmax"])")
                push!(messages[:qg_bounds_large], index)
            end

            if gen["qmin"] < -max_pg_mag/12.0 && gen["qmax"] > max_pg_mag/4.0
                Memento.warn(LOGGER, "generator $(i) reactive power capabilities $(gen["qmin"]) - $(gen["qmax"]) to do not match the 1/12 - 1/4 rule of active power capabilities $(max_pg_mag)")
                push!(messages[:qg_bounds_shape], index)
            end
        end

        if haskey(gen, "model") && haskey(gen, "cost")
            if gen["model"] == 1

            else
                @assert gen["model"] == 2
                if any(x < 0 for x in gen["cost"])
                    Memento.warn(LOGGER, "generator $(i) has negative cost coefficients $(gen["cost"])")
                    push!(messages[:cost_negative], index)
                end
            end
        end
    end

    return messages
end


""
function _parameter_check_branch(data::Dict{String,Any})
    messages = Dict{Symbol,Set{Int}}()

    messages[:mva_decreasing] = Set{Int}()
    messages[:mva_redundant_15d] = Set{Int}()
    messages[:mva_redundant_30d] = Set{Int}()
    messages[:impedance] = Set{Int}()
    messages[:reactance] = Set{Int}()
    messages[:admittance_fr] = Set{Int}()
    messages[:admittance_to] = Set{Int}()

    messages[:basekv_line] = Set{Int}()
    messages[:rx_ratio_line] = Set{Int}()
    messages[:bx_fr_ratio] = Set{Int}()
    messages[:bx_to_ratio] = Set{Int}()

    messages[:basekv_xfer] = Set{Int}()
    messages[:rx_ratio_xfer] = Set{Int}()
    messages[:tm_range] = Set{Int}()
    messages[:ta_range] = Set{Int}()

    bus_lookup = Dict(bus["index"] => bus for (i,bus) in data["bus"])

    for (i,branch) in data["branch"]
        index = branch["index"]

        rate_a = branch["rate_a"]
        rate_b = haskey(branch, "rate_b") ? branch["rate_b"] : rate_a
        rate_c = haskey(branch, "rate_c") ? branch["rate_c"] : rate_a

        basekv_fr = bus_lookup[branch["f_bus"]]["base_kv"]
        basekv_to = bus_lookup[branch["t_bus"]]["base_kv"]

        if rate_a > rate_b || rate_b > rate_c
            Memento.warn(LOGGER, "branch $(i) thermal limits are decreasing")
            push!(messages[:mva_decreasing], index)
        end

        # epsilon of 0.05 accounts for rounding in data
        rate_ub_15 = _compute_mva_ub(branch, bus_lookup, 0.261798)
        if rate_ub_15 < rate_a - 0.05
            Memento.warn(LOGGER, "branch $(i) thermal limit A $(rate_a) is redundant with a 15 deg. angle difference $(rate_ub_15)")
            push!(messages[:mva_redundant_15d], index)
        end

        # epsilon of 0.05 accounts for rounding in data
        rate_ub_30 = _compute_mva_ub(branch, bus_lookup, 0.523598)
        if rate_ub_30 < rate_a - 0.05
            Memento.warn(LOGGER, "branch $(i) thermal limit A $(rate_a) is redundant with a 30 deg. angle difference $(rate_ub_30)")
            push!(messages[:mva_redundant_30d], index)
        end

        if branch["br_r"] < 0.0 || branch["br_x"] < 0.0
            Memento.warn(LOGGER, "branch $(i) impedance $(branch["br_r"] + branch["br_x"]im) is non-positive")
            push!(messages[:impedance], index)
        end

        if branch["g_fr"] > 0.0 || branch["b_fr"] < 0.0
            Memento.warn(LOGGER, "branch $(i) from-side admittance $(branch["g_fr"] + branch["b_fr"]im) signs may be incorrect")
            push!(messages[:admittance_fr], index)
        end

        if branch["g_to"] > 0.0 || branch["b_to"] < 0.0
            Memento.warn(LOGGER, "branch $(i) to-side admittance $(branch["g_to"] + branch["b_to"]im) signs may be incorrect")
            push!(messages[:admittance_to], index)
        end

        if isapprox(branch["br_x"], 0.0)
            Memento.warn(LOGGER, "branch $(i) reactance $(branch["br_x"]) is zero")
            push!(messages[:reactance], index)
            continue
        end

        rx_ratio = abs(branch["br_r"]/branch["br_x"])
        if !branch["transformer"] # branch specific checks

            if !isapprox(basekv_fr, basekv_to)
                Memento.warn(LOGGER, "branch $(i) base kv values are different $(basekv_fr) - $(basekv_to)")
                push!(messages[:basekv_line], index)
            end

            if rx_ratio >= 0.5
                Memento.warn(LOGGER, "branch $(i) r/x ratio $(rx_ratio) is above 0.5")
                push!(messages[:rx_ratio_line], index)
            end

            if !isapprox(branch["b_fr"], 0.0)
                bx_ratio = abs(branch["b_fr"]/branch["br_x"])

                if bx_ratio > 0.5 || bx_ratio < 0.04
                    Memento.warn(LOGGER, "branch $(i) from-side b/x ratio $(bx_ratio) is outside the range 0.04 - 0.5")
                    push!(messages[:bx_fr_ratio], index)
                end
            end

            if !isapprox(branch["b_to"], 0.0)
                bx_ratio = abs(branch["b_to"]/branch["br_x"])

                if bx_ratio > 0.5 || bx_ratio < 0.04
                    Memento.warn(LOGGER, "branch $(i) to-side b/x ratio $(bx_ratio) is outside the range 0.04 - 0.5")
                    push!(messages[:bx_to_ratio], index)
                end
            end

        else # transformer specific checks
            if isapprox(basekv_fr, basekv_to)
                Memento.warn(LOGGER, "transformer branch $(i) base kv values are the same $(basekv_fr) - $(basekv_to)")
                push!(messages[:basekv_xfer], index)
            end

            if rx_ratio >= 0.05
                Memento.warn(LOGGER, "transformer branch $(i) r/x ratio $(rx_ratio) is above 0.05")
                push!(messages[:rx_ratio_xfer], index)
            end

            if branch["tap"] < 0.9 || branch["tap"] > 1.1
                Memento.warn(LOGGER, "transformer branch $(i) tap ratio $(branch["tap"]) is out side of the nominal range 0.9 - 1.1")
                push!(messages[:tm_range], index)
            end

            if branch["shift"] < -0.174533 || branch["shift"] > 0.174533
                Memento.warn(LOGGER, "transformer branch $(i) phase shift $(branch["shift"]) is out side of the range -0.174533 - 0.174533")
                push!(messages[:ta_range], index)
            end
        end
    end

    return messages
end


""
function _compute_mva_ub(branch::Dict{String,Any}, bus_lookup, vad_bound::Real)
    vad_max = max(abs(branch["angmin"]), abs(branch["angmax"]))
    if vad_bound > vad_max
        Memento.info(LOGGER, "given vad bound $(vad_bound) is larger than branch vad max $(vad_max)")
    end
    vad_max = vad_bound

    if vad_max > pi
        error(LOGGER, "compute_mva_ub does not support vad bounds larger than pi, given $(vad_max)")
    end

    r = branch["br_r"]
    x = branch["br_x"]
    z = r + im * x
    y = 1/z
    y_mag = abs(y)

    fr_vm_max = bus_lookup[branch["f_bus"]]["vmax"]
    to_vm_max = bus_lookup[branch["t_bus"]]["vmax"]
    vm_max = max(fr_vm_max, to_vm_max)

    c_max = sqrt(fr_vm_max^2 + to_vm_max^2 - 2*fr_vm_max*to_vm_max*cos(vad_max))

    rate_ub = y_mag*vm_max*c_max

end


""
function _parameter_check_network(data::Dict{String,Any})
    messages = Dict{Symbol,Number}()

    vm_center_list = [ (bus["vmax"]+bus["vmin"])/2.0 for (i,bus) in data["bus"] ]
    messages[:vm_center_mean] = mean(vm_center_list)
    messages[:vm_center_std] = std(vm_center_list)

    return messages
end
