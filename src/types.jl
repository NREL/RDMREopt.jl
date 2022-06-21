

"""
    Uncertainty(name::String, distribution::Distribution{Univariate, Continuous})

Keyword struct for defining input uncertainties.
- The `name` argument can be any REeopt input
- The `distribution` argument can be any of the type `Distribution{Univariate, Continuous}` from  Distributions.jl.

### Example
```@example
u1 = Uncertainty(
    name="Financial.elec_cost_escalation_pct",
    distribution=Uniform(-0.01, 0.03)    
)
```

### Distribution types
You can view all of the possible distributions with:
```@example
subtypes(Distribution{Univariate, Continuous})
```

### Custom sample sets
For the special case of `ElectricLoad.loads_kw` we allow one to provide a sample set of load profiles. The sample set is sampled uniformly. To use this capability define an `Uncertainty` as follows:
```julia
u4 = Uncertainty(
    "ElectricLoad.loads_kw",
    [
        ones(8760) .* 8.0,  # replace these vectors with your load profile samples
        ones(8760) .* 9.0,
        ones(8760) .* 10.0,
    ]
)
```
"""
Base.@kwdef struct Uncertainty
    name::String  # variable name in REopt.Scenario, e.g. "Financial.elec_cost_escalation_pct"
    distribution::Dist.Distribution{Dist.Univariate, Dist.Continuous}
    is_integer::Bool = false
    is_vector::Bool = false
    sample_set::AbstractVecOrMat = []
end


function Uncertainty(name::String, sample_set::AbstractVecOrMat)
    Uncertainty(
        name=name,
        distribution=Dist.Uniform(1, length(sample_set)),
        is_integer=true,
        is_vector=false,
        sample_set=sample_set
    )
end


"""
    function fill_in_scenario_dict!(
        d::Dict, 
        us::AbstractVector{Uncertainty}, 
        vals::AbstractVector{Float64}
    )

Put all of the `Uncertainty.name` fields and sample `vals` into the base scenario dict `d`.
"""
function fill_in_scenario_dict!(
    d::Dict, 
    us::AbstractVector{Uncertainty}, 
    vals::AbstractVector{<:Real}
    )

    function merge_nested_dict!(key1, key2, val, dict)
        if !haskey(dict, key1)
            merge!(dict, Dict(key1 => Dict(key2 => val)))
        else
            d[key1][key2] = val
        end
        nothing
    end

    for (i,u) in enumerate(us)
        k,v = String.(split(u.name, "."))
        if v == "size_kw"
            for v in ["max_kw", "min_kw"]
                merge_nested_dict!(k, v, vals[i], d)
            end
        elseif u.name == "ElectricLoad.loads_kw"
            merge_nested_dict!(k, v, u.sample_set[vals[i]], d)
        else
            if !(u.is_vector)
                merge_nested_dict!(k, v, vals[i], d)
            else
                merge_nested_dict!(k, v, [vals[i]], d)
            end
        end
    end
    d
end


struct Scenarios
    base_scenario::AbstractDict
    uncertainties::AbstractVector{Uncertainty}
    metrics::AbstractVector{String}  # REopt results strings, e.g. "Financial.lcc"
    Nscenarios::Int
    samples::AbstractMatrix{Float64}
    generator::Base.Generator
    Nparallel::Int
end


"""
    Scenarios(
        base_scenario::AbstractDict, 
        uncertainties::AbstractVector{Uncertainty},
        metrics::AbstractVector{String};
        Nscenarios::Int=100,
        Nparallel::Int=1,
        ngens::Int=100
    )

### Args
- `base_scenario::AbstractDict` a `Dict`` that defines the base REopt Scenario (see [REopt docs](https://nrel.github.io/REopt.jl/stable/reopt/inputs/#Scenario) for more)
- `uncertainties::AbstractVector{Uncertainty}` vector of [Uncertainty](@ref)s
- `metrics::AbstractVector{String}` vector of output metrics (TODO use these for analysis tools)

### Keyword Args
- `Nscenarios::Int` number of scenarios to sample from Latin Hypercube
- `Nparallel::Int` number of scenarios to run in parallel (when using [Run Threaded Scenarios](@ref))
- `ngens::Int` hyperparameter of LatinHypercubeSampling.LHCoptim, used to create Latin Hypercube of samples
"""
function Scenarios(
        base_scenario::AbstractDict, 
        uncertainties::AbstractVector{Uncertainty},
        metrics::AbstractVector{String};
        Nscenarios::Int=100,
        Nparallel::Int=1,
        ngens::Int=100
    )
    # preload URDB and PVWatts downloads s.t. they aren't downloaded for every scenario
    check_urdb!(base_scenario)
    check_pv!(base_scenario)

    samples = make_latin_hypercube_samples(uncertainties, Nscenarios; ngens=ngens)

    handle_RDM_inputs!(base_scenario)

    """
        function make_reopt_scenario(idx::Int)

    Wrapper function to create a Base.Generator of REopt.Scenarios for each sample of uncertainties.
    """
    function make_reopt_scenario(idx::Int)
        fill_in_scenario_dict!(deepcopy(base_scenario), uncertainties, samples[idx,:])
        # need the deepcopy to keep the parallel runs thread safe; 
        # o.w. get repeated samples in the scenarios
    end
    scenario_generator = Base.Generator(make_reopt_scenario, 1:Nscenarios)
    
    Scenarios(
        base_scenario,
        uncertainties,
        metrics,
        Nscenarios,
        samples,
        scenario_generator,
        Nparallel
    )
end


"""
    Scenarios(
        fp::String, 
        uncertainties::AbstractVector{Uncertainty},
        metrics::AbstractVector{String};
        Nscenarios::Int=100,
        Nparallel::Int=1,
        ngens::Int=100
    )

### Args
- `fp::String` path to a JSON file that defines the base REopt Scenario (see [REopt docs](https://nrel.github.io/REopt.jl/stable/reopt/inputs/#Scenario) for more)
- `uncertainties::AbstractVector{Uncertainty}` vector of [Uncertainty](@ref)s
- `metrics::AbstractVector{String}` vector of output metrics (TODO use these for analysis tools)

### Keyword Args
- `Nscenarios::Int` number of scenarios to sample from Latin Hypercube
- `Nparallel::Int` number of scenarios to run in parallel (when using [Run Threaded Scenarios](@ref))
- `ngens::Int` hyperparameter of LatinHypercubeSampling.LHCoptim, used to create Latin Hypercube of samples
"""
function Scenarios(
    fp::String, 
    uncertainties::AbstractVector{Uncertainty},
    metrics::AbstractVector{String};
    Nscenarios::Int=100,
    Nparallel::Int=1,
    ngens::Int=100
    )
    base_scenario = JSON.parsefile(fp)
    Scenarios(
        base_scenario,
        uncertainties,
        metrics,
        Nscenarios=Nscenarios,
        Nparallel=Nparallel,
        ngens=ngens
    )
end


"""
    function check_urdb!(s::Dict)

Fill in urdb_response if urdb_label is in `s` (and urdb_response is not).
"""
function check_urdb!(s::Dict)
    if "urdb_label" in keys(s["ElectricTariff"]) &&
        !("urdb_response" in keys(s["ElectricTariff"]))
        s["ElectricTariff"]["urdb_response"] = REopt.download_urdb(s["ElectricTariff"]["urdb_label"])
    end
    nothing
end


"""
    function check_pv!(s::Dict)

Fill in PV.prod_factor_series if PV is in `s` (and prod_factor_series is not).
"""
function check_pv!(s::Dict)
    if "PV" in keys(s) && !("prod_factor_series" in keys(s["PV"]))
        s["PV"]["prod_factor_series"] = REopt.get_pvwatts_prodfactor(
            s["Site"]["latitude"], s["Site"]["longitude"])
    end
    nothing
end


"""
    make_latin_hypercube_samples(v::AbstractVector{Uncertainty}, nsamples::Int; ngens=100)

Using the LatinHypercubeSampling.jl package, generate `nsamples` of the Uncertainties `v`. The integer "samples" from LHCoptim are re-sampled according to each `Uncertainty`'s `distribution` attribute.

return Matrix{Float64, 2} with size (nsamples, length(v))
"""
function make_latin_hypercube_samples(v::AbstractVector{Uncertainty}, nsamples::Int; ngens=100)

    ndims = length(v)
    # @assert nsamples >= ndims
    @info "Building Latin Hypercube of samples..."
    plan, _ = LHS.LHCoptim(nsamples, ndims, ngens)
    plan = convert(Matrix{Real}, plan)  # allow for Float and Int values
    # plan has integer values from 1:nsamples in each column
    # size(plan) = (nsamples, ndims)

    # for many distributions there is an issue b/c LHCoptim plan values range from 1:nsamples, 
    # but we need values in [0,1) (excluding 1) to lookup quantiles of CDFs.
    # Since plan./nsamples contain a value equal to 1, which gives an Inf from quantile(Normal(), 1)
    # (and many other distributions), we divide plan by nsamples + 1/nsamples to normalize it.
    for i = 1:ndims
        if !(typeof(v[i].distribution) <: Dist.Uniform)
            plan[:,i] ./= nsamples + 1/nsamples
        else
            plan[:,i] ./= nsamples
        end
        plan[:,i] .= Dist.quantile.(v[i].distribution, plan[:,i])
        if v[i].is_integer
            plan[:,i] .= map(x -> Int(round(x, digits=0)), plan[:,i])
        end
    end
    @info "... sample construction complete!"
    return plan
end

#=
Handling uncertainty distribution types and LHS:
- LHS takes ranges as inputs and each dimension's samples can be interpreted as being from a Uniform distribution. For uncertainties with distributions other than uniform we can set the LHS range to [0,1] and interpret the results as probabilities. 
- For Normal distributions we can convert the LHS output, call them u = U[0,1], with:
    quantile.(Normal(μ, σ), u)
- For Exponential distributions:
    quantile(Exponential(θ), 0.99)


julia> rand(Uniform(2,3),(2,2))
2×2 Matrix{Float64}:
 2.87109  2.7647
 2.73632  2.68062
=#

#=
LHS notes

N variables, M samples
M = 100
N=3
plan, _ = LHCoptim(M,N,1000)  # last arg is number of genarations in GA
- plan is a M x N matrix of integer values, with each (n-th) column ranging from 1:M
- assumes that each variable is split into M equally likely intervals
- so have to divide each entry by M to get probability? then look up value with quantile?
    - issue in that LHCoptim values range from 1:M, making plan ./ M contain a 1.0 value, which:
    julia> quantile(Normal(), 1)
        Inf
    - so plan = plan ./ (M+0.01) ?
    - need to plot to confirm that getting a Normally distributed variable ...
    - histogram(quantile.(Normal(), plan)) confirms
=#