module MinCostUnbalanced (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] k,
    input [15:0] str,
    input [127:0] cost,
    output reg [15:0] result,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_BALANCE = 3'd1;
    localparam [2:0] COMPUTE_MIN_COST = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [3:0] pos_idx;
    reg [3:0] flip_idx;
    reg [15:0] temp_result;
    reg [15:0] min_cost;
    reg can_balance_orig;
    reg can_balance_flipped;
    reg [7:0] balance_orig [0:15];
    reg [7:0] balance_flipped [0:15];
    reg [7:0] i_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Temporary variables for balance checking
    reg [7:0] current_balance;
    reg balance_valid;
    reg [7:0] current_pos;
    
    // Signal for intermediate cost calculation
    wire [15:0] current_cost;
    wire [7:0] cost_element;
    wire [7:0] cost_element_flipped;
    wire signed [7:0] signed_cost;
    wire signed [7:0] signed_cost_flipped;
    wire signed [15:0] signed_cost_16;
    wire signed [15:0] signed_cost_flipped_16;
    wire signed [15:0] total_cost;
    
    // Extract cost elements from packed array
    assign cost_element = cost[7:0] >> (flip_idx * 8);
    assign cost_element_flipped = cost[7:0] >> (flip_idx * 8);
    
    assign signed_cost = cost_element[7:0];
    assign signed_cost_flipped = cost_element_flipped[7:0];
    
    assign signed_cost_16 = {{8{signed_cost[7]}}, signed_cost};
    assign signed_cost_flipped_16 = {{8{signed_cost_flipped[7]}}, signed_cost_flipped};
    
    assign total_cost = signed_cost_16 + signed_cost_flipped_16;
    assign current_cost = (total_cost < 0) ? -total_cost : total_cost;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            pos_idx <= 4'd0;
            flip_idx <= 4'd0;
            temp_result <= 16'd0;
            min_cost <= 16'h7FFF;
            can_balance_orig <= 1'b0;
            can_balance_flipped <= 1'b0;
            i_reg <= 8'd0;
            cycle_count <= 8'd0;
            current_balance <= 8'd0;
            balance_valid <= 1'b0;
            current_pos <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 8'd0;
                    pos_idx <= 4'd0;
                    flip_idx <= 4'd0;
                    temp_result <= 16'd0;
                    min_cost <= 16'h7FFF;
                    can_balance_orig <= 1'b0;
                    can_balance_flipped <= 1'b0;
                    current_balance <= 8'd0;
                    balance_valid <= 1'b0;
                    current_pos <= 8'd0;
                    
                    if (start) begin
                        state <= CHECK_BALANCE;
                        i_reg <= 8'd0;
                    end
                end
                
                CHECK_BALANCE: begin
                    // Check if original string can be balanced
                    // Check prefix condition and total sum
                    current_balance <= 8'd0;
                    balance_valid <= 1'b1;
                    
                    if (i_reg < n) begin
                        if (str[i_reg] == 1'b0) begin
                            current_balance <= current_balance + 8'd1;
                        end else begin
                            if (current_balance > 8'd0) begin
                                current_balance <= current_balance - 8'd1;
                            end else begin
                                balance_valid <= 1'b0;
                            end
                        end
                        i_reg <= i_reg + 8'd1;
                    end else begin
                        // After checking all positions
                        if (balance_valid && (current_balance == 8'd0)) begin
                            can_balance_orig <= 1'b1;
                        end else begin
                            can_balance_orig <= 1'b0;
                        end
                        
                        // If original can't be balanced, we're done (impossible already)
                        if (!balance_valid || (current_balance != 8'd0)) begin
                            result <= 16'h8000;
                            impossible <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            // Original can be balanced, need to find min cost flip
                            state <= COMPUTE_MIN_COST;
                            flip_idx <= 4'd0;
                            temp_result <= 16'h7FFF;
                        end
                    end
                end
                
                COMPUTE_MIN_COST: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (flip_idx < n) begin
                        // Check if flipping position flip_idx makes string impossible
                        current_balance <= 8'd0;
                        balance_valid <= 1'b1;
                        
                        // Simulate the flipped string
                        for (i_reg = 8'd0; i_reg < n; i_reg = i_reg + 8'd1) begin
                            if (i_reg == flip_idx) begin
                                // Flipped character
                                if (str[flip_idx] == 1'b0) begin
                                    // was '(', now ')'
                                    if (current_balance > 8'd0) begin
                                        current_balance <= current_balance - 8'd1;
                                    end else begin
                                        balance_valid <= 1'b0;
                                    end
                                end else begin
                                    // was ')', now '('
                                    current_balance <= current_balance + 8'd1;
                                end
                            end else begin
                                // Unchanged character
                                if (str[i_reg] == 1'b0) begin
                                    current_balance <= current_balance + 8'd1;
                                end else begin
                                    if (current_balance > 8'd0) begin
                                        current_balance <= current_balance - 8'd1;
                                    end else begin
                                        balance_valid <= 1'b0;
                                    end
                                end
                            end
                        end
                        
                        // After checking this flip
                        if (!balance_valid || (current_balance != 8'd0)) begin
                            // This flip makes it impossible
                            // Get the cost for this flip
                            temp_result <= cost[flip_idx*8 +: 8];
                            
                            // Update min_cost if this cost is lower
                            if (temp_result < min_cost) begin
                                min_cost <= temp_result;
                            end
                        end
                        
                        flip_idx <= flip_idx + 8'd1;
                    end else begin
                        // Done checking all flips
                        if (min_cost < 16'h7FFF) begin
                            result <= min_cost;
                            impossible <= 1'b1;
                        end else begin
                            result <= 16'h8000;
                            impossible <= 1'b0;
                        end
                        state <= DONE_STATE;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 16'h8000;
                        impossible <= 1'b0;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule