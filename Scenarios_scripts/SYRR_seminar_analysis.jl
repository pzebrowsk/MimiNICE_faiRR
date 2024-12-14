#Script generating results presented on SYRR seminar on 26th Nov

using Revise
using PlotlyJS


include("../src/nice_fairr_helper_functions/optimize_NICE_faiRR_helpers.jl")
include("../src/nice_fairr_helper_functions/fair_aggregating_functions.jl")



### optimize carbon tax using RICE (i.e., NICE which acts as RICE)
m_RICE = get_model()

### set up params so that m_RICE behaves as RICE
ρ = 0.015
eta = 1.5
η = eta * ones(length(dim_keys(m_RICE, :regions)))     
damage_elasticity = 1.0 #ξ=1
income_dist = ones(length(dim_keys(m_RICE, :time)), length(dim_keys(m_RICE, :regions)), length(dim_keys(m_RICE, :quintiles))) .* 0.2
#u_0 = zeros(length(dim_keys(m_RICE, :time)), length(dim_keys(m_RICE, :regions)))
c_poverty = 0.5 # 500.0$ (cf. Adler 2017 p.444) = 0.5 thousands $ (units of consumption in the model)
u_0 = (c_poverty ^ (1.0 - eta)) / (1.0 - eta) .* ones(length(dim_keys(m_RICE, :time)), length(dim_keys(m_RICE, :regions))) #use Atkinson_fun here


update_param!(m_RICE, :rho, ρ)
update_param!(m_RICE, :eta, η)
update_param!(m_RICE, :damage_elasticity, damage_elasticity)
update_param!(m_RICE, :quintile_income_shares, income_dist)
update_param!(m_RICE, :u_zero, u_0)

run(m_RICE)

# Choice about recucling revenue
rr = false

# Utility type and aggregating function
utility_type = "total_reg"
aggr_fun = sum

