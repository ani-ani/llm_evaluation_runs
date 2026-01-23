module is_simple_power(
    input clk,
    input rst_n,
    input start,
    input [7:0] x,
    input [7:0] n,
    output reg result,
    output reg done
);

// State definitions
localparam [2:0] IDLE    = 3'd0;
localparam [2:0] CHECK   = 3'd1;
localparam [2:0] DIVIDE  = 3'd2;
localparam [2:0] DONE    = 3'd3;

// Registers
reg [2:0] state, next_state;
reg [7:0] current_x;
reg [7:0] current_n;
reg result_reg;
reg [3:0] iter_count;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_x <= 8'd0;
        current_n <= 8'd0;
        result_reg <= 1'b0;
        result <= 1'b0;
        done <= 1'b0;
        iter_count <= 4'd0;
    end else begin
        state <= next_state;
        
        case (next_state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    current_x <= x;
                    current_n <= n;
                    result_reg <= 1'b0;
                    iter_count <= 4'd0;
                end
            end
            
            CHECK: begin
                // Check conditions
                if (current_x == 8'd1) begin
                    result_reg <= 1'b1;
                    next_state <= DONE;
                end else if (current_n == 8'd1) begin
                    // n == 1, x must be 1 to be power
                    // Already handled x==1 above, so if here, x != 1
                    result_reg <= 1'b0;
                    next_state <= DONE;
                end else if (current_n == 8'd0) begin
                    // n == 0: valid powers are 0^0=1 or 0^1=0
                    if (current_x == 8'd0 || current_x == 8'd1) begin
                        result_reg <= 1'b1;
                    end else begin
                        result_reg <= 1'b0;
                    end
                    next_state <= DONE;
                end else if (current_x % current_n != 8'd0) begin
                    // Not divisible, not a power
                    result_reg <= 1'b0;
                    next_state <= DONE;
                end else begin
                    // x is divisible by n, continue division
                    next_state <= DIVIDE;
                end
            end
            
            DIVIDE: begin
                current_x <= current_x / current_n;
                iter_count <= iter_count + 4'd1;
                next_state <= CHECK;
                
                // Safety: if we've iterated too many times, give up
                if (iter_count >= 4'd8) begin
                    result_reg <= 1'b0;
                    next_state <= DONE;
                end
            end
            
            DONE: begin
                result <= result_reg;
                done <= 1'b1;
                next_state <= IDLE;
            end
            
            default: begin
                next_state <= IDLE;
                result <= 1'b0;
                done <= 1'b0;
            end
        endcase
    end
end

// Combinational next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) next_state = CHECK;
            else next_state = IDLE;
        end
        CHECK: begin
            // Determined based on conditions above
            next_state = CHECK; // Will be overridden in sequential logic
        end
        DIVIDE: begin
            next_state = CHECK;
        end
        DONE: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

endmodule