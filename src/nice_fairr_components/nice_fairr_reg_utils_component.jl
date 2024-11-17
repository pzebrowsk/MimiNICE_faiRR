@defcomp nice_fairr_reg_utils begin

    regions         = Index()                                     # Index for RICE regions.
    quintiles       = Index()                                     # Index for regional income quintiles.

    eta             = Parameter(index=[regions])                  # Elasticities of marginal utility of consumption for regions.
    rho             = Parameter()                                 # Pure rate of time preference.
    quintile_pop    = Parameter(index=[time, regions])            # Quintile population levels for each region.
    quintile_c      = Parameter(index=[time, regions, quintiles]) # Post-damage, post-abatement cost quintile consumption (thousands 2005 USD yr⁻¹).

    indiv_utils     = Variable(index=[time, regions, quintiles])  # Utility of individual person 
    reg_utils       = Variable(index=[time, regions])             # Aggregate utility of individual regions (discounted)
    total_reg_utils = Variable(index=[regions])                   # Total (discounted) aggregate utility of individual regions

    function run_timestep(p, v, d, t)



        for r in d.regions
            # # v.indiv_utils[t, r, :] = util_of_pcc(p.quintile_c[t,r,:], p.eta[r])
            # for q in d.quintiles
            #     v.indiv_utils[t, r, q] = util_of_pcc(p.quintile_c[t,r,q], p.eta[r])
            # end

            if p.eta[r] != 1
                v.indiv_utils[t, r, :] = (p.quintile_c[t,r,:].^ (1.0 - p.eta[r])) ./ (1.0 - p.eta[r])
            else
                v.indiv_utils[t, r, :] = log.(p.quintile_c[t,r,:])
            end

            v.reg_utils[t, r] = sum(v.indiv_utils[t,r,:] .* p.quintile_pop[t,r]) ./ (1.0 + p.rho)^(10*(t.t-1))

            if is_first(t)
                # Calculate period 1 glob_util.
                v.total_reg_utils[r] = v.reg_utils[t,r]
            else
                # Calculate cummulative glob_util over time.
                v.total_reg_utils[r] = v.total_reg_utils[r] + v.reg_utils[t,r]
            end
        end
    end

end #end defcomp


## this was before @defcomp
# """
#     util_of_pcc(c, eta)

# Function transforming per capita consumption into utility, assuming constant elasticity of marginal utility of consumption.
#         c:      per capita consumption
#         eta:    elasticity of marginal utility of consumption (reflect the diminishing returns form marginal increases of per capita consumption)
# """
# function util_of_pcc(c, eta)
    
#     if eta != 1
#         return (c.^ (1.0 - eta)) ./ (1.0 - eta)
#     else
#         return log.(c)
#     end

# end


