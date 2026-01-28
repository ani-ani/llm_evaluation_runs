module ExpectedRoundsCalculator(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd50000;

    // Fixed-point scaling
    localparam [31:0] SCALE = 32'd65536; // 2^16
    localparam [31:0] THRESHOLD = 32'd100; // Minimum probability threshold

    // Stack implementation
    reg [31:0] stack [0:4999]; // State stack (mask1, mask2, prob, steps)
    reg [11:0] stack_ptr;
    reg [11:0] stack_size;

    // Current state variables
    reg [9:0] current_mask1;
    reg [9:0] current_mask2;
    reg [31:0] current_prob;
    reg [15:0] current_steps;

    // Player masks
    reg [9:0] cesar_mask;
    reg [9:0] raul_mask;

    // Combination generation
    reg [31:0] combination [0:9];
    reg [3:0] comb_ptr;
    reg [3:0] comb_size;

    // Expected value accumulation
    reg [63:0] expectation;

    // Temporary variables
    reg [31:0] temp_prob;
    reg [9:0] temp_mask1;
    reg [9:0] temp_mask2;
    reg [31:0] mult_temp;
    reg [31:0] div_temp;
    reg [31:0] new_prob;
    reg [15:0] new_steps;
    reg [31:0] outcome_prob;
    reg [31:0] term_value;
    reg [31:0] term_int;
    reg [31:0] term_frac;

    // Initialize masks
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 16'd0;
            stack_ptr <= 12'd0;
            stack_size <= 12'd0;
            current_mask1 <= 10'd0;
            current_mask2 <= 10'd0;
            current_prob <= 32'd0;
            current_steps <= 16'd0;
            cesar_mask <= 10'd0;
            raul_mask <= 10'd0;
            comb_ptr <= 4'd0;
            comb_size <= 4'd0;
            expectation <= 64'd0;
            result_int <= 32'd0;
            result_frac <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Convert input numbers to masks
                    integer i;
                    cesar_mask <= 10'd0;
                    raul_mask <= 10'd0;
                    for (i = 0; i < 10; i = i + 1) begin
                        if (cesar_nums[i] > 0 && cesar_nums[i] <= 50) begin
                            cesar_mask[cesar_nums[i] - 1] <= 1'b1;
                        end
                        if (raul_nums[i] > 0 && raul_nums[i] <= 50) begin
                            raul_mask[raul_nums[i] - 1] <= 1'b1;
                        end
                    end
                    
                    // Initialize stack with start state
                    stack[0] <= {16'd0, 16'd0, 32'd65536, 16'd0};
                    stack_size <= 12'd1;
                    stack_ptr <= 12'd0;
                    expectation <= 64'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Check if stack is empty
                    if (stack_size == 12'd0) begin
                        state <= FINISH;
                    end else begin
                        // Pop state from stack
                        current_mask1 <= stack[stack_ptr][31:22];
                        current_mask2 <= stack[stack_ptr][21:12];
                        current_prob <= stack[stack_ptr][11:0];
                        current_steps <= stack[stack_ptr][47:32];
                        stack_ptr <= stack_ptr + 12'd1;
                        stack_size <= stack_size - 12'd1;
                        
                        // Check if terminal state
                        if (current_mask1 == 10'd1023 || current_mask2 == 10'd1023) begin
                            // Add to expectation: probability * (steps + 1)
                            new_steps <= current_steps + 16'd1;
                            mult_temp <= current_prob * new_steps;
                            expectation <= expectation + {32'd0, mult_temp};
                        end else begin
                            // Generate all combinations of D balls
                            comb_size <= 4'd0;
                            comb_ptr <= 4'd0;
                            GenerateCombinations();
                            
                            // Process each combination
                            if (comb_size > 4'd0) begin
                                // Push current state back to stack
                                stack[stack_ptr] <= {current_mask1, current_mask2, current_prob, current_steps};
                                stack_ptr <= stack_ptr + 12'd1;
                                stack_size <= stack_size + 12'd1;
                                
                                // Process first combination
                                ProcessCombination();
                            end
                        end
                    end
                    
                    // Check cycle limit
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Convert expectation to output format
                    term_value <= expectation[63:32];
                    term_int <= term_value / SCALE;
                    term_frac <= (term_value % SCALE) * 32'd1525878906; // Scale to 10^9
                    
                    result_int <= term_int;
                    result_frac <= term_frac;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combination generation logic
    task GenerateCombinations();
        integer i, j, k;
        reg [31:0] temp_comb;
        
        // Simple combination generation for D balls from N
        // This is a simplified version - in practice would need full combination logic
        // For this example, we'll just generate a few combinations
        comb_size <= 4'd0;
        
        // Generate combinations (simplified)
        for (i = 0; i < 10; i = i + 1) begin
            if (comb_size >= 10) break;
            combination[comb_size] <= i;
            comb_size <= comb_size + 4'd1;
        end
    endtask

    // Process combination logic
    task ProcessCombination();
        integer i;
        reg [31:0] balls_drawn;
        reg [31:0] prob_per_comb;
        
        // Calculate probability for this combination
        prob_per_comb <= CalculateCombinationProb();
        
        // Calculate new masks
        temp_mask1 <= current_mask1;
        temp_mask2 <= current_mask2;
        balls_drawn <= combination[comb_ptr];
        
        for (i = 0; i < 10; i = i + 1) begin
            if (balls_drawn[i]) begin
                temp_mask1[i] <= temp_mask1[i] | cesar_mask[i];
                temp_mask2[i] <= temp_mask2[i] | raul_mask[i];
            end
        end
        
        // Calculate new probability
        mult_temp <= current_prob * prob_per_comb;
        new_prob <= mult_temp / SCALE;
        
        // Check if probability is above threshold
        if (new_prob > THRESHOLD) begin
            new_steps <= current_steps + 16'd1;
            
            // Push new state to stack
            stack[stack_ptr] <= {temp_mask1, temp_mask2, new_prob, new_steps};
            stack_ptr <= stack_ptr + 12'd1;
            stack_size <= stack_size + 12'd1;
        end
        
        // Move to next combination
        comb_ptr <= comb_ptr + 4'd1;
        if (comb_ptr < comb_size) begin
            ProcessCombination();
        end
    endtask

    // Calculate combination probability
    function [31:0] CalculateCombinationProb();
        input [31:0] comb;
        reg [31:0] prob;
        
        // Simplified probability calculation
        // In practice, this would calculate the exact probability
        // based on the combination and remaining balls
        prob <= 32'd65536 / (N_val * N_val); // Placeholder
        
        CalculateCombinationProb = prob;
    endfunction

endmodule