
"""
    add_uncertainties_to_results!(r::Dict, s::Scenarios, d::Dict)

Put the `Uncertainties` names and values into the results dictionary `r` using the values in `d`.
"""
function add_uncertainties_to_results!(r::Dict, s::Scenarios, d::Dict)
    r["Uncertainty"] = Dict()
    for u in s.uncertainties
        k,v = String.(split(u.name, "."))
        if v == "size_kw"
            r["Uncertainty"][k * "_" * v] = d[k]["min_kw"]
        else
            r["Uncertainty"][k * "_" * v] = d[k][v]
        end
    end
    nothing
end


"""
    add_prob_of_survival_for_N_time_steps!(N::Int, results::Dict, outage_sim_results::Dict)
"""
function add_prob_of_survival_for_N_time_steps!(N::Int, results::Dict, outage_sim_results::Dict)
    try
        results["probability_of_survival_$(N)_time_steps"] = outage_sim_results["probs_of_surviving"][N]
    catch e
        if typeof(e) == BoundsError
            results["probability_of_survival_$(N)_time_steps"] = 0.0
        else
            throw(e)
        end
    end
    nothing
end


"""
    add_outage_sim_results!(sim_results::AbstractVector, s::Scenarios, r::Dict, p::REopt.REoptInputs, i::Int)

Run REopt.simulate_outages and add "probability_of_survival_N_time_steps" to results["Outages"]
"""
function add_outage_sim_results!(sim_results::AbstractVector, s::Scenarios, r::Dict, 
    p::REopt.REoptInputs, i::Int
    )
    sim_results[i] = REopt.simulate_outages(r, p; microgrid_only=true)
    for m in filter(m -> startswith(m, "probability_of_survival_"), s.metrics)
        N = parse(Int, m[25:findall("_", m)[4][1]-1])
        add_prob_of_survival_for_N_time_steps!(N, r, sim_results[i])
    end
    nothing
end


"""
    run_serial_scenarios(s::Scenarios, optimizer; remove_series=false)

Run the REopt scenarios one at a time in for loop and return a vector of dictionaries for results.

If `remove_series` is `true` then all time series results are removed from the dictionaries,
which will keep memory use lower and make the results compatible with rectangular data stores.
"""
function run_serial_scenarios(s::Scenarios, optimizer; remove_series=false)
    rs = [Dict() for i = 1:s.Nscenarios]
    sim_results = nothing
    if any(startswith(m, "probability_of_survival") for m in s.metrics)
        sim_results = [Dict() for i = 1:s.Nscenarios]
    end

    for (i,d) in enumerate(s.generator)
        p = REopt.REoptInputs(REopt.Scenario(d))
        r = REopt.run_reopt(JuMP.Model(optimizer), p)
        if  any(startswith(m, "probability_of_survival") for m in s.metrics)
            add_outage_sim_results!(sim_results, s, r, p, i)
        end
        if remove_series
            remove_results_series!(r)
        end
        add_uncertainties_to_results!(r, s, d)
        rs[i] = r
    end
    return rs, sim_results
end


"""
    run_threaded_scenarios(s::Scenarios, optimizer; remove_series=false)

Run batches of REopt scenarios in parallel according to `Scenarios.Nparallel` and return a
vector of dictionaries for results.

If `remove_series` is `true` then all time series results are removed from the dictionaries,
which will keep memory use lower and make the results compatible with rectangular data stores.
"""
function run_threaded_scenarios(s::Scenarios, optimizer; remove_series=false)
    rs = [Dict() for i = 1:s.Nscenarios]
    sim_results = nothing
    if any(startswith(m, "probability_of_survival") for m in s.metrics)
        sim_results = [Dict() for i = 1:s.Nscenarios]
    end

    Nthreads = s.Nparallel
    if Threads.nthreads() < s.Nparallel
        Nthreads = Threads.nthreads()
        @warn "Number of threads available is less than `Nparallel` ($(Nthreads) vs. $(s.Nparallel)). Only running $(Nthreads) REopt jobs in parallel.
        "
    end
    
    tstart = time()
    telapsed = 0.0
    tendbatch = 0.0
    tstartbatch = 0.0
    nbatches = Int(ceil(s.Nscenarios / Nthreads))
    batch_times = zeros(nbatches-1)

    for batchnum in 1:nbatches

        if batchnum > 1
            batch_times[batchnum-1] = tendbatch - tstartbatch
            avg_batch_time = sum(batch_times) / (batchnum-1)
            @info "\n\nTotal elapsed time: $(round(telapsed, digits=0)) seconds.
            Estimated time remaining: $(round(avg_batch_time * (nbatches-batchnum+1), digits=0)) seconds."
        end

        @info "Starting batch number $batchnum of $nbatches ...
        "
        tstartbatch = time()

        start_idx = Nthreads * (batchnum - 1) + 1
        end_idx = minimum([Nthreads * batchnum, s.Nscenarios])
        Threads.@threads for i = start_idx:end_idx
            d = iterate(s.generator, i-1)[1]  # iterate returns a tuple (nextitem, state)
            # create REoptInputs for simulate_outages (o.w. will get done twice)
            p = REopt.REoptInputs(REopt.Scenario(d))
            r = REopt.run_reopt(JuMP.Model(optimizer), p)
            if  any(startswith(m, "probability_of_survival") for m in s.metrics)
                add_outage_sim_results!(sim_results, s, r, p, i)
            end
            if remove_series # must be done after add_outage_sim_results! b/c need time series for outage sim
                remove_results_series!(r)
            end
            add_uncertainties_to_results!(r, s, d)
            rs[i] = r
        end
        tendbatch = time()
        telapsed = time() - tstart
    end
    return rs, sim_results
end


"""
    remove_results_series!(d::Dict)

Remove any key/value pair with "series" in the key.
"""
function remove_results_series!(d::Dict)
    for subd in (sd for sd in values(d) if isa(sd, Dict))
        for k in keys(subd)
            if occursin("series", k)
                delete!(subd, k)
            end
        end
    end
    nothing
end
