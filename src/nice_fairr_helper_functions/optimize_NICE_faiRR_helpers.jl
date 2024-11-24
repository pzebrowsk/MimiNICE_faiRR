#=
Functions to run optimization of the NICE_faiRR model.

Possible decision variables: carbon tax rates ($/ton CO2), saving rates (fraction of gross economic output). Decision variables organized as follows: rows: time; columns: tax rates by regions followed by saving rates by regions.

Carbon tax rates define optimal mitigation rates: optimal mitigation rate is the one for which marginal abatement cost equals carbon tax (then you would rather stop mitigating and start paying the tax for unmitigated emissions).

NOTE: Currently, this version does not support regionally differentiated carbon taxes (only uniform global tax). Implementing local carbon tax requires modification in nice_revenue_recycle_component_time_varying.jl in MimiNICE_revenue_recycle.jl. Change global_carbon_tax = Parameter(index=[time]) to carbon_tax = Parameter(index=[time,regions]) and v.tax_revenue (line 73). ]

TO DO: consider saving results of optimization as DataFrame (currently plain .csv)
=#


using Missings
using NLopt
using DelimitedFiles
#using DataFrames
using Mimi
using Revise


"""
    miu_from_global_tax(m::Model, global_carbon_tax)

Calculate regional mitigation rates that are optimal given the gloabl_carbon_tax. Idea: regions mitigate emissions until marginal costs of mitigation reach carbon price (carbon tax), at which point it is cheaper to pay tax for the remaining unmitigated emissions rather than to pay for further mitigation.
"""
function miu_from_global_tax(m::Model, global_carbon_tax)
    rice_backstop_prices = m[:emissions, :pbacktime] .* 1000
    theta2 = m[:emissions, :expcost2]
    theta2 = disallowmissing(theta2')       #so that columns of rice_backstop_prices aling with columns of theta2 (now 1 x 12 row vector)
    
    # calculate optimal mu given a level of global carbon tax. (cf. mu_from_tax() revenue_recycling/src/helper_functions.jl line 263)
    miu = min.((max.(((global_carbon_tax ./ rice_backstop_prices) .^ (1 ./ (theta2 .- 1.0))), 0.0)), 1.0) # (min / max so that miu is in [0,1])
    
    return miu
end



"""
    create_SWF_and_init_controls(m::Model, aggr_fun::Function; utility_type = "total_reg", active_time_steps = "all", active_controls = "tax_and_savings", use_global_carbon_tax = true)

Function creating a social welfare function (SWF) for model m by aggregating regional utilities with aggregating function aggr_fun. utility_type = { "indiv" | "reg" | "total_reg" } (cf. different types of regional utilities in nice_fairr_reg_utils_component.jl). Time steps for which controls are to be optimized are given by active_time_steps (set to "all" by default, in which case no exclusions are made). Controls to be optimized are give by active_controls = {"tax" | "savings" | "tax_and_savings"}. By default, use_global_carbon_tax = true, in which case in each individual time step carbon tax rates are equal for all regions. If use_global_carbon_tax = false, carbon tax rates differ accross regions. 

In addition to SWF, function returns vectors of initial controls init_controls and max_controls. init_controls are constructed from initial values of active decision variables, as they were set when model m was passed to this function. max_controls are the maximal allowed values for controls (to be used as upper bound in optimization).


[WARNING! carbon_tax_type = "local" not implemented yet. Local carbon tax requires modification in nice_revenue_recycle_component_time_varying.jl in MimiNICE_revenue_recycle.jl. Change global_carbon_tax = Parameter(index=[time]) to carbon_tax = Parameter(index=[time,regions]) and v.tax_revenue (line 73). ]

NOTE: Set the initial values of decision variables in m (both active and inactive) before calling create_SWF(m, aggr_fun). (E.g., set saving rates or a given trajectory of tax for 2C scenario before calling this function). A vector of initial controls (argument of SWF) will be constructed from values of active decision variables. Model m must have status Built: true before passing it th this function (e.g., run(m) first).

TO DO:
1. Add selection of regions (default active_regions = "all")? Same mechanism as active_time_steps. (If excluding regions from optimization makes sense.) 
"""
function create_SWF_and_init_controls(m::Model, aggr_fun::Function; utility_type = "total_reg", active_time_steps = "all", active_controls = "tax_and_savings", use_global_carbon_tax = true)

    # initial decision variables 
    if use_global_carbon_tax
        init_dec_vars = [m[:nice_recycle, :global_carbon_tax] m[:nice_neteconomy, :S]] #global carbon tax stored in the first column 
    else
        init_dec_vars = [m[:nice_recycle, :tax] m[:nice_neteconomy, :S]]     # WARNING: Requires nice_recycle to be updated with region-specific tax
    end

    # maximal allowed values of decision variables 
    rice_backstop_prices = m[:emissions, :pbacktime] .* 1000
    if use_global_carbon_tax
        max_dec_vars = [maximum(rice_backstop_prices, dims=2) ones(size(m[:nice_neteconomy, :S]))] #global carbon tax stored in the first column 
    else
        max_dec_vars = [rice_backstop_prices ones(size(m[:nice_neteconomy, :S]))]     # WARNING: Requires nice_recycle to be updated with region-specific tax
    end

    # # # Prepare mask for active dec_vars                  (consider generating a mask into a function, could be useful elswhere)
    dec_vars_on_mask = ones(size(init_dec_vars))

    # set rows for inactive times to 0 (i.e., deactivate dec variables for that times)
    if active_time_steps != "all"
        dec_vars_on_mask[ [!(t in active_time_steps) for t in dim_keys(m, :time)] .== true, :] .= 0
    end

    # set blocks of columns for inactive controls to 0
    if active_controls == "savings" #in this case deactivate tax
        if use_global_carbon_tax
            dec_vars_on_mask[:, 1] .= 0 #gloal carbon tax stored in the first column of dec_vars
        else
            dec_vars_on_mask[:, 1:length(dim_keys(m, :regions))] .= 0 #carbon tax stored for regions stored at the beginning of dec_vars 
        end
    elseif active_controls == "tax" #in this case deactivate savings
        dec_vars_on_mask[:, end-length(dim_keys(m, :regions))+1:end] .= 0      
    end

    init_controls = init_dec_vars[dec_vars_on_mask .== 1]
    max_controls = max_dec_vars[dec_vars_on_mask .== 1]


    # # # Create SWF
    #choose type of utilites to be aggregated with aggr_fun
    if utility_type == "indiv"
        utils_symbol = :indiv_utils
    elseif utility_type == "reg"
        utils_symbol = :reg_utils
    elseif utility_type == "total_reg"
        utils_symbol = :total_reg_utils
    end

    #generate SWF
    SWF = 
        if use_global_carbon_tax
            function(x)
                #get current values of decision variables
                dec_vars = [m[:nice_recycle, :global_carbon_tax] m[:nice_neteconomy, :S]]
                #set values for active dec_vars
                dec_vars[dec_vars_on_mask .== 1] = x
                #update global tax
                gct = dec_vars[:,1]     #Missing.disallowmissing here?
                set_param!(m, :global_carbon_tax, gct)
                
                #calculate and update mius
                miu = miu_from_global_tax(m, gct)
                update_param!(m, :MIU, miu)
                
                #update savings
                update_param!(m, :S, dec_vars[:, end-length(dim_keys(m, :regions))+1:end])   

                run(m)
                return aggr_fun(m[:nice_fairr_reg_utils, utils_symbol])
            end
        else
            function(x)
                #new function miu_from_local_tax() will be needed here
                return NaN
            end
        end

    return SWF, init_controls, max_controls
end



"""
    optimize_NICE(m::Model, aggr_fun::Function; utility_type = "total_reg", active_time_steps = "all", active_controls = "tax_and_savings", use_global_carbon_tax = true, global_opt_algorithm::Symbol = :LN_SBPLX, local_opt_algorithm::Symbol = :LN_SBPLX, global_stop_time = 600, local_stop_time = 300, global_tolerance = 1e-8, local_tolerance = 1e-8, save_file_path = nothing)

Function optimizing SWF defined by aggr_fun in the model m and saving the results. 

NOTES:
For details of optimization algorithm (:symbol) see http://ab-initio.mit.edu/wiki/index.php/NLopt_Algorithms
GN_DIRECT_L (and other global optimization algorithms) appear to be working worse than local algorithms. In the first we use LN_SBPLX by default (appears the fastes for our problem), though it is not a global optimization algorithm (according to NLopt page).
"""
function optimize_NICE(m::Model, aggr_fun::Function; utility_type = "total_reg", active_time_steps = "all", active_controls = "tax_and_savings", use_global_carbon_tax = true, global_opt_algorithm::Symbol = :LN_SBPLX, local_opt_algorithm::Symbol = :LN_SBPLX, global_stop_time = 600, local_stop_time = 300, global_tolerance = 1e-8, local_tolerance = 1e-8, save_file_path = nothing)
    #Setup summary
    println("")
    println("Optimization of the NICE model")
    println("global_opt_algorithm = ", global_opt_algorithm, ", local_opt_algorithm = ", local_opt_algorithm)
    println("use_global_carbon_tax = ", use_global_carbon_tax)
    println("")

    #Generate SWF and get initial controls (from initial state of m)
    swf, x_0, upper_bounds = create_SWF_and_init_controls(m, aggr_fun, utility_type = utility_type, active_time_steps = active_time_steps, active_controls = active_controls, use_global_carbon_tax = use_global_carbon_tax)

    n_objectives = length(x_0)

    #report initial state
    println("n_objectives = ", n_objectives)
    println("SWF(initial_controls) = ", swf(x_0))
    println("") 


    # # # First stage optimization
    println("First stage: global optimization")

    #set up NLopt optimization object
    objective_opt_global = Opt(global_opt_algorithm, n_objectives)

    # Set upper and lower bounds 
    lower_bounds = zeros(n_objectives)
    #upper_bounds from create_SWF_and_init_controls

    lower_bounds!(objective_opt_global, lower_bounds)
    upper_bounds!(objective_opt_global, upper_bounds)

    # Set max run time 
    maxtime!(objective_opt_global, global_stop_time)

    # Set convergence tolerance.
    ftol_rel!(objective_opt_global, global_tolerance)

    # Set the objective function.
    max_objective!(objective_opt_global, (x, grad) -> swf(x))      #do global algorithm maximize?
    #max_objective!(objective_opt_global, (x, grad) -> -swf(x))

    # Set start point for optimization
    start_point = disallowmissing(x_0)   #### ELIMINATING MISSINGS IS IMPORTANT!!!


    # optimize
    @time begin
        (opt_swf_val, opt_controls, ref_conv) = optimize(objective_opt_global, start_point)
    end

    println("Global optimization results:")
    println("Convergence result = ", ref_conv)
    println("Achieved SWF value = ", opt_swf_val)
    println("")


     # # # Second stage optimization
    println("Second stage: local optimization")

    # Set up NLopt optimization object
    objective_opt_local = Opt(local_opt_algorithm, n_objectives)

    # Set upper and lower bounds (use the same bounds as in the first stage)
    lower_bounds!(objective_opt_local, lower_bounds)
    upper_bounds!(objective_opt_local, upper_bounds)

    # Set max run time 
    maxtime!(objective_opt_local, local_stop_time)

    # Set convergence tolerance.
    ftol_rel!(objective_opt_local, local_tolerance)

    # Set the objective function.
    max_objective!(objective_opt_local, (x, grad) -> swf(x))

    # Set start point for optimization
    start_point = opt_controls

    # optimize
    @time begin
        (opt_swf_val, opt_controls, ref_conv) = optimize(objective_opt_local, start_point)
    end    

    println("Local optimization results:")
    println("Convergence result = ", ref_conv)
    println("Achieved SWF value = ", opt_swf_val)
    println("")

    # save results
    run(m)      #not needed?

    #save all decision variables (not only active controls) so that the model could be re-runned from saved results (active controls without a mask are useless).
    if use_global_carbon_tax
        opt_dec_vars =  [m[:nice_recycle, :global_carbon_tax] m[:nice_neteconomy, :S]] #global carbon tax stored in the first column 
        # opt_dec_vars =  DataFrame([m[:nice_recycle, :global_carbon_tax] m[:nice_neteconomy, :S]], :auto) #this works OK but index (years) and column names need to be added
    else
        #opt_dec_vars =  [m[:nice_recycle, :tax] m[:nice_neteconomy, :S]]     # WARNING: Requires nice_recycle to be updated with region-specific tax
    end
    
    if !isnothing(save_file_path)
        mkpath(dirname(save_file_path))
        writedlm(save_file_path, opt_dec_vars, ',')     #this works for CSV
        #save(save_file_path, opt_dec_vars) #This works with saving DataFrames
    end


    return (opt_swf_val, opt_controls, ref_conv)

end




#### TESTS

# # Test miu_from_global_tax()
# miu_from_global_tax(m, m[:nice_recycle, :global_carbon_tax])


# ####Test create_SWF_and_init_controls()
# # m = MimiNICE_faiRR.get_model()

# swf, x_0, u_b = create_SWF_and_init_controls(m, sum, utility_type = "reg")

# x = [m[:nice_recycle, :global_carbon_tax] m[:nice_neteconomy, :S]]
# x = disallowmissing(vec(x))

# swf(x)
# swf(x_0)
# sum(m[:nice_fairr_reg_utils, :reg_utils])


# ### Test optimize_NICE()
# m = get_model()
# run(m)
# optimize_NICE(m, sum, active_controls ="tax", global_opt_algorithm = :LN_SBPLX, local_opt_algorithm = :LN_COBYLA) 
# # optimize_NICE(m, sum, active_controls ="tax")
# # optimize_NICE(m, sum, active_controls ="tax_and_savings", global_opt_algorithm = :LN_COBYLA, global_stop_time = 100, local_stop_time = 100)
# # optimize_NICE(m, sum, active_controls ="tax_and_savings", global_opt_algorithm = :GD_STOGO_RAND, global_stop_time = 100, local_stop_time = 100)
# # optimize_NICE(m, sum, active_controls ="tax", global_opt_algorithm = :LN_COBYLA, global_stop_time = 6)
# # optimize_NICE(m, sum, active_controls ="tax_and_savings", global_stop_time = 10, local_stop_time = 60)

# sum(m[:nice_fairr_reg_utils, :reg_utils])
# Mimi.explore(m)




