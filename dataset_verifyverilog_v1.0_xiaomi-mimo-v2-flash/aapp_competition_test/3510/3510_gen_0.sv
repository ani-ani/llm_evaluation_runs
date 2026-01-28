module GameSolver (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] option_count_in,
    input [15:0] option_string_in,
    input [3:0] target_in,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] LOAD_INIT     = 4'd1;
    localparam [3:0] LOAD_NODE     = 4'd2;
    localparam [3:0] LOAD_OPTION   = 4'd3;
    localparam [3:0] LOAD_WAIT     = 4'd4;
    localparam [3:0] SETUP_TARGET  = 4'd5;
    localparam [3:0] ITER_START    = 4'd6;
    localparam [3:0] ITER_UPDATE   = 4'd7;
    localparam [3:0] ITER_CHECK    = 4'd8;
    localparam [3:0] ITER_NEXT     = 4'd9;
    localparam [3:0] OUTPUT_START  = 4'd10;
    localparam [3:0] OUTPUT_SEND   = 4'd11;
    localparam [3:0] OUTPUT_NEXT   = 4'd12;
    localparam [3:0] DONE_STATE    = 4'd13;

    // Registers for inputs
    reg [3:0] n_reg;
    reg [3:0] target_reg;
    reg [3:0] node_idx;           // Current node being loaded (0 to n-1)
    reg [3:0] option_idx;         // Current option index for current node
    reg [3:0] opt_count_remaining; // How many options left for current node

    // Internal memory
    reg [15:0] options [0:15][0:15]; // [node][option_idx] -> set of nodes
    reg [7:0] dist [0:15];          // Current distances for current target
    reg [7:0] new_dist [0:15];      // Temporary new distances

    // Computation registers
    reg [3:0] curr_target;          // Target for current computation
    reg [3:0] curr_node;            // Node being processed in iteration
    reg [3:0] curr_option;          // Option being considered
    reg [7:0] max_dist_in_set;      // Max distance in current option set
    reg [7:0] min_option_val;       // Min over options for current node
    reg [7:0] temp_val;             // Temporary for calculation
    reg [7:0] iter_count;           // Iteration counter (max 255)
    reg changed;                    // Flag for convergence check
    reg [3:0] out_start;            // Start node for output
    reg [3:0] out_target;           // Target node for output

    // Control registers
    reg [3:0] state, next_state;
    reg [7:0] bit_idx;              // Bit index for option string parsing

    integer i, j, k; // Loop variables

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            n_reg <= 4'd0;
            target_reg <= 4'd0;
            node_idx <= 4'd0;
            option_idx <= 4'd0;
            opt_count_remaining <= 4'd0;
            curr_target <= 4'd0;
            curr_node <= 4'd0;
            curr_option <= 4'd0;
            iter_count <= 8'd0;
            changed <= 1'b0;
            out_start <= 4'd0;
            out_target <= 4'd0;
            bit_idx <= 8'd0;
            max_dist_in_set <= 8'd0;
            min_option_val <= 8'd0;
            temp_val <= 8'd0;
            
            // Reset arrays
            for (i = 0; i < 16; i = i + 1) begin
                dist[i] <= 8'd255;
                new_dist[i] <= 8'd255;
                for (j = 0; j < 16; j = j + 1) begin
                    options[i][j] <= 16'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        target_reg <= target_in;
                        node_idx <= 4'd0;
                        option_idx <= 4'd0;
                        opt_count_remaining <= option_count_in;
                    end
                end

                LOAD_NODE: begin
                    // Wait for first option of new node
                    opt_count_remaining <= option_count_in;
                end

                LOAD_OPTION: begin
                    // Store option string
                    if (opt_count_remaining > 4'd0 && node_idx < n_reg) begin
                        options[node_idx][option_idx] <= option_string_in;
                        option_idx <= option_idx + 4'd1;
                        opt_count_remaining <= opt_count_remaining - 4'd1;
                    end
                end

                LOAD_WAIT: begin
                    // Wait for next option or move to next node
                    if (opt_count_remaining == 4'd0) begin
                        // Move to next node
                        if (node_idx < n_reg - 4'd1) begin
                            node_idx <= node_idx + 4'd1;
                            option_idx <= 4'd0;
                        end
                    end
                end

                SETUP_TARGET: begin
                    // Initialize distances for current target
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n_reg) begin
                            if (i == curr_target)
                                dist[i] <= 8'd0;
                            else
                                dist[i] <= 8'd255;
                        end else begin
                            dist[i] <= 8'd255;
                        end
                    end
                    iter_count <= 8'd0;
                end

                ITER_START: begin
                    curr_node <= 4'd0;
                    // Initialize new_dist with current dist
                    for (i = 0; i < 16; i = i + 1) begin
                        new_dist[i] <= dist[i];
                    end
                    changed <= 1'b0;
                end

                ITER_UPDATE: begin
                    // Process option curr_option for curr_node
                    // Calculate max distance in set
                    if (curr_option < 4'd16 && curr_node < n_reg) begin
                        // Check if option is valid (non-zero or index within count)
                        // We assume options array is pre-loaded
                        max_dist_in_set <= 8'd0;
                    end
                end

                ITER_CHECK: begin
                    // Finalize max_dist calculation and update min_option_val
                    if (curr_option < 4'd16 && curr_node < n_reg) begin
                        temp_val <= (max_dist_in_set >= 8'd255) ? 8'd255 : (max_dist_in_set + 8'd1);
                    end
                end

                ITER_NEXT: begin
                    // Update min_option_val and advance to next option
                    if (curr_option < 4'd16 && curr_node < n_reg) begin
                        if (curr_option == 4'd0)
                            min_option_val <= temp_val;
                        else if (temp_val < min_option_val && temp_val != 8'd0)
                            min_option_val <= temp_val;
                        
                        curr_option <= curr_option + 4'd1;
                    end
                    // Else if finished options, update node dist
                    else begin
                        if (curr_node < n_reg) begin
                            if (min_option_val < new_dist[curr_node]) begin
                                new_dist[curr_node] <= min_option_val;
                                changed <= 1'b1;
                            end
                        end
                        
                        // Advance to next node
                        curr_node <= curr_node + 4'd1;
                        curr_option <= 4'd0;
                        min_option_val <= 8'd255;
                    end
                end

                OUTPUT_START: begin
                    // Prepare to output results for all start nodes with current target
                    out_start <= 4'd0;
                    out_target <= curr_target;
                end

                OUTPUT_SEND: begin
                    // Output distance for (out_start, out_target)
                    // We need to retrieve distance from stored results
                    // Since we compute one target at a time, we need to store final distances
                    // Or re-compute. Given constraints, let's store final distances in dist array
                    // but we need to keep them for all targets. 
                    // Let's use dist array as storage, and we will fill it fully per target.
                    // But result output needs dist from out_start for out_target.
                    // We will compute and store one full target distance table.
                    // We need to output 0..n-1 for start. 
                    // We will store result in a temporary register or fetch from dist
                    // dist is for curr_target. We need to output dist[out_start]
                    result <= {8'd0, dist[out_start]};
                    done <= 1'b1;
                end

                OUTPUT_NEXT: begin
                    done <= 1'b0;
                    if (out_start < n_reg - 4'd1) begin
                        out_start <= out_start + 4'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Combinational next_state logic and detailed operations
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_INIT;
                end
            end

            LOAD_INIT: begin
                // Check if we need to load any options
                if (n_in > 4'd0 && option_count_in > 4'd0) begin
                    next_state = LOAD_NODE;
                end else begin
                    // Skip loading if no options (e.g., graph definition handled differently)
                    next_state = SETUP_TARGET;
                end
            end

            LOAD_NODE: begin
                if (opt_count_remaining > 4'd0) next_state = LOAD_OPTION;
                else next_state = LOAD_WAIT;
            end

            LOAD_OPTION: begin
                next_state = LOAD_WAIT;
            end

            LOAD_WAIT: begin
                // Check if more options for this node
                if (opt_count_remaining > 4'd0) next_state = LOAD_OPTION;
                // Check if more nodes
                else if (node_idx < n_reg - 4'd1) next_state = LOAD_NODE;
                // Finished loading
                else next_state = SETUP_TARGET;
            end

            SETUP_TARGET: begin
                next_state = ITER_START;
            end

            ITER_START: begin
                // Start processing nodes for one iteration
                if (curr_node < n_reg) next_state = ITER_UPDATE;
                else next_state = ITER_CHECK_END;
            end
            // Special state to handle end of node loop inside iteration
            // Actually, we can handle logic inside ITER_NEXT with multiple jumps
            // But let's separate the flow.
            // To avoid complex combinational loops, let's inline the logic carefully.

            ITER_UPDATE: begin
                // Calculate max_dist_in_set for current option
                // We need a loop here. Since we can't use loops in combinational next_state easily
                // without intermediate states, we will expand the bit check into states or combinational block.
                // Given constraints, let's use combinational block for bit scanning.
                // The update logic for max_dist_in_set is purely combinational based on curr_option.
                next_state = ITER_CHECK;
            end

            ITER_CHECK: begin
                next_state = ITER_NEXT;
            end

            ITER_NEXT: begin
                // Logic to advance option or node
                // If options remain: Update min, go to next option -> ITER_UPDATE
                // If options done: Update node dist, go to next node -> ITER_START
                // We need to check conditions here
                
                // If we just finished an option (curr_option check inside state implies we need to know status)
                // Actually, curr_option increments in ITER_NEXT. 
                // Logic: 
                // 1. We are at ITER_NEXT having just processed 'curr_option-1'.
                // 2. If curr_option < 16 (implies we just incremented to a valid next option): Go ITER_UPDATE
                // 3. If curr_option >= 16 (implies we finished last option): 
                //    - We updated node dist. Now check if curr_node < n_reg - 1.
                //    - If yes: Go ITER_START (next node)
                //    - If no: Go ITERATION_COMPLETE
                
                // This logic is complex for single always block. 
                // Let's use a helper flag or separate states.
                
                // We will use a different structure: 
                // ITER_UPDATE checks if option is valid. If not (curr_option >= 16), jump to NODE_DONE.
                // ITER_UPDATE calculates max dist. 
                
                // Refined flow for Iteration:
                // ITER_START: 
                //   if curr_node < n: 
                //     curr_option = 0; min_opt = 255; 
                //     next_state = CHECK_OPTION;
                //   else: next_state = CHECK_CONVERGENCE;
                // 
                // CHECK_OPTION: 
                //   if curr_option < 16: 
                //     calculate max_dist_in_set (needs loop or state)
                //     next_state = UPDATE_MIN;
                //   else: 
                //     update dist[curr_node] = min_opt;
                //     if dist changed: changed = 1;
                //     curr_node++;
                //     next_state = ITER_START;
                //
                // UPDATE_MIN:
                //   temp = (max_dist >= 255) ? 255 : max_dist + 1;
                //   min_opt = min(min_opt, temp);
                //   curr_option++;
                //   next_state = CHECK_OPTION;
                
                // Let's implement this refined flow in the actual state machine.
                
                // For now, simply forward.
                next_state = ITER_START;
            end

            OUTPUT_START: begin
                next_state = OUTPUT_SEND;
            end

            OUTPUT_SEND: begin
                next_state = OUTPUT_NEXT;
            end

            OUTPUT_NEXT: begin
                if (out_start < n_reg - 4'd1) next_state = OUTPUT_SEND;
                else next_state = NEXT_TARGET;
            end

            NEXT_TARGET: begin
                if (curr_target < n_reg - 4'd1) next_state = SETUP_TARGET;
                else next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Combinational logic for distance calculation
    // This block calculates max_dist_in_set for the current option of the current node
    // It iterates over bits 0 to 15.
    reg [3:0] b;
    always @(*) begin
        max_dist_in_set = 8'd0;
        if (curr_node < n_reg && curr_option < 4'd16) begin
            for (b = 0; b < 16; b = b + 1) begin
                if (b < n_reg && options[curr_node][curr_option][b]) begin
                    if (dist[b] > max_dist_in_set) begin
                        max_dist_in_set = dist[b];
                    end
                end
            end
        end
    end

    // Corrected State Machine Logic (Sequential)
    // We need to split the ITER_* states to match the refined flow
    // New states for iteration:
    localparam [3:0] CHECK_OPTION = 4'd14;
    localparam [3:0] UPDATE_MIN   = 4'd15;
    localparam [3:0] NODE_DONE    = 4'd16;
    localparam [3:0] CHECK_CONVERGENCE = 4'd17;
    localparam [3:0] NEXT_TARGET = 4'd18;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            case (state)
                // ... other states ...
                CHECK_OPTION: begin
                    // Logic handled in next_state block or here
                end
                UPDATE_MIN: begin
                    // Logic handled in next_state block
                end
            endcase
        end
    end

    // Updated Next State Logic with new states
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD_INIT;
            
            LOAD_INIT: begin
                if (n_in > 4'd0 && option_count_in > 4'd0) next_state = LOAD_NODE;
                else next_state = SETUP_TARGET;
            end
            
            LOAD_NODE: begin
                if (opt_count_remaining > 4'd0) next_state = LOAD_OPTION;
                else next_state = LOAD_WAIT;
            end
            
            LOAD_OPTION: next_state = LOAD_WAIT;
            
            LOAD_WAIT: begin
                if (opt_count_remaining > 4'd0) next_state = LOAD_OPTION;
                else if (node_idx < n_reg - 4'd1) next_state = LOAD_NODE;
                else next_state = SETUP_TARGET;
            end
            
            SETUP_TARGET: next_state = ITER_START;
            
            ITER_START: begin
                if (curr_node < n_reg) begin
                    next_state = CHECK_OPTION;
                end else begin
                    next_state = CHECK_CONVERGENCE;
                end
            end
            
            CHECK_OPTION: begin
                if (curr_option < 4'd16) begin
                    next_state = UPDATE_MIN;
                end else begin
                    next_state = NODE_DONE;
                end
            end
            
            UPDATE_MIN: begin
                next_state = CHECK_OPTION;
            end
            
            NODE_DONE: begin
                if (curr_node < n_reg - 4'd1) next_state = ITER_START;
                else next_state = CHECK_CONVERGENCE;
            end
            
            CHECK_CONVERGENCE: begin
                if (changed && iter_count < 8'd255) begin
                    next_state = ITER_START;
                end else begin
                    next_state = OUTPUT_START;
                end
            end
            
            OUTPUT_START: next_state = OUTPUT_SEND;
            OUTPUT_SEND: next_state = OUTPUT_NEXT;
            OUTPUT_NEXT: begin
                if (out_start < n_reg - 4'd1) next_state = OUTPUT_SEND;
                else next_state = NEXT_TARGET;
            end
            NEXT_TARGET: begin
                if (curr_target < n_reg - 4'd1) next_state = SETUP_TARGET;
                else next_state = DONE_STATE;
            end
            DONE_STATE: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic for New States
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            case (state)
                SETUP_TARGET: begin
                    curr_target <= curr_target + 4'd1;
                    // Reset curr_node for iteration start
                    curr_node <= 4'd0;
                    // Reset iteration counter
                    iter_count <= 8'd0;
                end

                ITER_START: begin
                    curr_option <= 4'd0;
                    min_option_val <= 8'd255;
                    // Reset new_dist? No, we update it. 
                    // But we need to check convergence on dist vs new_dist.
                    // Actually, standard fixed point: new_dist = dist. Update new_dist. Compare at end.
                end

                CHECK_OPTION: begin
                    // Check if option exists. 
                    // Since we don't store count per node explicitly in arrays, we assume 16 max.
                    // But we should respect the loaded counts if possible. 
                    // To simplify for Verilog synthesis, we iterate 0..15.
                    // If option is zero (no nodes), it implies max_dist = 0? Or invalid?
                    // If set is empty, Bob has no move. Alice wins instantly? 
                    // Or does Bob force a win if no moves? Let's assume empty set = no move = stuck.
                    // But graph usually has edges. If set is empty, distance is 255 (infinity).
                end

                UPDATE_MIN: begin
                    // Use combinational max_dist_in_set
                    temp_val <= (max_dist_in_set == 8'd255) ? 8'd255 : (max_dist_in_set + 8'd1);
                end

                NODE_DONE: begin
                    // Assign min_option_val to new_dist[curr_node]
                    // Only if we found a valid path (min_option_val < 255)
                    // If min_option_val is 255, it stays 255 (infinite)
                    new_dist[curr_node] <= min_option_val;
                    curr_node <= curr_node + 4'd1;
                end

                CHECK_CONVERGENCE: begin
                    // Compare dist and new_dist
                    changed <= 1'b0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n_reg) begin
                            dist[i] <= new_dist[i]; // Update dist for next iteration
                            if (dist[i] != new_dist[i]) begin
                                changed <= 1'b1;
                            end
                        end
                    end
                    iter_count <= iter_count + 8'd1;
                end

                OUTPUT_NEXT: begin
                    done <= 1'b0;
                end

                NEXT_TARGET: begin
                    // Reset for next target
                end

                DONE_STATE: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
