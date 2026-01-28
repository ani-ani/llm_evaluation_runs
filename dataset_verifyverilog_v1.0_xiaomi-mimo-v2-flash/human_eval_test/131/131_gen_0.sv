module ProductOfOddDigits (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_in,
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] EXTRACT  = 2'd1;
    localparam [1:0] MULTIPLY = 2'd2;
    localparam [1:0] DONE     = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] current_n;
    reg [3:0] digit_count;      // Counts digits processed (max 5 for 65535)
    reg [15:0] temp_product;
    reg [7:0] current_digit;
    reg [3:0] cycle_counter;    // Prevents infinite loops
    localparam [3:0] MAX_CYCLES = 4'd15;
    reg found_odd;              // Flag to track if any odd digits found

    // State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE: next_state = start ? EXTRACT : IDLE;
            EXTRACT: next_state = (current_n == 16'd0) ? DONE : MULTIPLY;
            MULTIPLY: next_state = (current_n == 16'd0) ? DONE : EXTRACT;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_n <= 16'd0;
            digit_count <= 4'd0;
            temp_product <= 16'd1;
            current_digit <= 8'd0;
            cycle_counter <= 4'd0;
            found_odd <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 4'd0;
                    digit_count <= 4'd0;
                    temp_product <= 16'd1;
                    found_odd <= 1'b0;
                    if (start) begin
                        current_n <= n_in;
                        state <= EXTRACT;
                    end
                end

                EXTRACT: begin
                    // Extract digit via modulus 10 (repeated subtraction)
                    // This takes multiple cycles - we use a simple 4-bit counter
                    // For synthesis, we unroll the loop for 0-9
                    if (current_n >= 16'd10) begin
                        current_n <= current_n - 16'd10;
                        digit_count <= digit_count + 4'd1;
                    end else begin
                        // Current digit is the remainder (0-9)
                        current_digit <= current_n[7:0];
                        // Now check if odd and prepare for division
                        // Division by 10 via repeated subtraction
                        if (current_digit[0] == 1'b1) begin // Odd digit
                            found_odd <= 1'b1;
                            state <= MULTIPLY;
                        end else begin
                            // Even digit, skip multiply, go to division
                            state <= EXTRACT; // Stay in extract for division
                        end
                        // Set current_n for next iteration (quotient)
                        // This will be done in MULTIPLY state or loop back
                    end
                    cycle_counter <= cycle_counter + 4'd1;
                end

                MULTIPLY: begin
                    // Perform division by 10 for next iteration
                    // We use repeated subtraction for division
                    if (current_n >= 16'd10) begin
                        current_n <= current_n - 16'd10;
                        digit_count <= digit_count + 4'd1;
                        // Stay in MULTIPLY to continue division
                    end else begin
                        // Quotient obtained, ready for next digit extraction
                        current_n <= current_n; // Quotient is already in current_n
                        state <= EXTRACT;
                        // If odd digit, multiply it into temp_product
                        if (current_digit[0] == 1'b1 && current_digit != 8'd0) begin
                            temp_product <= temp_product * current_digit;
                        end
                    end
                    cycle_counter <= cycle_counter + 4'd1;
                end

                DONE: begin
                    // Final result and done pulse
                    if (found_odd) begin
                        result <= temp_product;
                    end else begin
                        result <= 16'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Safety timeout
            if (cycle_counter >= MAX_CYCLES) begin
                state <= DONE;
            end
        end
    end
endmodule