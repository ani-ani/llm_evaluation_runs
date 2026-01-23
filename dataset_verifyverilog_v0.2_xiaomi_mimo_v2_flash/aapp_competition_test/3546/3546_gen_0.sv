module theorem_proof_minimizer(
    input clk,
    input rst_n,
    input start,
    input [4:0] num_theorems,
    input [5:0] proof_count [0:19],
    input [31:0] proof_length [0:199],
    input [4:0] proof_dep_count [0:199],
    input [4:0] proof_deps [0:199][0:19],
    output reg [31:0] min_length,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam LOAD_DATA = 3'b001; // Not strictly needed as inputs are parallel, but for FSM structure
    localparam COMPUTE_COSTS = 3'b010;
    localparam CHECK_DONE = 3'b011;
    localparam OUTPUT_RESULT = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal arrays
    reg [5:0] int_proof_count [0:19];
    reg [31:0] int_proof_length [0:199];
    reg [4:0] int_proof_dep_count [0:199];
    reg [4:0] int_proof_deps [0:199][0:19];
    reg [31:0] cost [0:19];
    reg [31:0] next_cost [0:19];

    // Loop variables
    integer i, j, k, m;

    // Control registers
    reg [4:0] current_theorem;
    reg [5:0] current_proof_idx_start; // Base index for current theorem
    reg [5:0] current_proof_idx; // Offset within theorem
    reg [31:0] current_proof_cost;
    reg [31:0] dep_cost_sum;
    reg [4:0] dep_theorem;
    reg [31:0] temp_cost;
    reg cycle_detected;
    reg needs_update;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_DATA;
            end
            LOAD_DATA: begin
                next_state = COMPUTE_COSTS;
            end
            COMPUTE_COSTS: begin
                // Wait for computation logic to finish iterating all theorems
                if (current_theorem >= num_theorems && !needs_update) 
                    next_state = OUTPUT_RESULT;
                else if (current_theorem >= num_theorems && needs_update)
                    next_state = CHECK_DONE;
                else
                    next_state = COMPUTE_COSTS;
            end
            CHECK_DONE: begin
                if (!needs_update) next_state = OUTPUT_RESULT;
                else next_state = COMPUTE_COSTS;
            end
            OUTPUT_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                if (start) next_state = IDLE; // Reset on new start
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_length <= 0;
            done <= 0;
            current_theorem <= 0;
            needs_update <= 0;
            // Reset costs
            for (i = 0; i < 20; i = i + 1) begin
                cost[i] <= 32'hFFFFFFFF;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    current_theorem <= 0;
                    needs_update <= 0;
                end
                
                LOAD_DATA: begin
                    // Copy inputs to internal storage
                    for (i = 0; i < 20; i = i + 1) begin
                        int_proof_count[i] <= proof_count[i];
                    end
                    for (i = 0; i < 200; i = i + 1) begin
                        int_proof_length[i] <= proof_length[i];
                        int_proof_dep_count[i] <= proof_dep_count[i];
                        for (j = 0; j < 20; j = j + 1) begin
                            int_proof_deps[i][j] <= proof_deps[i][j];
                        end
                    end
                    // Initialize costs to Infinity
                    for (i = 0; i < 20; i = i + 1) begin
                        cost[i] <= 32'hFFFFFFFF;
                    end
                    current_theorem <= 0;
                    needs_update <= 0;
                end

                COMPUTE_COSTS: begin
                    // Iterator Logic
                    // We iterate through theorems 0 to num_theorems-1
                    // For each theorem, we iterate its proofs to find min cost
                    // If a cycle is detected or dependencies aren't resolved (cost is INF), we might need another pass
                    
                    // Simple sequential implementation for area efficiency
                    // We run one full pass of theorems per invocation of COMPUTE_COSTS state
                    // or stick to the state loop. 
                    
                    // Let's use a loop variable that increments on each clock during this state
                    // But we need to handle proof iteration too.
                    
                    // Optimization: All logic here is combinational driven by `current_theorem` and `current_proof_idx`
                    // But since it's a sequential block, we need to manage the iteration carefully.
                    
                    // Let's refine: Use `current_theorem` to index the outer loop.
                    // Calculate cost for `current_theorem` in one clock cycle (assuming max 10 proofs, max 20 deps, this is feasible).
                    
                    if (current_theorem < num_theorems) begin
                        // Compute min cost for current_theorem
                        reg [31:0] local_min;
                        reg [31:0] p_len;
                        reg [31:0] sum_deps;
                        reg [4:0] d_idx;
                        reg [5:0] p_idx_offset;
                        reg [4:0] dep_t;
                        reg valid_proof;
                        
                        local_min = 32'hFFFFFFFF;
                        
                        // Iterate proofs for this theorem
                        // Accumulate global index: Sum of proof_counts of previous theorems + offset
                        // Since inputs are parallel, we don't need to accumulate in runtime, we just need the start offset.
                        // But to avoid complex logic, we iterate `k` from 0 to proof_count[current_theorem]-1
                        
                        p_idx_offset = 0;
                        for (m = 0; m < current_theorem; m = m + 1) begin
                            p_idx_offset = p_idx_offset + int_proof_count[m];
                        end

                        for (k = 0; k < 10; k = k + 1) begin // Max 10 proofs
                            if (k < int_proof_count[current_theorem]) begin
                                // Calculate cost for proof k
                                p_len = int_proof_length[p_idx_offset + k];
                                sum_deps = 0;
                                valid_proof = 1;
                                
                                for (d_idx = 0; d_idx < 20; d_idx = d_idx + 1) begin
                                    if (d_idx < int_proof_dep_count[p_idx_offset + k]) begin
                                        dep_t = int_proof_deps[p_idx_offset + k][d_idx];
                                        
                                        // Cycle check
                                        if (dep_t == current_theorem) begin
                                            valid_proof = 0; // Self reference cycle
                                        end else if (dep_t < num_theorems) begin
                                            // Check dependency cost
                                            if (cost[dep_t] == 32'hFFFFFFFF) begin
                                                valid_proof = 0; // Dependency not yet resolved
                                            end else begin
                                                sum_deps = sum_deps + cost[dep_t];
                                            end
                                        end
                                        // If dep_t >= num_theorems, it's technically invalid input, ignore or treat as 0? Assume valid inputs (0 to num_theorems-1) based on problem context
                                    end
                                end
                                
                                if (valid_proof) begin
                                    if (p_len + sum_deps < local_min) begin
                                        local_min = p_len + sum_deps;
                                    end
                                end
                            end
                        end
                        
                        // Update cost array if we found a better cost
                        if (local_min < cost[current_theorem]) begin
                            cost[current_theorem] <= local_min;
                            needs_update <= 1; // Signal that we made changes, need another pass
                        end
                        
                        current_theorem <= current_theorem + 1;
                    end else begin
                        // Finished pass
                        current_theorem <= 0;
                    end
                end
                
                CHECK_DONE: begin
                    // Check if any cost changed in the last pass
                    // Since we set needs_update in COMPUTE_COSTS, we use that.
                    // If needs_update is 1, we must re-run COMPUTE_COSTS.
                    if (needs_update) begin
                        needs_update <= 0; // Reset for next pass
                    end
                end

                OUTPUT_RESULT: begin
                    min_length <= cost[0];
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