path = joinpath(@__DIR__, "../Scenarios_results/SYRR_seminar/RICE_opt_tax.csv") 
optimize_NICE(m_RICE, aggr_fun,utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", save_file_path = path)

run(m_RICE)
Mimi.explore(m_RICE)

#get m_RICE optimal values of decision variables
tax_RICE = m_RICE[:nice_recycle, :global_carbon_tax]  
miu_RICE = m_RICE[:emissions, :MIU]
s_RICE = m_RICE[:nice_neteconomy, :S]






# get a clean NICE model and run it with optimal RICE controls
m_NICE = get_model()
ρ = 0.015
eta = 1.5
η = eta * ones(length(dim_keys(m_NICE, :regions)))     
damage_elasticity = -0.5 #0.5
# u_0 as for m_RICE  #u_0 = zeros(length(dim_keys(m_RICE, :time)), length(dim_keys(m_RICE, :regions)))

update_param!(m_NICE, :rho, ρ)
update_param!(m_NICE, :eta, η)
update_param!(m_NICE, :damage_elasticity, damage_elasticity)
update_param!(m_NICE, :u_zero, u_0)

update_param!(m_NICE, :global_carbon_tax, tax_RICE)
update_param!(m_NICE, :MIU, miu_RICE)
update_param!(m_NICE, :S, s_RICE)

run(m_NICE)
Mimi.explore(m_NICE)

# # Ad slide 6
# Result: same tepmerature and emissions, lower total welfare in NICE under optimal RICE carbon tax
# sum(m_RICE[:nice_fairr_reg_utils, :total_reg_utils])
# sum(m_NICE[:nice_fairr_reg_utils, :total_reg_utils])



### optimize carbon tax using NICE without revenue recycle
m_NICE_no_rr = get_model()
ρ = 0.015
eta = 1.5
η = eta * ones(length(dim_keys(m_NICE_no_rr, :regions)))     
damage_elasticity = -0.5 #0.5
# u_0 as for m_RICE  

update_param!(m_NICE_no_rr, :rho, ρ)
update_param!(m_NICE_no_rr, :eta, η)
update_param!(m_NICE_no_rr, :damage_elasticity, damage_elasticity)
update_param!(m_NICE_no_rr, :u_zero, u_0)

run(m_NICE_no_rr)

# Choice about recucling revenue
rr = false

# Utility type and aggregating function
utility_type = "total_reg"
aggr_fun = sum

path = joinpath(@__DIR__, "../Scenarios_results/SYRR_seminar/NICE_no_rr_opt_tax.csv") 
optimize_NICE(m_NICE_no_rr, aggr_fun,utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", save_file_path = path)

run(m_NICE_no_rr)
Mimi.explore(m_NICE_no_rr)

#get m_RICE optimal values of decision variables
tax_NICE_no_rr = m_NICE_no_rr[:nice_recycle, :global_carbon_tax]  
miu_NICE_no_rr = m_NICE_no_rr[:emissions, :MIU]
s_NICE_no_rr = m_NICE_no_rr[:nice_neteconomy, :S]



TATM_RICE  = getdataframe(m_RICE, :climatedynamics=>:TATM)
TATM_RICE[!, :model] .= "RICE"
TATM_NICE_no_rr  = getdataframe(m_NICE_no_rr, :climatedynamics=>:TATM)
TATM_NICE_no_rr[!, :model] .= "NICE_no_rr"
TATMs = vcat(TATM_RICE, TATM_NICE_no_rr)


### Plot on slide 7
Plot(TATMs[TATMs.time .<=2200, :], x = :time, y = :TATM, color = :model)
# sum(m_NICE_no_rr[:nice_fairr_reg_utils, :total_reg_utils])



### optimize carbon tax using NICE with revenue recycle
m_NICE_rr = get_model()
ρ = 0.015
eta = 1.5
η = eta * ones(length(dim_keys(m_NICE_rr, :regions)))     
damage_elasticity = -0.5 #0.5
# u_0 as for m_RICE  

update_param!(m_NICE_rr, :rho, ρ)
update_param!(m_NICE_rr, :eta, η)
update_param!(m_NICE_rr, :damage_elasticity, damage_elasticity)
update_param!(m_NICE_rr, :u_zero, u_0)

run(m_NICE_rr)

# Choice about recucling revenue
rr = true

# Utility type and aggregating function
utility_type = "total_reg"
aggr_fun = sum

path = joinpath(@__DIR__, "../Scenarios_results/SYRR_seminar/NICE_rr_opt_tax.csv") 
optimize_NICE(m_NICE_rr, aggr_fun,utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", save_file_path = path)

run(m_NICE_rr)
Mimi.explore(m_NICE_rr)

#get m_RICE optimal values of decision variables
tax_NICE_rr = m_NICE_rr[:nice_recycle, :global_carbon_tax]  
miu_NICE_rr = m_NICE_rr[:emissions, :MIU]
s_NICE_rr = m_NICE_rr[:nice_neteconomy, :S]


TATM_NICE_rr  = getdataframe(m_NICE_rr, :climatedynamics=>:TATM)
TATM_NICE_rr[!, :model] .= "NICE_rr"
TATMs = vcat(TATMs, TATM_NICE_rr)


### Plot on slide 9
Plot(TATMs[TATMs.time .<=2200, :], x = :time, y = :TATM, color = :model)
# sum(m_NICE_rr[:nice_fairr_reg_utils, :total_reg_utils])





### optimize carbon tax using NICE with revenue recycle and NP SWF
## optimize carbon tax using NICE with revenue recycle and NP SWF
m_NICE_rr_NP = get_model()
run(m_NICE_rr_NP)
# explore(m_NICE_rr_NP)

ρ = 0.001       #this is not needed NP_SWF does not use ρ
eta = 1.5
η = eta * ones(length(dim_keys(m_NICE_rr_NP, :regions)))     
damage_elasticity = -0.5 #0.5


update_param!(m_NICE_rr_NP, :rho, ρ)
update_param!(m_NICE_rr_NP, :eta, η)
update_param!(m_NICE_rr_NP, :damage_elasticity, damage_elasticity)
run(m_NICE_rr_NP)

# minimum(m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils])

c_0 = 0.9 * minimum(m_NICE_rr_NP[:nice_recycle, :qc_post_recycle]) #minimum(m[:nice_neteconomy, :quintile_c_post])
#c_0 = disallowmissing(c_0)
u_0 = Atkinson_fun(c_0, eta) .* ones(length(dim_keys(m_NICE_rr_NP, :time)), length(dim_keys(m_NICE_rr_NP, :regions)))
update_param!(m_NICE_rr_NP, :u_zero, u_0)



run(m_NICE_rr_NP)

m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils]
minimum(m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils])


utility_type = "indiv"
γ = 1.1 #2.0
q_pop = m_NICE_rr_NP[:nice_fairr_reg_utils, :quintile_pop]

function NP_SWF(u, q_pop, γ)

    if γ != 1
        z = (u.^ (1.0 - γ)) ./ (1.0 - γ)
    else
        z = log.(u)
    end

    return sum(z .* q_pop)
end


aggr_fun = x -> NP_SWF(x, q_pop, γ)

aggr_fun(m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils])

# Choice about recucling revenue
rr = true


