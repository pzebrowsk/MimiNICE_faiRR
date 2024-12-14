using Missings
# using Revise

#Atkinson function does not work properly for negative x
# shift utiliities by 1200 so that all regional utilites in NICE are positive (find more elegant solution)
function Atkinson_fun(x, gamma)
    #x = disallowmissing(x) 
    if gamma != 1
        return sum((x.^ (1.0 - gamma)) ./ (1.0 - gamma))
    else
        return sum(log.(x))
    end
end

function type_2_achievement_fun(x, alpha)
    return minimum(x) + alpha * sum(x)
end

# this implementation of Gini index may not work for arrays (only for 1D vectors), elements of x assumed to be non-negative
function Gini(x)
    return sum([abs(a - b) for a in x, b in x])/(2*length(x)*sum(x))
end



