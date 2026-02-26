# TRAIN MAINTENANCE MODEL
# main script

using JuMP, Gurobi

#include(joinpath(@__DIR__, "trainmaintenance_toy1.jl"))
include(joinpath(@__DIR__, "trainmaintenance_medium1.jl"))


include(joinpath(@__DIR__, "partition_period.jl"))
include(joinpath(@__DIR__, "binary_var_block_tm.jl"))
include(joinpath(@__DIR__, "relax_and_fix.jl"))


TM=Model(Gurobi.Optimizer)
set_optimizer_attribute(TM, "OutputFlag", 1)
#set_optimizer_attribute(TM, "TimeLimit", 300)
set_optimizer_attribute(TM, "TimeLimit", 2700) 
#set_optimizer_attribute(TM, "TimeLimit", 21600) # 6 hours



# Variables
@variable(TM, x[k in K, a in A_t[k]], Bin)
@variable(TM, y[k in K, a in A_m[k]], Bin)
@variable(TM, z[j in periods], Bin)


@objective(TM, Min, sum(M_costs[k][a]* x[k, a] for k in K for a in A_t[k]) + sum(U * z[j] for j in periods))

for k in K
    @constraint(TM, 
        sum(x[k, a] for a in A_t[k] if a[1] == 0) + 
        sum(y[k, a] for a in A_m[k] if a[1] == 0) == 1
    )
end


for k in K
    @constraint(TM, 
        sum(x[k, a] for a in A_t[k] if a[2] == "T") == 1
    )
end


for k in K, j in periods #, j in 1:T
    @constraint(TM, 
        sum(x[k, a] for a in A_t[k] if a[2] == j) == 
        sum(y[k, a] for a in A_m[k] if a[1] == j)
    )
end


for k in K, j in periods if j > 0 # j=0 already in the first constraint
    @constraint(TM, 
        sum(y[k, a] for a in A_m[k] if a[2] == j) == 
        sum(x[k, a] for a in A_t[k] if a[1] == j)
    )
end
end



for k in K, j in periods # j in 1:T
    @constraint(TM, 
        z[j] >= sum(y[k, a] for a in A_m[k] if a[1] <= j < a[2])
    )
end


for k in K, a in A_t[k]
    if a[2] != "T"
        i, j, l = a
        @constraint(TM, (j - i - l) * x[k, a] <= sum(z[p] for p in i:j-1))
    end
end


for j in periods, r in R
    @constraint(TM, 
        sum(y[k, a] * q[k, r] for k in K for a in A_m[k] if a[1] <= j < a[2]) <= Q[j, r]
    )
end




# -------- GUROBI ------------
optimize!(TM)
println("Termination status: $(termination_status(TM))")

gurobi_cost=round(objective_value(TM), digits=2)
best_bound=round(objective_bound(TM), digits=2) 



if termination_status(TM) == MOI.OPTIMAL || termination_status(TM) == MOI.TIME_LIMIT
    println("\n--- OPTIMAL SOLUTION DETAILS ---")
    
    for k in K
        println("\nActivity: $k")
        
        println("  Travel Path:")
        for a in A_t[k]
            if value(x[k, a]) > 0.5
                i, j, l = a
                # Distinguish between internal and sink arcs
                dest = (j == "T") ? "Sink (End)" : "Node $j"
                println("    - From $i to $dest: Operative periods (l) = $l")
            end
        end
    
        println("  Maintenance Schedule:")
        maintenance_found = false
        for a in A_m[k]
            if value(y[k, a]) > 0.5
                maintenance_found = true
                i, j = a
                println("    - Scheduled from period $i to $j (Duration: $(j-i))")
            end
        end
        if !maintenance_found
            println("    - No maintenance performed within the horizon.")
        end
    end
    
    println("\n--- TRAIN DOWNTIME STATUS (z_j) ---")
    for j in periods
        status = value(z[j]) > 0.5 ? "STOPPED (Downtime)" : "RUNNING"
        println("  Period $j: $status")
    end
else
    println("No optimal solution found.")
end





# ----- RELAX AND FIX -----

#blocks=partition_period(periods, 3) # toy instance
blocks=partition_period(periods, 5) # medium instance
println("\nTime blocks: ", blocks)

binary_blocks=binary_var_block_tm(TM, blocks)
#println("\nBinary variables per block:")
#for (i, vars) in enumerate(binary_blocks)
#    println("  Block $i: ", length(vars), " binary variables")
#end



rf_solution, rf_cost=relax_and_fix(TM, blocks, binary_blocks)


# ----- RESULTS -------

println("\n" * "="^40)
println("      RESULTS")
println("="^40)
println("Gurobi objective: ", gurobi_cost)
println("Gurobi best bound: ", best_bound)
println("Relax and fix objective: ", round(rf_cost, digits=2))
println("="^40)


#=
println("\n--- ALL ACTIVE BINARY VARIABLES ---")
for (var_name, val) in rf_solution
    if val > 0.5 && (occursin("x", var_name) || occursin("y", var_name))
        println("$var_name = $val")
    end
end
=#
