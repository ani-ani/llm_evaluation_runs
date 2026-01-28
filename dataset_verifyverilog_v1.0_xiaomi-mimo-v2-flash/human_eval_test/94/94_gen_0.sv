module find_largest_prime_digit_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] arr_0,
    input wire [15:0] arr_1,
    input wire [15:0] arr_2,
    input wire [15:0] arr_3,
    input wire [15:0] arr_4,
    input wire [15:0] arr_5,
    input wire [15:0] arr_6,
    input wire [15:0] arr_7,
    input wire [15:0] arr_8,
    input wire [15:0] arr_9,
    input wire [15:0] arr_10,
    input wire [15:0] arr_11,
    input wire [15:0] arr_12,
    input wire [15:0] arr_13,
    input wire [15:0] arr_14,
    input wire [15:0] arr_15,
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] SCAN        = 3'd1;
    localparam [2:0] CHECK_PRIME = 3'd2;
    localparam [2:0] UPDATE_MAX  = 3'd3;
    localparam [2:0] DIGIT_SUM   = 3'd4;
    localparam [2:0] DONE        = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] index;              // Current index in array (0-15)
    reg [15:0] current_val;       // Value being checked
    reg [15:0] largest_prime;     // Largest prime found so far
    reg [15:0] temp_val;          // Temporary for digit sum calculation
    reg [15:0] digit_sum;         // Accumulated digit sum
    reg [7:0] divisor;            // Divisor for prime check (1-255)
    reg is_prime;                 // Flag for prime checking
    reg [7:0] cycle_count;        // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Combinational wire for array element selection
    reg [15:0] arr_selected;

    // Always block for sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            index <= 4'd0;
            current_val <= 16'd0;
            largest_prime <= 16'd0;
            temp_val <= 16'd0;
            digit_sum <= 16'd0;
            divisor <= 8'd0;
            is_prime <= 1'b0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    largest_prime <= 16'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    // Select current array element based on index
                    case (index)
                        4'd0:  current_val <= arr_0;
                        4'd1:  current_val <= arr_1;
                        4'd2:  current_val <= arr_2;
                        4'd3:  current_val <= arr_3;
                        4'd4:  current_val <= arr_4;
                        4'd5:  current_val <= arr_5;
                        4'd6:  current_val <= arr_6;
                        4'd7:  current_val <= arr_7;
                        4'd8:  current_val <= arr_8;
                        4'd9:  current_val <= arr_9;
                        4'd10: current_val <= arr_10;
                        4'd11: current_val <= arr_11;
                        4'd12: current_val <= arr_12;
                        4'd13: current_val <= arr_13;
                        4'd14: current_val <= arr_14;
                        4'd15: current_val <= arr_15;
                        default: current_val <= 16'd0;
                    endcase
                    
                    if (index >= len) begin
                        // Done scanning all elements
                        if (largest_prime > 16'd0) begin
                            state <= DIGIT_SUM;
                            temp_val <= largest_prime;
                            digit_sum <= 16'd0;
                        end else begin
                            // No primes found
                            result <= 16'd0;
                            state <= DONE;
                        end
                    end else begin
                        state <= CHECK_PRIME;
                        divisor <= 8'd2;      // Start checking from d=2
                        is_prime <= 1'b1;     // Assume prime until proven otherwise
                    end
                end

                CHECK_PRIME: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Condition 1: Must be > 1
                    if (current_val <= 16'd1) begin
                        is_prime <= 1'b0;
                        state <= UPDATE_MAX;
                    end
                    // Condition 2: Check divisibility
                    else if (divisor > 8'd255) begin
                        // Reached limit (max sqrt for 16-bit)
                        state <= UPDATE_MAX;
                    end
                    else if (divisor >= current_val[7:0]) begin
                        // Divisor >= value (should not happen for valid primes)
                        state <= UPDATE_MAX;
                    end
                    else if (divisor * divisor > current_val) begin
                        // Divisor > sqrt(current_val) - prime confirmed
                        state <= UPDATE_MAX;
                    end
                    else begin
                        // Check divisibility: if (current_val % divisor == 0)
                        if (current_val % divisor == 0) begin
                            is_prime <= 1'b0;
                            state <= UPDATE_MAX;
                        end else begin
                            divisor <= divisor + 8'd1;
                            // Stay in CHECK_PRIME
                        end
                    end
                end

                UPDATE_MAX: begin
                    if (is_prime && (current_val > largest_prime)) begin
                        largest_prime <= current_val;
                    end
                    index <= index + 4'd1;
                    state <= SCAN;
                end

                DIGIT_SUM: begin
                    if (temp_val == 16'd0) begin
                        // Done summing digits
                        result <= digit_sum;
                        state <= DONE;
                    end else begin
                        // temp % 10
                        digit_sum <= digit_sum + (temp_val % 10);
                        // temp = temp / 10
                        temp_val <= temp_val / 16'd10;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase

            // Safety timeout to prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE;
                result <= 16'd0;
            end
        end
    end

endmodule