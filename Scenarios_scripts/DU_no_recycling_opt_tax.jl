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
η = 1.5 * ones(length(dim_keys(m, :regions)))           #this should be done in the constructor as well (works with one value because nice_fairr_reg_utils_component is added later)

# Income elasticity of climate damages ξ (1 = proportional to income, -1 = inversely proportional to income).
damage_elasticity = 0.5 #0.0 #-1.0 #ξ=-1 is a bit extreme  # ξ = 1 used in (Budolfson et al 2021). 

# Share of carbon tax revenue that is lost and cannot be recycled (1 = 100% of revenue lost, 0 = nothing lost)
lost_revenue_share = 0.0

# Shares of regional revenues that are recycled globally as international transfers (1 = 100% of revenue recycled globally).
global_recycle_share = zeros(12)

# Share of recycled carbon tax revenue that each region-quintile pair receives (row = region, column = quintile)
quintile_recycle_share = ones(12, 5) .* 0.2     #equal per capita distribution


# Reference utility level u_zero
u_0 = zeros(length(dim_keys(m, :time)), length(dim_keys(m, :regions)))


update_param!(m, :rho, ρ)
update_param!(m, :eta, η)
update_param!(m, :damage_elasticity, damage_elasticity)
update_param!(m, :lost_revenue_share, lost_revenue_share)
update_param!(m, :global_recycle_share, global_recycle_share)  
update_param!(m, :recycle_share, quintile_recycle_share)       
#set_param!(m, :nice_fairr_reg_utils, :u_zero, u_0)
update_param!(m, :u_zero, u_0)

# Choice about recucling revenue
rr = false

# Utility type and aggregating function
utility_type = "total_reg"
aggr_fun = sum

# # # ________________________
# # # 3) Set up initial conditions (initial state of the model, including initial values of active controls)
# # # ________________________


# # # ________________________
# # # 4) Select active controls
# # # ________________________
a_c = "tax"
# a_t = ...     #active time steps

# # # ________________________
# # # 5) Optimize and save results
# # # ________________________
run(m)

path = joinpath(@__DIR__, "../Scenarios_results/xi=-1/DU/no_rec_opt_tax.csv") # path = "Scenarios_results/DU_no_rec_opt_tax.csv"
optimize_NICE(m, aggr_fun,utility_type = utility_type, revenue_recycle = rr, active_controls = a_c, save_file_path = path)

run(m)
Mimi.explore(m)

# optimize_NICE(m, aggr_fun,utility_type = utility_type, revenue_recycle = rr, active_controls = a_c, global_stop_time = 5, local_stop_time = 1, save_file_path = path)
# optimize_NICE(m, sum, revenue_recycle = rr, active_controls = a_c, global_stop_time = 5, local_stop_time = 1, save_file_path = path)