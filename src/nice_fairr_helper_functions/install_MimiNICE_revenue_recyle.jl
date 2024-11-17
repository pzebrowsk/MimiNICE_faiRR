# script installing MimiNICE_revenue_recycle model from github
# These are instructions for instalation. Better to put them in README

using Pkg

pkg"add CSVFiles"
pkg"add DataFrames"
pkg"add Interpolations"
pkg"add Mimi"
pkg"add NLopt"

#install MimiRICE2010
pkg"registry add https://github.com/mimiframework/MimiRegistry.git"
pkg"add MimiRICE2010"

# install MimiNICE and MimiFAIR13
pkg"add https://github.com/Environment-Research/MimiNICE.jl.git"
pkg"add https://github.com/FrankErrickson/MimiFAIR13.jl.git"

# clone / downolad revenue_recycling Git repositort 

# set this folder as your working directory

pkg"add https://github.com/pzebrowsk/MimiNICE_revenue_recycleg.jl.git"
