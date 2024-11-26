using Revise
using PlotlyJS


include("../src/nice_fairr_helper_functions/optimize_NICE_faiRR_helpers.jl")
include("../src/nice_fairr_helper_functions/fair_aggregating_functions.jl")

m = MimiNICE_faiRR.get_model()
run(m)

m[:nice_fairr_reg_utils, :indiv_utils]
m[:nice_neteconomy, :quintile_c_post]
minimum(m[:nice_neteconomy, :quintile_c_post])

Mimi.explore(m)







## optimize carbon tax using NICE with revenue recycle and NP SWF
m_NICE_rr_NP = get_model()
run(m_NICE_rr_NP)
# explore(m_NICE_rr_NP)

ρ = 0.001       #this is not needed NP_SWF does not use ρ
eta = 1.5
η = eta * ones(length(dim_keys(m_NICE_rr_NP, :regions)))     
damage_elasticity = -0.5 #0.5
# c_0 = 0.9 * minimum(m_NICE_rr_NP[:nice_recycle, :qc_post_recycle]) #minimum(m[:nice_neteconomy, :quintile_c_post])
# #c_0 = disallowmissing(c_0)
# u_0 = Atkinson_fun(c_0, eta) .* ones(length(dim_keys(m_NICE_rr_NP, :time)), length(dim_keys(m_NICE_rr_NP, :regions)))


update_param!(m_NICE_rr_NP, :rho, ρ)
update_param!(m_NICE_rr_NP, :eta, η)
update_param!(m_NICE_rr_NP, :damage_elasticity, damage_elasticity)
run(m_NICE_rr_NP)

minimum(m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils])

c_0 = 0.9 * minimum(m_NICE_rr_NP[:nice_recycle, :qc_post_recycle]) #minimum(m[:nice_neteconomy, :quintile_c_post])
#c_0 = disallowmissing(c_0)
u_0 = Atkinson_fun(c_0, eta) .* ones(length(dim_keys(m_NICE_rr_NP, :time)), length(dim_keys(m_NICE_rr_NP, :regions)))
update_param!(m_NICE_rr_NP, :u_zero, u_0)



run(m_NICE_rr_NP)

m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils]
minimum(m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils])

# Utility type and aggregating function
# utility_type = "indiv"
# γ = 1.1 #2.0
# aggr_fun = x -> Atkinson_fun(x, γ)

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

# #test of NP_SWF
u = m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils]
q_pop = m_NICE_rr_NP[:nice_fairr_reg_utils, :quintile_pop]
γ = 1.1

(u.^ (1.0 - γ)) ./ (1.0 - γ)
u .* q_pop
sum(u .* q_pop)

NP_SWF(u, q_pop, γ)

aggr_fun = x -> NP_SWF(x, q_pop, γ)
#aggr_fun = x -> Atkinson_fun(x, γ)

aggr_fun(m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils])

# Choice about recucling revenue
rr = true


path = joinpath(@__DIR__, "../Scenarios_results/SYRR_seminar/NICE_rr_NP_opt_tax.csv") 
optimize_NICE(m_NICE_rr_NP, aggr_fun, utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", global_tolerance = 1e-12, local_tolerance = 1e-12, save_file_path = path)
# optimize_NICE(m_NICE_rr_NP, aggr_fun, utility_type = utility_type, revenue_recycle = rr, active_controls = "tax", global_opt_algorithm = :LN_COBYLA, global_tolerance = 1e-12, local_tolerance = 1e-12, save_file_path = path)

run(m_NICE_rr_NP)
Mimi.explore(m_NICE_rr_NP)



#m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils] .* m_NICE_rr_NP[:nice_fairr_reg_utils, :quintile_pop]
#sum(m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils] .* m_NICE_rr_NP[:nice_fairr_reg_utils, :quintile_pop])

#NP_SWF(m_NICE_rr_NP[:nice_fairr_reg_utils, :indiv_utils], m_NICE_rr_NP[:nice_fairr_reg_utils, :quintile_pop], 1.1)