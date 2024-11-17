module MimiNICE_faiRR

using MimiNICE_revenue_recycle
using Mimi 
using Revise

include(joinpath("nice_fairr_components", "nice_fairr_reg_utils_component.jl"))     # component with individual and regional utilities, calculated as Atkinson function (or constant relative risk aversion (CRRA) function,cf. Adler 2017 Methods) of per capita consumption with region-specific elasticities (eta, marginal utility of consumption).

#include helper functions from MimiNICE_revenue_recycle (needed for get_quintile_income_shares() )
include(joinpath(dirname(pathof(MimiNICE_revenue_recycle)), "helper_functions.jl"))



export get_model


# # # ---------------------------
# # # Default parameter values of MimiNICE_revenue_recycle
# # # ---------------------------

# Pure rate of time preference.
ρ = 0.015

# Elasticity of marginal utility of consumption.
η = 1.5

# Income elasticity of climate damages ξ (1 = proportional to income, -1 = inversely proportional to income).
damage_elasticity = 1.0  # ξ = 1 used in (Budolfson et al 2021). It useful to keep it here for comparability of results, but we want to use ξ = 1.5. Update this param before generating new results.

# Share of carbon tax revenue that is lost and cannot be recycled (1 = 100% of revenue lost, 0 = nothing lost)
lost_revenue_share = 0.0

# Shares of regional revenues that are recycled globally as international transfers (1 = 100% of revenue recycled globally).
global_recycle_share = zeros(12)

# Share of recycled carbon tax revenue that each region-quintile pair receives (row = region, column = quintile)
quintile_recycle_share = ones(12, 5) .* 0.2


# # # ---------------------------
# # # Assumptions about income distributions
# # # ---------------------------

# Quintile income distribution scenario (options = "constant", "SSP1", "SSP2", "SSP3", "SSP4", or "SSP5")
quintile_income_scenario = "constant"

# Load quintile income distribution scenario data (stored in MimiNICE_revenue_recycle package).
# income_distribution_raw = DataFrame(load(joinpath(@__DIR__, "..", "..", "data", quintile_income_scenario*"_quintile_distributions_consumption.csv")))
income_distribution_raw = DataFrame(load(joinpath(dirname(pathof(MimiNICE_revenue_recycle)), "..", "data", quintile_income_scenario*"_quintile_distributions_consumption.csv")))

# Clean up and organize time-varying income distribution data into required NICE format (time × regions × quintiles).
income_distributions = get_quintile_income_shares(income_distribution_raw)




# # # ---------------------------
# # # Assumptions about regression between GDP and consumption elasticity of initial carbon tax burden
# # # ---------------------------

# Should the time-varying elasticity values only change across the range of GDP values from the studies?
# true = limit calculations to study gdp range, false = allow calculations for 0 to +Inf GDP.
bound_gdp_elasticity = false

# Type of slope for regression analysis (options are :central, :steeper, :flatter, :percentile)
regression_slope_type = :central

# Value if setting the regression slope type to a specific elasticity percentile value.
elasticity_percentile = 0.9



"""
    get_model()

Function to build the MimiNICE_faiRR model
"""
function get_model()

    # Initialize model as MimiNICE_revenue_recycle (with assumptions about regression between GDP and consumption elasticity of initial carbon tax burden)
    m = MimiNICE_revenue_recycle.create_nice_recycle(slope_type=regression_slope_type, percentile=elasticity_percentile)
    run(m)

    # Set parameters of MimiNICE_revenue_recycle
    update_param!(m, :damage_elasticity, damage_elasticity)
    update_param!(m, :quintile_income_shares, income_distributions)
    update_param!(m, :recycle_share, recycle_share)
    update_param!(m, :rho, ρ)
    update_param!(m, :eta, η)

    # If selected, allow elasticities to be calculated for all GDP values (not just those observed in studies).
    if bound_gdp_elasticity == false
        update_param!(m, :min_study_gdp, 1e-10)
        update_param!(m, :max_study_gdp, +Inf)
    end

    run(m)

    #modify MimiNICE_revenue_recycle components and params

    # Delete NICE welfare (to be replaced by regional utilities and SWF components).
    quintile_population = m[:nice_welfare, :quintile_pop]
    delete!(m, :nice_welfare)
    delete_param!(m, :eta)
    delete_param!(m, :rho)         #(if I delete :nice_welfare, does param :rho disappear? I think yes)

    # Add regional utilities component.
    add_comp!(m, nice_fairr_reg_utils, after = :nice_recycle)
    
    # Set parameters for nice_fairr_reg_utils.
    set_param!(m, :nice_fairr_reg_utils, :eta, ones(length(dim_keys(m, :regions))).* η) # in principle, η can be region-specific. Here we keep them equal for all regions
    set_param!(m, :nice_fairr_reg_utils, :rho, ρ)
    update_param!(m, :nice_fairr_reg_utils, :quintile_pop, quintile_population)

    
    # Create model connections.
    # connect_param!(m, :nice_fairr_reg_utils, :quintile_c, :nice_neteconomy, :quintile_c_post)
    connect_param!(m, :nice_fairr_reg_utils, :quintile_c, :nice_recycle, :qc_post_recycle)


    return m

end 

end


# Note: if I want to access data stored in MimiNICE_revenue_recycle package (in the folder "data") from within this package, the following should work:
# joinpath(dirname(pathof(MimiNICE_revenue_recycle)), "..", "data")
# example: open(joinpath(dirname(pathof(MimiNICE_revenue_recycle)), "..", "data/RCP45_concentrations.csv")) opens IOStream to this file
