module ComputeSum(
    input clk,
    input rst_n,
    input start,
    input [7:0] L,
    input [7:0] R,
    output reg [31:0] result,
    output reg done
);
    // Modulo constant: 1,000,000,007 (0x3B9ACA07)
    localparam [31:0] MOD = 32'd1000000007;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTING_F = 3'd1;
    localparam [2:0] ADDING = 3'd2;
    localparam [2:0] DONE = 3'd3;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] current_X;
    reg [7:0] current_sum;
    reg [31:0] result_reg;
    reg [7:0] outer_counter;  // from L to R
    reg [31:0] inner_counter;  // iterations for f(X)
    reg [31:0] temp_sum;
    
    // Control flags
    reg computation_done;
    
    // Cycle counter to prevent infinite loops (max 65536)
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd65536;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            current_X <= 8'd0;
            current_sum <= 8'd0;
            outer_counter <= 8'd0;
            inner_counter <= 32'd0;
            temp_sum <= 32'd0;
            cycle_count <= 16'd0;
            computation_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= COMPUTING_F;
                        outer_counter <= L;
                        current_X <= L;
                        current_sum <= 8'd0;
                        result_reg <= 32'd0;
                        computation_done <= 1'b0;
                    end
                end
                
                COMPUTING_F: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // f(X) algorithm: count iterations until X becomes 1
                    // Edge case: X=1 returns 0 iterations
                    if (current_X == 8'd1) begin
                        inner_counter <= 32'd0;
                        state <= ADDING;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Safety timeout - go to DONE
                        state <= DONE;
                    end else if (current_X[0] == 1'b1) begin
                        // X is odd and X > 1 (since X != 1 was checked)
                        // X = X + 1
                        current_X <= current_X + 8'd1;
                        inner_counter <= inner_counter + 32'd1;
                    end else begin
                        // X is even
                        // X = X / 2
                        current_X <= {1'b0, current_X[7:1]};
                        inner_counter <= inner_counter + 32'd1;
                    end
                    
                    // Check if X has become 1 (for even case)
                    if (current_X == 8'd1 && current_X != 8'd1) begin
                        // This condition won't trigger in the same cycle,
                        // but we need to detect it
                    end
                    
                    // Special check for even X becoming 1
                    if (current_X[0] == 1'b0 && current_X[7:1] == 7'd1) begin
                        // After division, X will be 1
                        state <= ADDING;
                    end
                    
                    // Also check for odd X that will become 2, then 1
                    if (current_X == 8'd2) begin
                        // X=2 (even), after division X=1
                        state <= ADDING;
                    end
                    
                    // For odd X, after X=X+1 it becomes even
                    // Need to continue loop
                end
                
                ADDING: begin
                    // Add inner_counter to result_reg with modulo
                    temp_sum <= result_reg + inner_counter;
                    
                    // Move to next X
                    if (outer_counter < R) begin
                        outer_counter <= outer_counter + 8'd1;
                        current_X <= outer_counter + 8'd1;
                        inner_counter <= 32'd0;
                        state <= COMPUTING_F;
                    end else begin
                        computation_done <= 1'b1;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    // Apply modulo and output
                    if (temp_sum >= MOD) begin
                        result_reg <= temp_sum - MOD;
                    end else begin
                        result_reg <= temp_sum;
                    end
                    
                    result <= (temp_sum >= MOD) ? (temp_sum - MOD) : temp_sum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Additional logic for COMPUTING_F state (edge cases)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == COMPUTING_F) begin
                // Handle the detection of when X becomes 1
                if (current_X[0] == 1'b0) begin
                    // Even number: after division
                    if (current_X == 8'd2) begin
                        // 2 / 2 = 1
                        state <= ADDING;
                    end else if (current_X == 8'd1) begin
                        // Already at 1
                        state <= ADDING;
                    end
                end else if (current_X != 8'd1) begin
                    // Odd number > 1
                    if (current_X == 8'd3) begin
                        // 3 -> 4 (odd), then 4 -> 2 (even), then 2 -> 1
                        // This will take 2 more cycles
                        current_X <= current_X + 8'd1;
                        inner_counter <= inner_counter + 32'd1;
                    end
                end
            end
        end
    end
    
    // Simplified COMPUTING_F logic with proper termination
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else if (state == COMPUTING_F) begin
            // Proper f(X) algorithm
            if (current_X == 8'd1) begin
                // X reached 1, go to adding
                state <= ADDING;
            end else begin
                // Continue algorithm
                if (current_X[0] == 1'b0) begin
                    // Even: X = X / 2
                    current_X <= {1'b0, current_X[7:1]};
                    inner_counter <= inner_counter + 32'd1;
                    
                    // Check if result will be 1
                    if (current_X == 8'd2) begin
                        // After this cycle, X=1
                        state <= ADDING;
                    end
                end else begin
                    // Odd: X = X + 1
                    current_X <= current_X + 8'd1;
                    inner_counter <= inner_counter + 32'd1;
                end
            end
        end
    end
endmodule