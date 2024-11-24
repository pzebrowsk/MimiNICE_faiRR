include("../src/nice_fairr_helper_functions/optimize_NICE_faiRR_helpers.jl")

m = get_model()
run(m)

save_results_path = "test results/test1.csv" #"../test results/test1.csv" #joinpath(dirname(dirname(@__DIR__)), "test_results", "test1.csv")
optimize_NICE(m, sum, active_controls ="tax_and_savings", global_stop_time = 1, local_stop_time = 1, save_file_path = save_results_path)