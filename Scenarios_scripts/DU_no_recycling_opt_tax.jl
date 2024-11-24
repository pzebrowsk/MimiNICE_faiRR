# Scenario with discounted utilitarian SWF, no recycling, only global carbon tax is optimized (savings fixed)

include("../src/nice_fairr_helper_functions/optimize_NICE_faiRR_helpers.jl")

# # # ________________________
# # # 1) generate model
# # # ________________________ 
m = get_model()
run(m)

# # # ________________________
# # # 2) Set up parameters of the model
# # # ________________________
# Pure rate of time preference.
ρ = 0.015

# Elasticity of marginal utility of consumption.
η = 1.5

# Income elasticity of climate damages ξ (1 = proportional to income, -1 = inversely proportional to income).
#change damage_elasticity to 1.5
damage_elasticity = 1.0  # ξ = 1 used in (Budolfson et al 2021). It useful to keep it here for comparability of results, but we want to use ξ = 1.5. Update this param before generating new results.

# Share of carbon tax revenue that is lost and cannot be recycled (1 = 100% of revenue lost, 0 = nothing lost)
lost_revenue_share = 0.0

# Shares of regional revenues that are recycled globally as international transfers (1 = 100% of revenue recycled globally).
global_recycle_share = zeros(12)

# Share of recycled carbon tax revenue that each region-quintile pair receives (row = region, column = quintile)
quintile_recycle_share = ones(12, 5) .* 0.2 

#u_zero