module fizz_buzz_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] count,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK      = 3'd1;
    localparam [2:0] EXTRACT    = 3'd2;
    localparam [2:0] INCREMENT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    // Registers
    reg [2:0] state, next_state;
    reg [15:0] x;           // Current number being checked
    reg [15:0] temp_count;  // Count of 7s in current number
    reg [15:0] temp_num;    // Working number for digit extraction
    reg [2:0] digit_count;  // Track digits extracted (max 5)
    reg divisible;          // Flag for divisibility check
    reg [7:0] cycle_count;  // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Division remainder calculations (combinational)
    wire [15:0] rem_11;
    wire [15:0] rem_13;
    assign rem_11 = x % 16'd11;
    assign rem_13 = x % 16'd13;
    
    // Digit extraction: get last digit (temp_num % 10)
    wire [15:0] last_digit;
    assign last_digit = temp_num % 16'd10;
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 16'd0;
            done <= 1'b0;
            x <= 16'd0;
            temp_count <= 16'd0;
            temp_num <= 16'd0;
            digit_count <= 3'd0;
            divisible <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 16'd0;
                    x <= 16'd0;
                    temp_count <= 16'd0;
                    temp_num <= 16'd0;
                    digit_count <= 3'd0;
                    divisible <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                CHECK: begin
                    // Check if x < n
                    if (x >= n) begin
                        state <= DONE_STATE;
                    end else begin
                        // Check divisibility by 11 or 13
                        if ((rem_11 == 16'd0) || (rem_13 == 16'd0)) begin
                            divisible <= 1'b1;
                            temp_num <= x;
                            temp_count <= 16'd0;
                            digit_count <= 3'd0;
                            state <= EXTRACT;
                        end else begin
                            divisible <= 1'b0;
                            state <= INCREMENT;
                        end
                    end
                end
                
                EXTRACT: begin
                    // Extract decimal digits (max 5)
                    if (temp_num == 16'd0 || digit_count >= 3'd5) begin
                        // Done extracting digits
                        if (divisible) begin
                            state <= INCREMENT;
                        end else begin
                            state <= INCREMENT;
                        end
                    end else begin
                        // Check if last digit is 7
                        if (last_digit == 4'd7) begin
                            temp_count <= temp_count + 16'd1;
                        end
                        // Divide by 10 for next digit
                        temp_num <= temp_num / 16'd10;
                        digit_count <= digit_count + 3'd1;
                    end
                end
                
                INCREMENT: begin
                    // Add count from current number if divisible
                    if (divisible) begin
                        count <= count + temp_count;
                    end
                    // Move to next number
                    x <= x + 16'd1;
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES || x >= n - 16'd1) begin
                        state <= CHECK;  // Will hit DONE_STATE next
                    end else begin
                        state <= CHECK;
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
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK;
                else next_state = IDLE;
            end
            CHECK: begin
                // Handled in state machine with x comparison
                next_state = CHECK;  // Default, actual logic in state block
            end
            EXTRACT: next_state = EXTRACT;  // Default, logic in state block
            INCREMENT: next_state = CHECK;  // Default
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
endmodule