# NEW RELAX AND FIX

#### RELAX AND FIX  

using JuMP, Gurobi

function relax_and_fix(model, time_blocks, binary_blocks)
    
    m = copy(model)
    set_optimizer(m, Gurobi.Optimizer)
    set_attribute(m, "OutputFlag", 1)
    set_attribute(m, "TimeLimit", 150.0)
    #set_attribute(m, "TimeLimit", 180.0)
    


    solution = Dict{String, Float64}()
    
    # To keep track of fixed varibles
    fixed_vars = Set{VariableRef}()

    all_vars = all_variables(m)

    all_binaries = [v for v in all_vars if is_binary(v)]

    #binaries_current=binary_var_block_ls(m, time_blocks) # LSP version
    binaries_current=binary_var_block_tm(m, time_blocks) # TM version
    
    for (i, block) in enumerate(time_blocks)
        
        println("--- Risolvo blocco $(i)/$(length(time_blocks)): $block ---")
                
        # Relaxing the binary variables not fixed and not in the current block
        for v in all_binaries
            if v in fixed_vars
                continue
            end

            if v in binaries_current[i]
                if has_lower_bound(v)
                    delete_lower_bound(v)
                end
                if has_upper_bound(v)
                    delete_upper_bound(v)
                end
                set_binary(v)
            else
                if is_binary(v)
                    unset_binary(v)
                    set_lower_bound(v, 0.0)
                    set_upper_bound(v, 1.0)
                end
            end
        end
    


        # Solve the subproblem
        optimize!(m)

        status = termination_status(m)
        if status != MOI.OPTIMAL && status != MOI.TIME_LIMIT
            println("Infeasible al blocco $i. Termino l'euristico.")
            return nothing
        elseif !has_values(m)
            println("Nessuna soluzione trovata nel blocco $i entro il tempo limite.")
            return nothing
        end
        
        # save the values before fixing
        vals = Dict{VariableRef, Float64}()

        for v in binaries_current[i]
            vals[v] = value(v)
        end

        for (v, val) in vals
            solution[string(v)] = val
            fix(v, val)        
            push!(fixed_vars, v)
        end


    end

    # solve again with all binaries fixed
    optimize!(m)
    

    status = termination_status(m)
    if status != MOI.OPTIMAL
        println("Problema finale infeasible.")
        return nothing
    end

    if !has_values(m)
        println("Problema finale senza soluzione ammissibile (Stato: $status).")
        return nothing
    end

    
     # Save all the varaibles 
    for v in all_variables(m)
        solution[string(v)] = value(v)
    end
    
    final_obj = objective_value(m)

    return solution, final_obj

end
