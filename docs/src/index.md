# RDMREopt.jl

Documentation for RDMREopt.jl

# Example
```julia
using RDMREopt
using Xpress
using Distributions

u1 = Uncertainty(
    name="Financial.elec_cost_escalation_pct",
    distribution=Uniform(-0.01, 0.03)    
)
u2 = Uncertainty(
    name="ElectricUtility.outage_start_time_steps",
    distribution=Uniform(1, 8000),
    is_integer=true,
    is_vector=true  # passes one time step to each REopt model
)
u3 = Uncertainty(
    name="PV.size_kw",
    distribution=Normal(500, 50)    
)
u4 = Uncertainty(
    "ElectricLoad.loads_kw",
    [
        ones(8760) .* 8.0,
        ones(8760) .* 9.0,
        ones(8760) .* 10.0,
    ]
)
uncertainties = [u1, u2, u3, u4]

metrics = [
    "Financial.lcc",
    "PV.lcoe_per_kwh"
    "probability_of_survival_10_time_steps"
]

scenarios = Scenarios(
    "base_scenario.json",
    uncertainties,
    metrics;
    Nscenarios=10,
    Nparallel=6
);

rs, outage_sim_results = RDMREopt.run_threaded_scenarios(scenarios, Xpress.Optimizer; remove_series=true);

df = dicts_to_dataframe(rs)
save_dataframe_as_csv(df, "results.csv")
save_opt_and_outage_sim_results_as_json("results.json", rs, outage_sim_results)

```

# Inputs

### Uncertainty
```@docs
Uncertainty
```
### Scenarios
```@docs
Scenarios
```

# Running REopt Scenarios
### Run Serial Scenarios
```@docs
run_serial_scenarios
```
### Run Threaded Scenarios
```@docs
run_threaded_scenarios
```

# Analyzing Results
```@docs
dicts_to_dataframe
save_dataframe_as_csv
save_opt_and_outage_sim_results_as_json
```