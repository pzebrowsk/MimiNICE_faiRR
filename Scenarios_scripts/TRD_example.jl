# Script generating example for the triple resilience dividend paper

#= 
Idea of the example: 
compare DU vs BAU <- action without co-benefits
compare DP vs DP <- assess impact of fairness: Gini, share of poorest quintile as measures of 3rd div, changes in consumption of quintiles as 2nd div ?
=#

using Mimi
using Revise
using PlotlyJS
using DataFrames
using MimiNICE_faiRR


include("../src/nice_fairr_helper_functions/optimize_NICE_faiRR_helpers.jl")
include("../src/nice_fairr_helper_functions/fair_aggregating_functions.jl")


# # # # BAU model : fixed savings, no abatement
m_BAU = get_model()

damage_elasticity = -0.5 #0.5
update_param!(m_BAU, :damage_elasticity, damage_elasticity)
run(m_BAU)

# Mimi.explore(m_BAU)


# # # # DU_model : NICE with no revenue recycling, discounted utilitarianism (total welfare maximization)
m_DU = get_model()
ρ = 0.015
eta = 1.5
η = eta * ones(length(dim_keys(m_DU, :regions)))     
damage_elasticity = -0.5 #0.5
#zero-in utilities
c_poverty = 0.5 # 500.0$ (cf. Adler 2017 p.444) = 0.5 thousands $ (units of consumption in the model)
u_0 = (c_poverty ^ (1.0 - eta)) / (1.0 - eta) .* ones(length(dim_keys(m_DU, :time)), length(dim_keys(m_DU, :regions))) #use Atkinson_fun here


update_param!(m_DU, :rho, ρ)
update_param!(m_DU, :eta, η)
update_param!(m_DU, :damage_elasticity, damage_elasticity)
update_param!(m_DU, :u_zero, u_0)

run(m_DU)

# Choice about recucling revenue
#rr = false
rr = true

# Utility type and aggregating function
utility_type = "total_reg"
aggr_fun = sum

