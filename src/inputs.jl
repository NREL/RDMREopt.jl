"""
    handle_RDM_inputs!(d::Dict)

Parse any inputs in d["RDM"] into REopt input values. Options include:
- `seasonal_design_outage_duration`
    - four outages of the duration specified are modeled in REopt, with each outage centered on the peak load in each season
    - using the `min_resil_time_steps` the critical load must be met for the entirety of each outage
        - NOTE requiring that the critical load is met can lead to infeasible problems (when the generation cannot meet the critical load); including a large amount of generator fuel available can help prevent infeasible problems
    - the `value_of_lost_load_per_kwh` is set to zero s.t. no outage costs are included
    - requires the `base_critical_electric_loads_kw` input
- `base_critical_electric_loads_kw`
    - used to determine when to place the seasonal outages of length `seasonal_design_outage_duration`
"""
function handle_RDM_inputs!(d::Dict)
    r = pop!(d, "RDM", Dict())
    if "seasonal_design_outage_duration" in keys(r) && "base_critical_electric_loads_kw" in keys(r)

        # set min_resil_time_steps
        if haskey(d, "Site")
            d["Site"]["min_resil_time_steps"] = r["seasonal_design_outage_duration"]
        else
            d["Site"] = Dict("min_resil_time_steps" => r["seasonal_design_outage_duration"])
        end

        # find seasonal peak time steps
        @assert length(r["base_critical_electric_loads_kw"]) == 8760 "base_critical_electric_loads_kw must be hourly"
        load = r["base_critical_electric_loads_kw"]
        dur = r["seasonal_design_outage_duration"]
        winter_load = vcat(load[355*24+1 : 365*24], load[1:(31+28+21)*24]);
        spring_load = load[(31+28+21)*24+1 : (31+28+31+30+31+21)*24];
        summer_load = load[(31+28+31+30+31+21)*24+1: (31+28+31+30+31+30+31+30+21)*24];
        fall_load = load[(31+28+31+30+31+30+31+30+21)*24+1 : (31+28+31+30+31+30+31+30+31+30+31+21)*24];

        @assert sum(length(winter_load) + length(spring_load) + length(summer_load) + length(fall_load)) / 24 == 365

        peak_load_hour_winter = indexin(maximum(winter_load), load)[1]
        peak_load_hour_spring = indexin(maximum(spring_load), load)[1]
        peak_load_hour_summer = indexin(maximum(summer_load), load)[1]
        peak_load_hour_fall = indexin(maximum(fall_load), load)[1]

        if peak_load_hour_winter <= dur/2  # Jan or later time step
            peak_load_hour_winter = ceil(Int, dur/2+1)
        end
        half_dur = ceil(Int, dur/2)
        if peak_load_hour_winter > 8760-dur/2 # Dec or earlier time step
            peak_load_hour_winter = 8760-half_dur
        end

        if !haskey(d, "ElectricUtility")
            d["ElectricUtility"] = Dict()
        end
        d["ElectricUtility"]["outage_durations"] = [dur]
        d["ElectricUtility"]["outage_start_time_steps"] = [
            peak_load_hour_winter - half_dur,
            peak_load_hour_spring - half_dur,
            peak_load_hour_summer - half_dur, 
            peak_load_hour_fall - half_dur
        ]
    end
    nothing
end