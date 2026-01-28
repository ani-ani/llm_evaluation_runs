module nsw_prime_computer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] STATE_IDLE    = 2'd0;
    localparam [1:0] STATE_COMPUTE = 2'd1;
    localparam [1:0] STATE_DONE    = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] count, next_count;
    reg [31:0] prev, next_prev;
    reg [31:0] prev2, next_prev2;
    reg [31:0] result_reg, next_result;
    reg done_reg, next_done;
    reg [3:0] n_reg, next_n_reg;
    reg computing, next_computing;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count, next_cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State register and synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            count <= 4'd0;
            prev <= 32'd0;
            prev2 <= 32'd0;
            result_reg <= 32'd0;
            done_reg <= 1'b0;
            n_reg <= 4'd0;
            computing <= 1'b0;
            cycle_count <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            count <= next_count;
            prev <= next_prev;
            prev2 <= next_prev2;
            result_reg <= next_result;
            done_reg <= next_done;
            n_reg <= next_n_reg;
            computing <= next_computing;
            cycle_count <= next_cycle_count;
            result <= next_result;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default values
        next_state = state;
        next_count = count;
        next_prev = prev;
        next_prev2 = prev2;
        next_result = result_reg;
        next_done = 1'b0;
        next_n_reg = n_reg;
        next_computing = computing;
        next_cycle_count = cycle_count;

        case (state)
            STATE_IDLE: begin
                next_done = 1'b0;
                next_cycle_count = 8'd0;
                next_computing = 1'b0;
                
                if (start) begin
                    next_n_reg = n;
                    next_computing = 1'b1;
                    
                    // Initialize for all cases
                    next_prev = 32'd1;  // NSW(0) = 1
                    next_prev2 = 32'd1; // NSW(1) = 1 (used for n>=2)
                    next_count = 4'd0;
                    next_cycle_count = 8'd1;
                    
                    if (n == 4'd0 || n == 4'd1) begin
                        // Direct result for base cases
                        next_result = 32'd1;
                        next_state = STATE_DONE;
                    end else begin
                        // For n >= 2, start computing
                        next_state = STATE_COMPUTE;
                    end
                end
            end

            STATE_COMPUTE: begin
                next_cycle_count = cycle_count + 8'd1;
                
                // Compute next NSW value
                // NSW(n) = 2 * NSW(n-1) + NSW(n-2)
                // Use next_prev (NSW(n-1)) and next_prev2 (NSW(n-2))
                next_prev2 = prev;  // shift: prev2 becomes previous prev
                
                // Compute next = 2*prev + prev2
                // Check for overflow to 32-bit (though n<=15 should fit)
                next_prev = (prev << 1) + prev2;
                
                next_count = count + 4'd1;
                
                // Check if computation is complete
                // For n=2: need 1 iteration (count=0 -> 1)
                // For n=15: need 14 iterations (count=0 -> 14)
                // So complete when count >= (n_reg - 1)
                if (count >= (n_reg - 4'd1) || next_cycle_count >= MAX_CYCLES) begin
                    next_result = next_prev;
                    next_state = STATE_DONE;
                    next_computing = 1'b0;
                end else begin
                    next_state = STATE_COMPUTE;
                end
            end

            STATE_DONE: begin
                next_done = 1'b1;
                next_state = STATE_IDLE;
                next_computing = 1'b0;
                next_cycle_count = 8'd0;
                next_count = 4'd0;
            end

            default: begin
                next_state = STATE_IDLE;
                next_done = 1'b0;
            end
        endcase
    end

endmodule