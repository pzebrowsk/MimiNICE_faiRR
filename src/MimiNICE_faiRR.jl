module MimiNICE_faiRR

using MimiNICE_revenue_recycle
using Mimi 
using Revise

include(joinpath("nice_fairr_components", "nice_fairr_reg_utils_component.jl"))     # component with individual and regional utilities, calculated as Atkinson function (or constant relative risk aversion (CRRA) function,cf. Adler 2017 Methods) of per capita consumption with region-specific elasticities (eta, marginal utility of consumption).

export get_model



"""
    get_model()

Function to build the MimiNICE_faiRR model
"""
function get_model()

    # Initialize model as MimiNICE_revenue_recycle
    m = MimiNICE_revenue_recycle.create_nice_recycle()     
    
    run(m)

    # Delete NICE welfare (to be replaced by regional utilities and SWF components).
    quintile_population = m[:nice_welfare, :quintile_pop]
    delete!(m, :nice_welfare)
    delete_param!(m, :eta)
    delete_param!(m, :rho)

    # Add regional utilities component.
    add_comp!(m, nice_fairr_reg_utils, after = :nice_recycle)
    

    # Set new NICE_F component parameters for nice_fairr_reg_utils.
    set_param!(m, :nice_fairr_reg_utils, :eta, ones(length(dim_keys(m, :regions))).*1.5) 
    set_param!(m, :nice_fairr_reg_utils, :rho, 0.015)
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
