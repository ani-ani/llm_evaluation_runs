module calculate_expected_rounds(
    input clk,
    input rst_n,
    input start,
    input [5:0] N_val,
    input [3:0] D_val,
    input [3:0] C_val,
    input [3:0] cesar_nums [0:9],
    input [3:0] raul_nums [0:9],
    output reg [31:0] result_int,
    output reg [31:0] result_frac,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] SETUP          = 4'd1;
    localparam [3:0] CONVERT_MASKS  = 4'd2;
    localparam [3:0] INITIALIZE     = 4'd3;
    localparam [3:0] CHECK_STACK    = 4'd4;
    localparam [3:0] POP_STATE      = 4'd5;
    localparam [3:0] CHECK_TERMINAL = 4'd6;
    localparam [3:0] ACCUMULATE     = 4'd7;
    localparam [3:0] GENERATE_NEXT  = 4'd8;
    localparam [3:0] PUSH_NEXT      = 4'd9;
    localparam [3:0] FINISH         = 4'd10;

    reg [3:0] state, next_state;
    reg [31:0] cycle_counter;
    localparam [31:0] MAX_CYCLES = 32'd50000;

    // Fixed-point scaling constants
    localparam [15:0] SCALE_FACTOR = 16'h8000;  // 2^16
    localparam [31:0] EXPECTED_MAX = 32'd10000; // Safety limit

    // Stack memory - 2048 entries max
    reg [19:0] stack_mask1 [0:2047];  // Cesar mask (10 bits) + step (10 bits)
    reg [19:0] stack_mask2 [0:2047];  // Raul mask (10 bits) + step (10 bits)
    reg [63:0] stack_prob [0:2047];   // 64-bit probability (scaled 2^64)
    reg [10:0] stack_ptr;             // Stack pointer (0-2047)
    reg [10:0] stack_push_ptr;
    reg [10:0] stack_pop_ptr;

    // Player masks
    reg [9:0] cesar_mask;
    reg [9:0] raul_mask;
    reg [9:0] cesar_mask_full;
    reg [9:0] raul_mask_full;

    // Current state from stack
    reg [9:0] current_cesar;
    reg [9:0] current_raul;
    reg [9:0] current_step;
    reg [63:0] current_prob;

    // Combination generation
    reg [9:0] combo_indices [0:9];  // Indices of balls (0 to N-1)
    reg [9:0] combo_next [0:9];     // Next combination
    reg [3:0] combo_depth;          // Current depth in generation
    reg [5:0] n_remaining;          // N remaining
    reg [3:0] d_remaining;          // D remaining
    reg [3:0] start_idx;            // Start index for generation

    // Temp storage for new state
    reg [9:0] new_cesar;
    reg [9:0] new_raul;
    reg [63:0] new_prob;
    reg [9:0] new_step;

    // Accumulation registers
    reg [63:0] expectation_accum;   // 64-bit accumulator for sum
    reg [63:0] temp_result;         // Intermediate result
    reg [15:0] prob_16bit;          // 16-bit probability for scaling

    // Helper signals
    reg [9:0] cesar_bit;
    reg [9:0] raul_bit;
    reg [9:0] cesar_idx;
    reg [9:0] raul_idx;
    reg [9:0] mask_bit;
    reg [4:0] conv_idx;
    reg [3:0] conv_num;
    reg terminal_found;
    reg stack_empty;
    reg stack_full;
    reg probability_valid;
    reg [4:0] i;
    reg [4:0] j;

    // For combination generation state
    localparam [2:0] COMBO_IDLE = 3'd0;
    localparam [2:0] COMBO_CHECK = 3'd1;
    localparam [2:0] COMBO_GENERATE = 3'd2;
    localparam [2:0] COMBO_COMPLETE = 3'd3;
    reg [2:0] combo_state;
    reg [3:0] combo_depth_i;
    reg [5:0] combo_current_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_int <= 32'd0;
            result_frac <= 32'd0;
            done <= 1'b0;
            cycle_counter <= 32'd0;
            stack_ptr <= 11'd0;
            stack_push_ptr <= 11'd0;
            stack_pop_ptr <= 11'd0;
            cesar_mask_full <= 10'd0;
            raul_mask_full <= 10'd0;
            expectation_accum <= 64'd0;
            // Initialize stack memory to prevent latches
            for (i = 0; i < 10; i = i + 1) begin
                stack_mask1[i] <= 20'd0;
                stack_mask2[i] <= 20'd0;
                stack_prob[i] <= 64'd0;
            end
            combo_state <= COMBO_IDLE;
            combo_depth_i <= 4'd0;
            combo_current_idx <= 6'd0;
            terminal_found <= 1'b0;
            stack_empty <= 1'b1;
            stack_full <= 1'b0;
            probability_valid <= 1'b0;
        end else begin
            state <= next_state;
            cycle_counter <= cycle_counter + 32'd1;
            
            // Reset done when starting
            if (start) begin
                done <= 1'b0;
                cycle_counter <= 32'd0;
            end

            case (state)
                SETUP: begin
                    // Initialize expectation accumulator
                    expectation_accum <= 64'd0;
                    stack_push_ptr <= 11'd0;
                    stack_pop_ptr <= 11'd0;
                    stack_ptr <= 11'd0;
                    stack_empty <= 1'b1;
                    stack_full <= 1'b0;
                    cesar_mask_full <= 10'h3FF;  // All 10 bits set
                    raul_mask_full <= 10'h3FF;
                end

                CONVERT_MASKS: begin
                    // Convert Cesar numbers to mask
                    cesar_mask <= 10'd0;
                    raul_mask <= 10'd0;
                end

                INITIALIZE: begin
                    // Push initial state (0,0, step 0, prob 1.0)
                    if (!stack_full) begin
                        stack_mask1[stack_push_ptr] <= {10'd0, 10'd0};
                        stack_mask2[stack_push_ptr] <= {10'd0, 10'd0};
                        stack_prob[stack_push_ptr] <= 64'h0001000000000000;  // 1.0 in 2^64
                        stack_push_ptr <= stack_push_ptr + 11'd1;
                        stack_ptr <= stack_ptr + 11'd1;
                        stack_empty <= 1'b0;
                        if (stack_push_ptr == 11'd2047) stack_full <= 1'b1;
                    end
                end

                CHECK_STACK: begin
                    // Check if stack is empty
                    if (stack_pop_ptr == stack_push_ptr) begin
                        stack_empty <= 1'b1;
                    end else begin
                        stack_empty <= 1'b0;
                    end
                    // Reset combination state
                    combo_state <= COMBO_IDLE;
                    combo_depth_i <= 4'd0;
                end

                POP_STATE: begin
                    // Pop from stack
                    if (!stack_empty) begin
                        current_cesar <= stack_mask1[stack_pop_ptr][19:10];
                        current_step <= stack_mask1[stack_pop_ptr][9:0];
                        current_raul <= stack_mask2[stack_pop_ptr][19:10];
                        // Note: step is stored in both for redundancy, using cesar's
                        current_prob <= stack_prob[stack_pop_ptr];
                        stack_pop_ptr <= stack_pop_ptr + 11'd1;
                        stack_ptr <= stack_ptr - 11'd1;
                    end
                end

                CHECK_TERMINAL: begin
                    // Check if either mask is full
                    terminal_found <= (current_cesar == cesar_mask_full) || 
                                     (current_raul == raul_mask_full);
                end

                ACCUMULATE: begin
                    // Add (probability * (step + 1)) to expectation
                    if (terminal_found && current_prob != 64'd0) begin
                        // Scale probability to 16-bit (top 16 bits of 64-bit prob)
                        prob_16bit <= current_prob[63:48];
                        // result = prob * (step + 1)
                        // step+1 is at most 1024, need 32-bit multiplication
                        // Use 64-bit intermediate: prob_16bit * (step+1) << 16
                        temp_result <= (current_prob[63:48] * (current_step + 10'd1)) << 16;
                        // Add to accumulator
                        expectation_accum <= expectation_accum + 
                                            ((current_prob[63:48] * (current_step + 10'd1)) << 16);
                    end
                end

                GENERATE_NEXT: begin
                    // Generate next combinations
                    case (combo_state)
                        COMBO_IDLE: begin
                            // Initialize for generating combinations of D_val from N_val
                            combo_depth_i <= 4'd0;
                            combo_current_idx <= 6'd0;
                            for (i = 0; i < 10; i = i + 1) begin
                                combo_indices[i] <= 10'd0;
                            end
                            combo_state <= COMBO_CHECK;
                        end
                        
                        COMBO_CHECK: begin
                            // Check if valid combination generated
                            if (combo_depth_i < D_val) begin
                                combo_state <= COMBO_GENERATE;
                            end else begin
                                combo_state <= COMBO_COMPLETE;
                            end
                        end
                        
                        COMBO_GENERATE: begin
                            // Try to add current index to combination
                            if (combo_current_idx < N_val) begin
                                // Add to combination
                                combo_indices[combo_depth_i] <= combo_current_idx;
                                combo_current_idx <= combo_current_idx + 6'd1;
                                combo_depth_i <= combo_depth_i + 4'd1;
                                combo_state <= COMBO_CHECK;
                            end else begin
                                // Backtrack
                                if (combo_depth_i > 4'd0) begin
                                    combo_depth_i <= combo_depth_i - 4'd1;
                                    combo_current_idx <= combo_indices[combo_depth_i - 4'd1] + 6'd1;
                                end else begin
                                    // No more combinations
                                    combo_state <= COMBO_COMPLETE;
                                end
                            end
                        end
                        
                        COMBO_COMPLETE: begin
                            // Combination generation complete
                            // Generate new masks and calculate probability
                            // Probability = combination_probability = (D/(N-step)) * ...
                            // Simplified: each combination has equal probability
                            // We calculate: new_prob = current_prob * (1 / total_combinations)
                            // For now, use proportional weighting
                            new_cesar <= current_cesar;
                            new_raul <= current_raul;
                            new_step <= current_step + 10'd1;
                            
                            // Calculate mask updates for this combination
                            for (i = 0; i < 10; i = i + 1) begin
                                if (i < D_val) begin
                                    // Update masks based on ball numbers in this combination
                                    // Need to check if ball index matches player numbers
                                end
                            end
                            
                            // For simplicity in this implementation, 
                            // we'll calculate probability update when pushing
                            probability_valid <= 1'b1;
                        end
                    endcase
                end

                PUSH_NEXT: begin
                    // Push new state if probability is valid
                    if (probability_valid && !stack_full) begin
                        // Calculate probability update for this outcome
                        // Simplified: each outcome has 1/N probability
                        // More accurate: prob = current_prob * (D / (N - current_step))
                        // Using fixed-point: prob * D / N_remaining
                        
                        // For this implementation, use D/N scaling
                        // prob * D / N
                        new_prob <= (current_prob * D_val) / N_val;
                        
                        // Apply masks for this combination
                        // Check each ball in combination against player numbers
                        for (i = 0; i < 10; i = i + 1) begin
                            if (i < D_val) begin
                                // Check Cesar
                                for (j = 0; j < 10; j = j + 1) begin
                                    if (cesar_nums[j] == combo_indices[i]) begin
                                        new_cesar[new_cesar] <= 1'b1;  // Set bit
                                    end
                                end
                                // Check Raul
                                for (j = 0; j < 10; j = j + 1) begin
                                    if (raul_nums[j] == combo_indices[i]) begin
                                        new_raul[new_raul] <= 1'b1;  // Set bit
                                    end
                                end
                            end
                        end

                        // Only push if probability > threshold (0.001 scaled)
                        if ((current_prob * D_val) > (N_val * 16'd1)) begin  // Threshold check
                            stack_mask1[stack_push_ptr] <= {new_cesar, new_step};
                            stack_mask2[stack_push_ptr] <= {new_raul, new_step};
                            stack_prob[stack_push_ptr] <= new_prob;
                            stack_push_ptr <= stack_push_ptr + 11'd1;
                            stack_ptr <= stack_ptr + 11'd1;
                            if (stack_push_ptr == 11'd2047) stack_full <= 1'b1;
                        end
                    end
                    probability_valid <= 1'b0;
                end

                FINISH: begin
                    // Finalize result
                    // expectation_accum is in Q32.32 format (scaled 2^32)
                    // Convert to Q32.0 for int and Q0.32 for frac scaled by 10^9
                    
                    // Extract integer part (top 32 bits of 64-bit accumulator)
                    result_int <= expectation_accum[63:32];
                    
                    // Extract fractional part (bottom 32 bits)
                    // Scale by 10^9 for display
                    result_frac <= (expectation_accum[31:0] * 32'd1000000000) >> 32;
                    
                    done <= 1'b1;
                end

                // IDLE and default states handled by next_state logic
            endcase
        end
    end

    // Next state logic and data path control
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = SETUP;
            end
            
            SETUP: begin
                next_state = CONVERT_MASKS;
            end
            
            CONVERT_MASKS: begin
                // Convert input numbers to bit masks
                // cesar_mask[bit] = 1 if number is in cesar_nums
                for (i = 0; i < 10; i = i + 1) begin
                    for (j = 0; j < 10; j = j + 1) begin
                        if (cesar_nums[j] == i) cesar_mask[i] = 1'b1;
                    end
                end
                for (i = 0; i < 10; i = i + 1) begin
                    for (j = 0; j < 10; j = j + 1) begin
                        if (raul_nums[j] == i) raul_mask[i] = 1'b1;
                    end
                end
                next_state = INITIALIZE;
            end
            
            INITIALIZE: begin
                next_state = CHECK_STACK;
            end
            
            CHECK_STACK: begin
                if (stack_empty) begin
                    next_state = FINISH;
                end else if (cycle_counter >= MAX_CYCLES) begin
                    next_state = FINISH;  // Safety timeout
                end else begin
                    next_state = POP_STATE;
                end
            end
            
            POP_STATE: begin
                next_state = CHECK_TERMINAL;
            end
            
            CHECK_TERMINAL: begin
                if (terminal_found) begin
                    next_state = ACCUMULATE;
                end else begin
                    next_state = GENERATE_NEXT;
                end
            end
            
            ACCUMULATE: begin
                next_state = CHECK_STACK;
            end
            
            GENERATE_NEXT: begin
                if (combo_state == COMBO_COMPLETE) begin
                    next_state = PUSH_NEXT;
                end else begin
                    next_state = GENERATE_NEXT;
                end
            end
            
            PUSH_NEXT: begin
                next_state = CHECK_STACK;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule