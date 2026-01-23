module replant_solver(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [4:0] M,
    input [3:0] species_in,
    input load_species,
    output reg [3:0] result,
    output reg done
);

    // Internal buffer for species IDs (Max N = 8)
    reg [3:0] species_buffer [0:7];
    reg [2:0] load_index;
    
    // DP array (Max N = 8, max LNDS length is 8 which fits in 4 bits)
    reg [3:0] dp [0:7];
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COMPUTE_DP = 3'b010;
    localparam FIND_MAX = 3'b011;
    localparam CALCULATE_RESULT = 3'b100;
    localparam DONE_STATE = 3'b101;
    
    reg [2:0] state;
    
    // Loop counters and temporary registers
    reg [2:0] i; // Outer loop index (DP index)
    reg [2:0] j; // Inner loop index (Comparison index)
    reg [3:0] current_max_dp; // Stores max(dp[j]) for current i
    reg [3:0] global_max_len; // Stores max(dp[i]) for result calculation
    
    // Control signals for FSM transitions
    reg processing_done;
    
    // Load species buffer logic
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_index <= 3'd0;
            for (k = 0; k < 8; k = k + 1) begin
                species_buffer[k] <= 4'd0;
            end
        end else if (state == IDLE && load_species) begin
            if (load_index < N) begin
                species_buffer[load_index] <= species_in;
                load_index <= load_index + 1'b1;
            end
        end else if (state != IDLE && state != LOAD) begin
            // Reset load index when computation starts or resets
            // Note: This logic assumes load sequence is contiguous before start
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            i <= 3'd0;
            j <= 3'd0;
            current_max_dp <= 4'd0;
            global_max_len <= 4'd0;
            // Initialize DP array
            for (k = 0; k < 8; k = k + 1) dp[k] <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset indices for computation
                        i <= 3'd0;
                        j <= 3'd0;
                        current_max_dp <= 4'd0;
                        global_max_len <= 4'd0;
                        // Clear DP array (optional but good practice)
                        // We can just overwrite it during compute
                        state <= COMPUTE_DP;
                    end else if (load_species) begin
                        // If load signal comes while idle, go to LOAD state to handle buffer filling
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    if (!load_species) begin
                        // Return to idle if loading stops
                        state <= IDLE;
                    end else if (load_index >= N) begin
                        // Buffer full, wait for signal to drop or stay? 
                        // If user keeps signal high, we ignore (or could stay here)
                        // Let's just wait for signal to drop to go to IDLE or start
                    end
                    // In LOAD state, the always block for buffer handles the capture
                    if (start) begin
                        // Start requested during load, transition to compute
                        state <= COMPUTE_DP;
                        // Reset indices
                        i <= 3'd0;
                        j <= 3'd0;
                        current_max_dp <= 4'd0;
                        global_max_len <= 4'd0;
                    end
                end

                COMPUTE_DP: begin
                    // DP Algorithm: dp[i] = 1 + max(dp[j]) for j < i and species[j] <= species[i]
                    
                    // Outer loop i runs from 0 to N-1
                    // Inner loop j runs from 0 to i-1
                    
                    if (i < N) begin
                        // Inner loop processing
                        if (j < i) begin
                            if (species_buffer[j] <= species_buffer[i]) begin
                                if (dp[j] > current_max_dp) begin
                                    current_max_dp <= dp[j];
                                end
                            end
                            j <= j + 1'b1;
                        end else begin
                            // Inner loop finished for current i
                            // dp[i] = 1 + max_dp (if any valid j found) or 1
                            // current_max_dp is initialized to 0 every outer loop iteration (handled below)
                            // If no j satisfied condition, current_max_dp remains 0, so dp[i] = 1 (correct)
                            // If j satisfied, current_max_dp holds max value, dp[i] = 1 + max_dp (correct)
                            dp[i] <= 1'b1 + current_max_dp;
                            
                            // Update global max_len on the fly to save a state (optional optimization)
                            if (1'b1 + current_max_dp > global_max_len) begin
                                global_max_len <= 1'b1 + current_max_dp;
                            end
                            
                            // Advance outer loop
                            i <= i + 1'b1;
                            j <= 3'd0;
                            current_max_dp <= 4'd0; // Reset for next iteration
                        end
                    end else begin
                        // Finished computing all dp values
                        state <= CALCULATE_RESULT;
                    end
                end
                
                /*
                // Original Spec Find Max State (if not optimized into Compute)
                FIND_MAX: begin
                    // Using global_max_len tracked during compute state instead
                    // to fit within rough cycle count and simplify.
                    // If strictly separated logic was required, it would be here.
                    // Jumping straight to CALCULATE.
                    state <= CALCULATE_RESULT;
                end
                */

                CALCULATE_RESULT: begin
                    // Result = N - max_len
                    // N is 4 bits, max_len is 4 bits
                    // Note: N is unsigned. If N < max_len (shouldn't happen), result wraps.
                    // Assuming valid inputs (max_len <= N).
                    result <= N - global_max_len;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        // Wait for start to go low before accepting new command
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
