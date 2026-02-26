# Medium instance train maintenance

using JuMP.Containers, Random

include(joinpath(@__DIR__, "building_functions.jl"))


Random.seed!(67)


K=["k$i" for i in 1:4] # set of activities
R=["r$i" for i in 1:2] # set of resources
T=25 # time horizon
periods=0:T-1

p = rand(2:5, length(K))
p = DenseAxisArray(p, K)


I = rand(4:7, length(K))
I = DenseAxisArray(I, K)


l_bar = [rand(0:I[k]) for k in K]
l_bar = DenseAxisArray(l_bar, K)


U = 900 


A_t = build_travel_arcs(K, T, I, l_bar)
A_m = build_maintenance_arcs(K, T, p)


C_k = rand(400:800, length(K))
C_k = DenseAxisArray(C_k, K)

M_costs = build_costs(K, T, I, C_k, A_t)

# initialize resource consumption and capacity arrays
q = DenseAxisArray(zeros(Float64, length(K), length(R)), K, R)
Q = DenseAxisArray(zeros(Float64, T, length(R)), periods, R)

# r1 could be the number of maintenance bays available, while r2 could represent labor hours available.
for (i, k) in enumerate(K)
    q[k, "r1"] = 1.0  # Each task requires 1 bay
    q[k, "r2"] = p[k] * 1.5 
end

for t in periods
    Q[t, "r1"] = 3.0 # 3 bays
    Q[t, "r2"] = 15.0 
end



#=
q = [rand() < 0.5 ? rand(1.0:0.5:4.0) : 0.0 for k in 1:length(K), r in 1:length(R)]
q = DenseAxisArray(q, K, R)


Q = DenseAxisArray(zeros(T, length(R)), periods, R)
for r in R
    capacity = rand(8.0:1.0:15.0)
    for t in periods
        Q[t, r] = capacity
    end
end
=#
