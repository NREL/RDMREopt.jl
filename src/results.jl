
"""
    dicts_to_dataframe(ds::AbstractVector)

Put all of the Dicts in `ds` into a DataFrame. Column names will match keys.
"""
function dicts_to_dataframe(ds::AbstractVector)
    df = DataFrame(flatten_results_dict(ds[1]))
    if length(ds) > 1
        for d in ds[2:end]
            push!(df, flatten_results_dict(d), cols=:union, promote=true)
        end
    end
    df
end


"""
    flatten_results_dict(d::Dict)

Given a REopt results Dict, take all the sub-dictionaries and flatten them by 
creating keys from combinations of the upper and lower keys seperated by an underscore "_".

For example, the `ElectricTariff` results from REopt is a Dict with many keys, such as:
```@repl
julia> d["ElectricTariff"]
Dict{String, Any} with 13 entries:
  "year_one_demand_cost"           => 2.23023e5
  "year_one_coincident_peak_cost"  => 0.0
  "year_one_export_benefit"        => -0.0
  "year_one_energy_cost"           => 2.86959e5
  "lifecycle_energy_cost"          => 21046.0
  "year_one_fixed_cost"            => 1600.0
  "lifecycle_coincident_peak_cost" => 0.0
  "lifecycle_export_benefit"       => -0.0
  "lifecycle_fixed_cost"           => 117.33
  "lifecycle_min_charge_adder"     => 0.0
  "year_one_min_charge_adder"      => 0.0
  "year_one_bill"                  => 5.11582e5
  "lifecycle_demand_cost"          => 16356.8
```
And so the flattened dictionary will have keys such as `ElectricTariff_year_one_demand_cost` and 
`ElectricTariff_year_one_coincident_peak_cost`.
"""
function flatten_results_dict(d::Dict)
    flatd = Dict()
    for (k,v) in d
        if isa(v, Dict)
            for (k2,v2) in v
                if !isempty(v2) && !(typeof(v2) <: AbstractArray)
                    flatd[k*"_"*k2] = convert(Float64, v2)
                end
                # have to convert Ints to Float in case the first value in a column is a 0 but other values are non zero Floats
            end
        else
            flatd[k] = v
        end
    end
    flatd
end


"""
    save_dataframe_as_csv(df::DataFrame, filename::String)

Needs no explanation.
"""
function save_dataframe_as_csv(df::DataFrame, filename::String)
    CSV.write(filename, df)
end


"""
    save_opt_and_outage_sim_results_as_json(file_name::String, results::Vector{<:Dict}, outage_sim_results::Vector{<:Dict})

Combine optimization and outage simulator results and save them to JSON using `file_name`.
"""
function save_opt_and_outage_sim_results_as_json(file_name::String, results::Vector{<:Dict}, outage_sim_results::Vector{<:Dict})
    out_json = Dict[]
    for (r,o) in zip(results, outage_sim_results)
        r["outage_sim_results"] = o
        push!(out_json, r)
    end
    open(file_name, "w") do f
        JSON.print(f, out_json, 2)
    end
end
