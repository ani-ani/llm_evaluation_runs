module MinCostAlternatingSequence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] c_in,
    input wire [15:0] r_in,
    input wire [7:0] s_in,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] LOAD_SCORES  = 3'd1;
    localparam [2:0] DP_INIT      = 3'd2;
    localparam [2:0] DP_PROCESS   = 3'd3;
    localparam [2:0] CALC_RESULT  = 3'd4;
    localparam [2:0] FINISH       = 3'd5;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] load_counter;      // 0-15 for loading scores
    reg [3:0] dp_counter;        // 0-15 for DP processing
    
    // Score memory (Block RAM)
    reg [7:0] s_mem [0:15];      // Store 16 scores
    
    // DP state variables (costs)
    reg [23:0] cost_pos;         // State 0: ends with positive
    reg [23:0] cost_neg;         // State 1: ends with negative
    reg [23:0] cost_empty;       // State 2: empty sequence
    reg [23:0] cost_pos_next;
    reg [23:0] cost_neg_next;
    reg [23:0] cost_empty_next;
    
    // Temporary variables for calculations
    reg [23:0] min_prev_01;
    reg [23:0] min_prev_02;
    reg [23:0] min_prev_12;
    reg [23:0] temp_remove;
    reg [23:0] temp_keep_pos;
    reg [23:0] temp_keep_neg;
    
    // Current score being processed
    reg [7:0] current_score;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Helper: find minimum of two 24-bit values
    function automatic [23:0] min2;
        input [23:0] a, b;
        begin
            min2 = (a < b) ? a : b;
        end
    endfunction
    
    // Helper: find minimum of three 24-bit values
    function automatic [23:0] min3;
        input [23:0] a, b, c;
        reg [23:0] temp;
        begin
            temp = (a < b) ? a : b;
            min3 = (temp < c) ? temp : c;
        end
    endfunction

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            load_counter <= 4'd0;
            dp_counter <= 4'd0;
            cycle_count <= 8'd0;
            cost_pos <= 24'd0;
            cost_neg <= 24'd0;
            cost_empty <= 24'd0;
            current_score <= 8'd0;
            // Initialize memory
            s_mem[0] <= 8'd0;
            s_mem[1] <= 8'd0;
            s_mem[2] <= 8'd0;
            s_mem[3] <= 8'd0;
            s_mem[4] <= 8'd0;
            s_mem[5] <= 8'd0;
            s_mem[6] <= 8'd0;
            s_mem[7] <= 8'd0;
            s_mem[8] <= 8'd0;
            s_mem[9] <= 8'd0;
            s_mem[10] <= 8'd0;
            s_mem[11] <= 8'd0;
            s_mem[12] <= 8'd0;
            s_mem[13] <= 8'd0;
            s_mem[14] <= 8'd0;
            s_mem[15] <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    load_counter <= 4'd0;
                    dp_counter <= 4'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Clear costs for new computation
                        cost_pos <= 24'd0;
                        cost_neg <= 24'd0;
                        cost_empty <= 24'd0;
                    end
                end
                
                LOAD_SCORES: begin
                    if (load_counter < 4'd16) begin
                        s_mem[load_counter] <= s_in;
                        load_counter <= load_counter + 4'd1;
                    end
                end
                
                DP_INIT: begin
                    // Initialize DP with first score
                    current_score <= s_mem[0];
                    dp_counter <= 4'd1;  // Start from index 1
                    // Initial state: empty sequence has cost 0
                    cost_pos <= 24'd0;
                    cost_neg <= 24'd0;
                    cost_empty <= 24'd0;
                end
                
                DP_PROCESS: begin
                    if (dp_counter < 4'd16) begin
                        // Calculate min of previous states
                        min_prev_01 <= min2(cost_pos, cost_neg);
                        min_prev_02 <= min2(cost_pos, cost_empty);
                        min_prev_12 <= min2(cost_neg, cost_empty);
                        
                        // Get current score
                        current_score <= s_mem[dp_counter];
                        
                        // Update DP state for next cycle
                        cost_pos <= cost_pos_next;
                        cost_neg <= cost_neg_next;
                        cost_empty <= cost_empty_next;
                        
                        dp_counter <= dp_counter + 4'd1;
                    end
                end
                
                CALC_RESULT: begin
                    // Final result is min of all three states
                    result <= min3(cost_pos, cost_neg, cost_empty);
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_SCORES;
                else next_state = IDLE;
            end
            
            LOAD_SCORES: begin
                if (load_counter >= 4'd16) next_state = DP_INIT;
                else next_state = LOAD_SCORES;
            end
            
            DP_INIT: begin
                next_state = DP_PROCESS;
            end
            
            DP_PROCESS: begin
                if (dp_counter >= 4'd16 || cycle_count >= MAX_CYCLES) begin
                    next_state = CALC_RESULT;
                end else begin
                    next_state = DP_PROCESS;
                end
            end
            
            CALC_RESULT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // DP calculation logic (combinational)
    always @(*) begin
        // Cost to remove current: min of all previous states + R
        temp_remove = min3(cost_pos, cost_neg, cost_empty) + {8'd0, r_in};
        
        // Cost to keep as positive
        if (current_score > 8'sd0) begin
            // Already positive, no flip cost
            temp_keep_pos = min_prev_12;  // Can come from negative or empty
        end else begin
            // Need to flip sign
            temp_keep_pos = min_prev_12 + {8'd0, c_in};
        end
        
        // Cost to keep as negative
        if (current_score < 8'sd0) begin
            // Already negative, no flip cost
            temp_keep_neg = min_prev_02;  // Can come from positive or empty
        end else begin
            // Need to flip sign
            temp_keep_neg = min_prev_02 + {8'd0, c_in};
        end
        
        // Update next DP state
        cost_pos_next = temp_keep_pos;
        cost_neg_next = temp_keep_neg;
        cost_empty_next = temp_remove;
    end

endmodule