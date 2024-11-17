using Mimi
using Revise
#using MimiNICE_faiRR

m = MimiNICE_faiRR.get_model()

run(m)

Mimi.explore(m)