path = joinpath(@__DIR__, "../Scenarios_results/SYRR_seminar/NICE_rr_NP_opt_tax.csv") 
optimize_NICE(m_NICE_rr_NP, aggr_fun, utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", global_tolerance = 1e-12, local_tolerance = 1e-12, save_file_path = path)
# optimize_NICE(m_NICE_rr_NP, aggr_fun, utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", global_opt_algorithm = :LN_COBYLA, global_tolerance = 1e-12, local_tolerance = 1e-12, save_file_path = path)

run(m_NICE_rr_NP)
Mimi.explore(m_NICE_rr_NP)

tax_NICE_rr_NP = m_NICE_rr_NP[:nice_recycle, :global_carbon_tax]  
miu_NICE_rr_NP = m_NICE_rr_NP[:emissions, :MIU]
s_NICE_rr_NP = m_NICE_rr_NP[:nice_neteconomy, :S]


TATM_NICE_rr_NP  = getdataframe(m_NICE_rr_NP, :climatedynamics=>:TATM)
TATM_NICE_rr_NP[!, :model] .= "NICE_rr_NP"
TATMs = vcat(TATMs, TATM_NICE_rr_NP)

### Plot on slide 12
Plot(TATMs[TATMs.time .<=2200, :], x = :time, y = :TATM, color = :model)
# sum(m_NICE_rr[:nice_fairr_reg_utils, :total_reg_utils])




# m_NICE_rr_NP = get_model()
# ρ = 0.001
# eta = 1.5
# η = eta * ones(length(dim_keys(m_NICE_rr_NP, :regions)))     
# damage_elasticity = -0.5 #0.5
# # u_0 as for m_RICE  

# update_param!(m_NICE_rr_NP, :rho, ρ)
# update_param!(m_NICE_rr_NP, :eta, η)
# update_param!(m_NICE_rr_NP, :damage_elasticity, damage_elasticity)
# update_param!(m_NICE_rr_NP, :u_zero, u_0)

# run(m_NICE_rr_NP)

# # Choice about recucling revenue
# rr = true

# # Utility type and aggregating function
# utility_type = "indiv"
# γ = 2.0 #1.1 #2.0
# aggr_fun = x -> Atkinson_fun(x, γ)

# path = joinpath(@__DIR__, "../Scenarios_results/SYRR_seminar/NICE_rr_NP_opt_tax.csv") 
# optimize_NICE(m_NICE_rr_NP, aggr_fun, utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", global_tolerance = 1e-12, local_tolerance = 1e-12, save_file_path = path)
# # optimize_NICE(m_NICE_rr_NP, aggr_fun, utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", global_opt_algorithm = :LN_COBYLA, global_tolerance = 1e-12, local_tolerance = 1e-12, save_file_path = path)

# run(m_NICE_rr_NP)
# Mimi.explore(m_NICE_rr_NP)

#get m_RICE optimal values of decision variables
tax_NICE_rr_NP = m_NICE_rr_NP[:nice_recycle, :global_carbon_tax]  
miu_NICE_rr_NP = m_NICE_rr_NP[:emissions, :MIU]
s_NICE_rr_NP = m_NICE_rr_NP[:nice_neteconomy, :S]


TATM_NICE_rr_NP  = getdataframe(m_NICE_rr_NP, :climatedynamics=>:TATM)
TATM_NICE_rr_NP[!, :model] .= "NICE_rr_NP"
TATMs = vcat(TATMs, TATM_NICE_rr_NP)

### Plot on slide 12
Plot(TATMs[TATMs.time .<=2200, :], x = :time, y = :TATM, color = :model)
# sum(m_NICE_rr[:nice_fairr_reg_utils, :total_reg_utils])


m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils]



#######-------------------
# # Share of carbon tax revenue that is lost and cannot be recycled (1 = 100% of revenue lost, 0 = nothing lost)
# lost_revenue_share = 0.0

# # Shares of regional revenues that are recycled globally as international transfers (1 = 100% of revenue recycled globally).
# global_recycle_share = zeros(12)

# # Share of recycled carbon tax revenue that each region-quintile pair receives (row = region, column = quintile)
# quintile_recycle_share = ones(12, 5) .* 0.2     #equal per capita distribution


# # Reference utility level u_zero
# u_0 = zeros(length(dim_keys(m, :time)), length(dim_keys(m, :regions)))


# update_param!(m, :rho, ρ)
# update_param!(m, :eta, η)
# update_param!(m, :damage_elasticity, damage_elasticity)
# update_param!(m, :lost_revenue_share, lost_revenue_share)
# update_param!(m, :global_recycle_share, global_recycle_share)  
# update_param!(m, :recycle_share, quintile_recycle_share)       
# #set_param!(m, :nice_fairr_reg_utils, :u_zero, u_0)
# update_param!(m, :u_zero, u_0)

# # Choice about recucling revenue
# rr = false

# # Utility type and aggregating function
# utility_type = "total_reg"
# aggr_fun = sum



#TATMs = reduce(vcat, [TATM_RICE TATM_NICE_no_rr], cols = :union)
#TATMs = vcat([TATM_RICE TATM_NICE_no_rr], cols = :union)


# # test of Plot
# #post-damage consumption of quintiles
# quint_cons = getdataframe(m_NICE, :nice_neteconomy=>:quintile_c_post)
# # Q1 consumption
# Q1 = quint_cons[quint_cons.quintiles .== "First", :]
# Q5 = quint_cons[quint_cons.quintiles .== "Fifth", :]
# #print(Q1[Q1.time .== 2195, :])
# #print(Q5[Q5.time .== 2195, :])


# # ### This replicates subplots ξ=1; BAU; Q5 and ξ=1; BAU; Q1 from figure S4. in supplementary materials to Denning et al. 2015
# Plot(Q1[Q1.time .<=2200, :], x = :time, y = :quintile_c_post, color = :regions)
# Plot(Q5[Q5.time .<=2200, :], x = :time, y = :quintile_c_post, color = :regions)