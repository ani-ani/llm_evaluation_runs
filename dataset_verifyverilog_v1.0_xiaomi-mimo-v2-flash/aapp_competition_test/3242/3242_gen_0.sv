module polly_finder (
    input clk,
    input rst_n,
    input start,
    input [7:0] e_0, e_1, e_2, e_3, e_4, e_5, e_6, e_7,
    input [7:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input [7:0] P_target,
    output reg [10:0] result,
    output reg done
);

    // State Definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_MEM = 3'd1;
    localparam [2:0] CALC_BOX = 3'd2;
    localparam [2:0] FIND_RESULT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Parameters
    localparam [10:0] MAX_ENERGY = 11'd2048;
    localparam [3:0] NUM_BOXES = 4'd8;

    // Internal Registers and Wires
    reg [2:0] state, next_state;
    reg [10:0] energy_idx;
    reg [10:0] energy_limit;
    reg [3:0] box_idx;
    reg [7:0] current_p;
    reg [10:0] current_e;
    reg [7:0] temp_prob;
    reg [7:0] dp_mem [0:2047]; // 2048 x 8-bit memory
    reg [7:0] inputs_e [0:7];   // Register inputs
    reg [7:0] inputs_p [0:7];   // Register inputs
    reg [7:0] target_reg;

    // Helper variables for loops
    integer i;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 11'd0;
            done <= 1'b0;
            energy_idx <= 11'd0;
            energy_limit <= 11'd0;
            box_idx <= 4'd0;
            current_p <= 8'd0;
            current_e <= 11'd0;
            temp_prob <= 8'd0;
            target_reg <= 8'd0;
            // Initialize memory (optional but safe, handled in INIT_MEM state mostly)
            for (i = 0; i < 2048; i = i + 1) dp_mem[i] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 11'd0;
                    if (start) begin
                        // Register inputs
                        inputs_e[0] <= e_0;
                        inputs_e[1] <= e_1;
                        inputs_e[2] <= e_2;
                        inputs_e[3] <= e_3;
                        inputs_e[4] <= e_4;
                        inputs_e[5] <= e_5;
                        inputs_e[6] <= e_6;
                        inputs_e[7] <= e_7;
                        inputs_p[0] <= p_0;
                        inputs_p[1] <= p_1;
                        inputs_p[2] <= p_2;
                        inputs_p[3] <= p_3;
                        inputs_p[4] <= p_4;
                        inputs_p[5] <= p_5;
                        inputs_p[6] <= p_6;
                        inputs_p[7] <= p_7;
                        target_reg <= P_target;
                    end
                end

                INIT_MEM: begin
                    // Initialize dp_mem[0] = 0, rest = 0 (default from reset)
                    // Ensure we clear for next run if necessary
                    dp_mem[0] <= 8'd0;
                    energy_idx <= 11'd0;
                    box_idx <= 4'd0;
                end

                CALC_BOX: begin
                    // Standard 0/1 Knapsack Loop logic
                    // We iterate backwards for in-place update
                    // DP update: dp[e + e_i] = max(dp[e + e_i], dp[e] + p_i)
                    
                    // Current box properties
                    current_p <= inputs_p[box_idx];
                    current_e <= {3'd0, inputs_e[box_idx]}; // Extend to 11 bits

                    // Check bounds for reverse iteration
                    // We want to update from (MAX_ENERGY - e_i) down to 0
                    // But since we process one box at a time, we iterate full range and check condition
                    
                    if (energy_idx < MAX_ENERGY) begin
                        // Calculate potential new probability
                        // Only update if energy_idx + current_e is valid AND we have a valid value at current index
                        
                        // This logic is tricky in hardware. We need to read dp_mem[energy_idx]
                        // and conditionally write to dp_mem[energy_idx + current_e]
                        
                        // We need to handle the reverse iteration properly.
                        // We can iterate from (MAX_ENERGY - 1) down to 0.
                        
                        // Let's refine the loop:
                        // Iterate e from (MAX_ENERGY - current_e) down to 0
                        // If dp[e] is valid, update dp[e + current_e]
                        
                        // Since we are in a state machine, we simulate the loop.
                        // Valid range for 'e' in this step: [0, MAX_ENERGY - current_e - 1]
                        
                        // We use 'energy_idx' as the counter for the loop.
                        // If we are at energy_idx, we check if we can update (energy_idx + current_e)
                        // However, to avoid dependency issues (reading what we just wrote),
                        // we must iterate DESCENDING (High to Low) for knapsack.
                        
                        // Let's change the loop structure: 
                        // Start at MAX_ENERGY - current_e, go down to 0.
                        
                        // Read value at current index
                        temp_prob <= dp_mem[energy_idx];
                        
                        // If we have a valid probability at current index, try to extend it
                        // Note: In standard knapsack, we check if (dp[e] + p_i) > dp[e + w]
                        
                        // We will write to the memory in the same cycle or next.
                        // To prevent write-before-read hazard in descending loop:
                        // Read is done at current energy_idx.
                        // The write target is (energy_idx + current_e).
                        // Since we iterate Down (e.g., 2047 -> 0), and target is Higher (e+weight),
                        // we are safe (we write to a location we haven't visited yet in this iteration).
                        
                        if (energy_idx + current_e < MAX_ENERGY) begin
                            if (temp_prob + current_p > dp_mem[energy_idx + current_e]) begin
                                dp_mem[energy_idx + current_e] <= temp_prob + current_p;
                            end
                        end

                        energy_idx <= energy_idx + 11'd1;
                    end
                end

                FIND_RESULT: begin
                    // Scan from 0 to find first index where dp_mem[energy_idx] >= target_reg
                    if (energy_idx < MAX_ENERGY) begin
                        if (dp_mem[energy_idx] >= target_reg) begin
                            result <= energy_idx[10:0];
                            // Found, transition to finish (handled in combinational logic below)
                        end else begin
                            energy_idx <= energy_idx + 11'd1;
                        end
                    end else begin
                        // No solution found (result stays 0 or indicates max)
                        result <= 11'd2048; // Indicate max energy or no solution
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INIT_MEM;
                else next_state = IDLE;
            end
            INIT_MEM: begin
                next_state = CALC_BOX;
            end
            CALC_BOX: begin
                // Loop: 8 boxes. Each box loop runs for MAX_ENERGY iterations (2048)
                // We combine these loops into a single counter or nested state logic.
                // Here we use a simple approach: if box_idx < 8, stay in CALC_BOX.
                // If energy_idx reaches MAX_ENERGY, move to next box.
                
                if (energy_idx >= MAX_ENERGY) begin
                    if (box_idx < NUM_BOXES - 1) begin
                        // Next box, reset energy_idx
                        next_state = CALC_BOX; // Stay in CALC_BOX but logic will reset counters
                    end else begin
                        // All boxes done
                        next_state = FIND_RESULT;
                    end
                end else begin
                    next_state = CALC_BOX;
                end
            end
            FIND_RESULT: begin
                // Check if found or reached end
                if (dp_mem[energy_idx] >= target_reg || energy_idx >= MAX_ENERGY) begin
                    next_state = FINISH;
                end else begin
                    next_state = FIND_RESULT;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State-specific counter control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Counters handled in main block
        end else begin
            if (state == INIT_MEM) begin
                energy_idx <= MAX_ENERGY - 11'd1; // Start high for descending update
                box_idx <= 4'd0;
                // Initialize memory to 0 for valid range
                // We assume reset cleared it. If not, we might need to clear here.
                // For safety, let's assume we only care about indices up to used capacity.
            end
            
            if (state == CALC_BOX) begin
                if (energy_idx == 0) begin
                    // Reached end of loop for this box
                    if (box_idx < NUM_BOXES - 1) begin
                        box_idx <= box_idx + 4'd1;
                        energy_idx <= MAX_ENERGY - 11'd1; // Reset for next box
                    end
                end else begin
                    energy_idx <= energy_idx - 11'd1; // Descending loop
                end
            end
            
            if (state == FIND_RESULT) begin
                // Logic is handled in main block (incrementing)
                // Reset counter for scan
                if (next_state == FIND_RESULT && state != FIND_RESULT) begin
                    energy_idx <= 11'd0;
                end
            end
        end
    end

endmodule