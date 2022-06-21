using RDMREopt
using Distributions
using Test
using Xpress


@testset "threaded_scenarios" begin
    u1 = Uncertainty(
        name="Financial.elec_cost_escalation_pct",
        distribution=Uniform(-0.01, 0.03)    
    )
    u2 = Uncertainty(
        name="ElectricUtility.outage_start_time_steps",
        distribution=Uniform(1, 8000),  # TODO does REopt.jl handle outages wrapping around year?
        is_integer=true,
        is_vector=true
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
        "PV.lcoe_per_kwh",
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

    #=
    Memory notes:
    With 10 scenarios and remove_series=true
        rs 50.334 KiB
    With 10 scenarios and remove_series=false
        rs 
    =#

    #= TODO
    plot metrics and uncertainties?
    =#
end


@testset "serial_scenarios" begin
    u1 = Uncertainty(
        name="Financial.elec_cost_escalation_pct",
        distribution=Uniform(-0.01, 0.03)    
    )
    u2 = Uncertainty(
        name="ElectricLoad.annual_kwh",
        distribution=Normal(2_849_901, 100_000)    
    )
    u3 = Uncertainty(
        name="PV.size_kw",
        distribution=Normal(500, 50)    
    )
    uncertainties = [u1, u2, u3]

    metrics = [
        "Financial.lcc",
        "PV.lcoe_per_kwh",
        "probability_of_survival"
    ]

    scenarios = Scenarios(
        "base_scenario.json",
        uncertainties,
        metrics;
        Nscenarios=2,
        Nparallel=6
    );

    results, outage_sim_results = RDMREopt.run_serial_scenarios(scenarios, Xpress.Optimizer; remove_series=true);

    df = dicts_to_dataframe(results)
    save_dataframe_as_csv(df, "results.csv")
end