path = joinpath(@__DIR__, "../Scenarios_results/TRD_paper_example/NICE_no_rr_du.csv") 
# optimize_NICE(m_DU, aggr_fun,utility_type = utility_type, revenue_recycle = rr, active_controls = "tax_and_savings", save_file_path = path)
optimize_NICE(m_DU, aggr_fun,utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", save_file_path = path)

run(m_DU)
# Mimi.explore(m_DU)





# # # # DP_model : NICE with no revenue recycling, discounted prioritarian approach
m_DP = get_model()
run(m_DP)
# explore(m_DP)

ρ = 0.015       #this is not needed NP_SWF does not use ρ
eta = 1.5
η = eta * ones(length(dim_keys(m_DP, :regions)))     
damage_elasticity = -0.5 #0.5


update_param!(m_DP, :rho, ρ)
update_param!(m_DP, :eta, η)
update_param!(m_DP, :damage_elasticity, damage_elasticity)
run(m_DP)

c_0 = 0.9 * minimum(m_DP[:nice_recycle, :qc_post_recycle]) 
u_0 = Atkinson_fun(c_0, eta) .* ones(length(dim_keys(m_DP, :time)), length(dim_keys(m_DP, :regions)))
update_param!(m_DP, :u_zero, u_0)

run(m_DP)


utility_type = "indiv"
γ = 1.1 #2.0
q_pop = m_DP[:nice_fairr_reg_utils, :quintile_pop]
t = 0:length(dim_keys(m_DP, :time))-1
discount_factors = (1+ρ).^(-t)

function DP_SWF(u, q_pop, γ, discount_factors)

    if γ != 1
        z = (u.^ (1.0 - γ)) ./ (1.0 - γ)
    else
        z = log.(u)
    end

    return sum(z .* q_pop .* discount_factors)
end


aggr_fun = x -> DP_SWF(x, q_pop, γ, discount_factors)

# aggr_fun(m_DP[:nice_fairr_reg_utils, :indiv_utils])

# Choice about recucling revenue
# rr = false
rr = true


path = joinpath(@__DIR__, "../Scenarios_results/TRD_paper_example/NICE_no_rr_dp.csv") 
optimize_NICE(m_DP, aggr_fun, utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", global_tolerance = 1e-12, local_tolerance = 1e-12, save_file_path = path)
# optimize_NICE(m_DP, aggr_fun, utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", global_opt_algorithm = :LN_COBYLA, global_tolerance = 1e-12, local_tolerance = 1e-12, save_file_path = path)

run(m_DP)
#Mimi.explore(m_DP)


### 1st dividend assessment: percentage change in (absolute) damages
### quantification percentage change of damages in DP compared to DU


damages_df = getdataframe(m_BAU, :damages=>:DAMAGES)
rename!(damages_df, :DAMAGES => :DAMAGES_BAU)
damages_df[!, :DAMAGES_DU] = getdataframe(m_DU, :damages=>:DAMAGES)[:, "DAMAGES"]
damages_df[!, :DAMAGES_DP] = getdataframe(m_DP, :damages=>:DAMAGES)[:, "DAMAGES"]
# insertcols!(damages_df, :dam_change => (damages_df.DAMAGES_DP .- damages_df.DAMAGES_DU)./damages_df.DAMAGES_DU)
insertcols!(damages_df, :dam_change => ((damages_df.DAMAGES_BAU - damages_df.DAMAGES_DP) .- (damages_df.DAMAGES_BAU - damages_df.DAMAGES_DU))./(damages_df.DAMAGES_BAU - damages_df.DAMAGES_DU))

p1 = Plot(damages_df[damages_df.time .<=2150, :], x = :time, y = :dam_change, color = :regions)



### 2nd dividend assessment: percentage change of unlocked econ growth (relative to BAU with no mitigation)



Y_df = getdataframe(m_BAU, :nice_neteconomy=>:Y)
rename!(Y_df, :Y => :Y_BAU)
Y_df[!, :Y_DU] = getdataframe(m_DU, :nice_neteconomy=>:Y)[:, "Y"]
Y_df[!, :Y_DP] = getdataframe(m_DP, :nice_neteconomy=>:Y)[:, "Y"]
#insertcols!(Y_df, :Y_change => ((Y_df.Y_DP - Y_df.Y_DU)./Y_df.Y_DU))# .- (Y_df.Y_BAU - Y_df.Y_DU))./(Y_df.Y_BAU - Y_df.Y_DU))
# insertcols!(Y_df, :Y_change => ((Y_df.Y_BAU - Y_df.Y_DP) .- (Y_df.Y_BAU - Y_df.Y_DU))./(Y_df.Y_BAU - Y_df.Y_DU))
#insertcols!(Y_df, :Y_change => ((Y_df.Y_BAU - Y_df.Y_DP) .- (Y_df.Y_BAU - Y_df.Y_DU)))

insertcols!(Y_df, :Y_change => (Y_df.Y_DP - Y_df.Y_BAU)./Y_df.Y_BAU)
# insertcols!(Y_df, :Y_change => (Y_df.Y_DP - Y_df.Y_BAU))
p2 = Plot(Y_df[Y_df.time .<=2150, :], x = :time, y = :Y_change, color = :regions)

Plot(Y_df[Y_df.time .<=2150, :], x = :time, y = :Y_DU, color = :regions)
Plot(Y_df[Y_df.time .<=2150, :], x = :time, y = :Y_DP, color = :regions)


#consumption
CPC_df = getdataframe(m_BAU, :nice_neteconomy=>:CPC)
rename!(CPC_df, :CPC => :CPC_BAU)
CPC_df[!, :CPC_DU] = getdataframe(m_DU, :nice_neteconomy=>:CPC)[:, "CPC"]
CPC_df[!, :CPC_DP] = getdataframe(m_DP, :nice_neteconomy=>:CPC)[:, "CPC"]
# insertcols!(CPC_df, :CPC_change => (CPC_df.CPC_DP - CPC_df.CPC_DU)./CPC_df.CPC_DU)
insertcols!(CPC_df, :CPC_change => (CPC_df.CPC_DP - CPC_df.CPC_DU))
# insertcols!(CPC_df, :CPC_change => (CPC_df.CPC_DP - CPC_df.CPC_BAU))
# p2 = Plot(CPC_df[CPC_df.time .<=2150, :], x = :time, y = :CPC_change, color = :regions)
p2 = Plot(CPC_df[CPC_df.time .<=2300, :], x = :time, y = :CPC_change, color = :regions)



Plot(CPC_df[CPC_df.time .<=2150, :], x = :time, y = :CPC_DU, color = :regions)
Plot(CPC_df[CPC_df.time .<=2150, :], x = :time, y = :CPC_DP, color = :regions)


#consumption post damage by quintiles
qcp_df = getdataframe(m_BAU, :nice_recycle => :qc_post_recycle)
rename!(qcp_df, :qc_post_recycle => :qcp_BAU)
qcp_df[!, :qcp_DU] = getdataframe(m_DU, :nice_recycle => :qc_post_recycle)[:, "qc_post_recycle"]
qcp_df[!, :qcp_DP] = getdataframe(m_DP, :nice_recycle => :qc_post_recycle)[:, "qc_post_recycle"]
# Add population of quintiles (to convert per capita consumption into total consumption) [Is this necessary?]
#qcp_df[!, :L] = getdataframe(m_BAU, :grosseconomy => :L)[:, "L"]    #this should be converted to population of quintiles (5 times larger)

#group by regions and time
gcp_gr = groupby(qcp_df, ["regions", "time"])
#multiply by population ?
cons_df = combine(gcp_gr, :qcp_BAU => sum)
rename!(cons_df, :qcp_BAU_sum => :cons_BAU)
cons_df[!, :cons_DU] = combine(gcp_gr, :qcp_DU => sum)[:, "qcp_DU_sum"]
cons_df[!, :cons_DP] = combine(gcp_gr, :qcp_DP => sum)[:, "qcp_DP_sum"]

insertcols!(cons_df, :cons_change => (cons_df.cons_DP - cons_df.cons_BAU))
# insertcols!(cons_df, :cons_change => ((cons_df.cons_DP - cons_df.cons_DU)./cons_df.cons_BAU))
Plot(cons_df[cons_df.time .<=2150, :], x = :time, y = :cons_change, color = :regions)


Plot(cons_df[cons_df.time .<=2150, :], x = :time, y = :cons_DU, color = :regions)
Plot(cons_df[cons_df.time .<=2150, :], x = :time, y = :cons_DP, color = :regions)



#Gini
function Gini(x)
    return sum([abs(a - b) for a in x, b in x])/(2*length(x)*sum(x))
end

gini_df = combine(gcp_gr, :qcp_BAU => Gini)
rename!(gini_df, :qcp_BAU_Gini => :gini_BAU)
gini_df[!, :gini_DU] = combine(gcp_gr, :qcp_DU => Gini)[:, "qcp_DU_Gini"]
gini_df[!, :gini_DP] = combine(gcp_gr, :qcp_DP => Gini)[:, "qcp_DP_Gini"]

insertcols!(gini_df, :gini_change => ((gini_df.gini_DP - gini_df.gini_DU)./gini_df.gini_DU))
Plot(gini_df[gini_df.time .<=2150, :], x = :time, y = :gini_change, color = :regions)


Plot(gini_df[gini_df.time .<=2150, :], x = :time, y = :gini_DU, color = :regions)
