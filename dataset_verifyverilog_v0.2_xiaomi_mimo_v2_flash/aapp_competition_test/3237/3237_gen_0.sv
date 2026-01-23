module min_cost_calculator(
    input clk,
    input rst_n,
    input start,
    input [5:0] num_factors,
    input [7:0] prime_factors [0:7],
    output reg [63:0] min_cost,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam ACCUMULATE_K = 3'b001;
    localparam GENERATE_SUBSETS = 3'b010;
    localparam CALCULATE_D = 3'b011;
    localparam CALCULATE_N = 3'b100;
    localparam CALCULATE_COST = 3'b101;
    localparam UPDATE_MIN = 3'b110;
    localparam DONE = 3'b111;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [63:0] K;
    reg [63:0] D;
    reg [63:0] N;
    reg [63:0] current_cost;
    reg [63:0] min_cost_reg;
    
    // Counter for subsets (0 to 2^num_factors - 1)
    reg [7:0] subset_counter;
    reg [7:0] max_subset;
    
    // Counter for iterating through factors
    reg [3:0] factor_idx;
    reg [3:0] num_factors_reg;
    
    // Temporary registers for product accumulation
    reg [63:0] temp_product;
    reg [63:0] temp_K_acc;
    
    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_cost <= 64'd0;
            done <= 1'b0;
            K <= 64'd0;
            D <= 64'd0;
            N <= 64'd0;
            current_cost <= 64'd0;
            min_cost_reg <= 64'hFFFF_FFFF_FFFF_FFFF;
            subset_counter <= 8'd0;
            max_subset <= 8'd0;
            factor_idx <= 4'd0;
            num_factors_reg <= 4'd0;
            temp_product <= 64'd1;
            temp_K_acc <= 64'd1;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    min_cost_reg <= 64'hFFFF_FFFF_FFFF_FFFF;
                    if (start) begin
                        num_factors_reg <= num_factors[3:0]; // Max 8 fits in 4 bits
                        max_subset <= (num_factors > 0) ? (8'd1 << num_factors[2:0]) - 8'd1 : 8'd0;
                        subset_counter <= 8'd0;
                        temp_K_acc <= 64'd1;
                        factor_idx <= 4'd0;
                    end
                end
                
                ACCUMULATE_K: begin
                    if (factor_idx < num_factors_reg) begin
                        temp_K_acc <= temp_K_acc * prime_factors[factor_idx];
                        factor_idx <= factor_idx + 1'b1;
                    end
                end
                
                GENERATE_SUBSETS: begin
                    subset_counter <= subset_counter + 1'b1;
                    factor_idx <= 4'd0;
                    temp_product <= 64'd1;
                end
                
                CALCULATE_D: begin
                    // If factor_idx < num_factors_reg, check if bit is set in subset_counter
                    if (factor_idx < num_factors_reg) begin
                        if (subset_counter[factor_idx]) begin
                            temp_product <= temp_product * prime_factors[factor_idx];
                        end
                        factor_idx <= factor_idx + 1'b1;
                    end else begin
                        D <= temp_product;
                    end
                end
                
                CALCULATE_N: begin
                    K <= temp_K_acc;
                    min_cost <= min_cost_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = ACCUMULATE_K;
            
            ACCUMULATE_K: begin
                if (factor_idx >= num_factors_reg && num_factors_reg > 0) next_state = GENERATE_SUBSETS;
                else if (num_factors_reg == 0) next_state = DONE; // Handle K=1 case if no factors
                else next_state = ACCUMULATE_K;
            end
            
            GENERATE_SUBSETS: begin
                // Check if we processed all subsets? 
                // Actually, we process current subset in CALCULATE_D. 
                // Wait, subset_counter increments at end of CALCULATE_N or UPDATE_MIN logic.
                // Let's manage the loop control carefully.
                // If subset_counter > max_subset, we are done.
                // But here we just entered GENERATE_SUBSETS.
                if (subset_counter > max_subset) next_state = DONE;
                else next_state = CALCULATE_D;
            end
            
            CALCULATE_D: begin
                if (factor_idx >= num_factors_reg) next_state = CALCULATE_N;
                else next_state = CALCULATE_D;
            end
            
            CALCULATE_N: begin
                next_state = CALCULATE_N;
            end
            
            CALCULATE_COST: begin
                next_state = UPDATE_MIN;
            end
            
            UPDATE_MIN: begin
                // Check loop condition here or in GENERATE_SUBSETS
                next_state = GENERATE_SUBSETS;
            end
            
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Refinement of logic to match the states strictly without adding too many states.
    // The prompt specifies: IDLE, ACCUMULATE_K, GENERATE_SUBSETS, CALCULATE_D, CALCULATE_N, CALCULATE_COST, UPDATE_MIN, DONE.
    // We must use these. 
    // CALCULATE_N: We must stay here until N is computed.
    // We need a way to track if we are starting N calc or continuing.
    // Let's add calc_n_started register.
    
    reg calc_n_started;
    
    // Update block for N calc logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calc_n_started <= 1'b0;
            N <= 64'd0;
        end else begin
            case (state)
                CALCULATE_D: begin
                    calc_n_started <= 1'b0;
                end
                
                CALCULATE_N: begin
                    if (!calc_n_started) begin
                        // First cycle in CALCULATE_N
                        N <= 64'd1;
                        factor_idx <= 4'd0;
                        calc_n_started <= 1'b1;
                    end else begin
                        // Iterating
                        if (factor_idx < num_factors_reg) begin
                            // Check if bit is NOT set (N gets factors not in D)
                            if (!subset_counter[factor_idx]) begin
                                N <= N * prime_factors[factor_idx];
                            end
                            factor_idx <= factor_idx + 1'b1;
                        end
                    end
                end
                
                UPDATE_MIN: begin
                    calc_n_started <= 1'b0; // Reset for next iteration
                end
            endcase
        end
    end
    
    // Updated Next State Logic for CALCULATE_N and UPDATE_MIN
    always @(*) begin
        // Default assignment is already handled, just reassign specific cases
        case (state)
            CALCULATE_N: begin
                if (calc_n_started && factor_idx >= num_factors_reg) next_state = CALCULATE_COST;
                else next_state = CALCULATE_N;
            end
            CALCULATE_COST: begin
                next_state = UPDATE_MIN;
            end
            UPDATE_MIN: begin
                // Check if we have processed all subsets
                // Note: subset_counter increments at the END of UPDATE_MIN or at the start of next loop?
                // We incremented subset_counter in GENERATE_SUBSETS.
                // Wait, in my previous sequential block, I incremented subset_counter in GENERATE_SUBSETS.
                // But GENERATE_SUBSETS is a state we enter. 
                // Cycle: UPDATE_MIN -> GENERATE_SUBSETS (increments subset) -> CALCULATE_D...
                // So when we are in UPDATE_MIN, we have finished a cost calculation for subset_counter.
                // We need to check if subset_counter >= max_subset.
                // If yes, DONE. Else, continue.
                if (subset_counter > max_subset) next_state = DONE;
                else next_state = GENERATE_SUBSETS;
            end
            default: ; // Keep default
        endcase
    end

    // Combinational Logic for Cost Calculation
    always @(*) begin
        if (state == CALCULATE_COST) begin
            current_cost = D + N;
        end else begin
            current_cost = 64'd0; // Or don't care
        end
    end

    // Update Min Cost in UPDATE_MIN state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled in main block
        end else begin
            if (state == UPDATE_MIN) begin
                if (current_cost < min_cost_reg) begin
                    min_cost_reg <= current_cost;
                end
            end
        end
    end

endmodule
