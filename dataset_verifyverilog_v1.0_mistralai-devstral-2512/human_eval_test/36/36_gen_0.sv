module fizz_buzz_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] count,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] EXTRACT   = 3'd2;
    localparam [2:0] INCREMENT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state, next_state;
    reg [15:0] x;              // Current number being checked
    reg [15:0] temp_x;         // Temporary for digit extraction
    reg [3:0] digit;           // Current digit being checked
    reg [15:0] digit_count;    // Count of digit '7' in current number
    reg [15:0] remainder_11;   // Remainder for divisibility by 11
    reg [15:0] remainder_13;   // Remainder for divisibility by 13
    reg divisible;            // Flag if divisible by 11 or 13
    reg [7:0] cycle_counter;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 16'd0;
            done <= 1'b0;
            x <= 16'd0;
            temp_x <= 16'd0;
            digit <= 4'd0;
            digit_count <= 16'd0;
            remainder_11 <= 16'd0;
            remainder_13 <= 16'd0;
            divisible <= 1'b0;
            cycle_counter <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state and output logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CHECK;
                    x = 16'd0;
                    count = 16'd0;
                    cycle_counter = 8'd0;
                end
            end
            
            CHECK: begin
                // Check if x is divisible by 11 or 13
                remainder_11 = x % 11;
                remainder_13 = x % 13;
                divisible = (remainder_11 == 0) || (remainder_13 == 0);
                
                if (divisible) begin
                    next_state = EXTRACT;
                    temp_x = x;
                    digit_count = 16'd0;
                end else begin
                    next_state = INCREMENT;
                end
            end
            
            EXTRACT: begin
                // Extract digits and count '7's
                if (temp_x > 0) begin
                    digit = temp_x % 10;
                    if (digit == 4'd7) begin
                        digit_count = digit_count + 16'd1;
                    end
                    temp_x = temp_x / 10;
                end else begin
                    // Finished extracting digits
                    count = count + digit_count;
                    next_state = INCREMENT;
                end
            end
            
            INCREMENT: begin
                x = x + 16'd1;
                cycle_counter = cycle_counter + 8'd1;
                
                if (x == n || cycle_counter >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CHECK;
                end
            end
            
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule