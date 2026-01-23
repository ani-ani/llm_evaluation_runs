module repeating_decimal_converter(
    input clk,
    input rst_n,
    input start,
    input [7:0] decimal_int_part,
    input [31:0] decimal_frac_part,
    input [3:0] frac_digits,
    input [3:0] repeat_count,
    output reg [63:0] numerator,
    output reg [63:0] denominator,
    output reg done,
    output reg error
);

    // State definitions
    localparam [3:0] IDLE = 4'b0000;
    localparam [3:0] PARSE = 4'b0001;
    localparam [3:0] COMPUTE_SCALED = 4'b0010;
    localparam [3:0] CALCULATE_GCD = 4'b0011;
    localparam [3:0] REDUCE = 4'b0100;
    localparam [3:0] DONE = 4'b0101;

    // Internal registers
    reg [3:0] state;
    reg [63:0] num, den;
    reg [63:0] temp_gcd;
    reg [7:0] counter;
    reg [63:0] a, b, temp;
    reg [63:0] pow10_L, pow10_LK, pow10_K;
    reg [63:0] A, B;
    reg [31:0] loop_counter;

    // Intermediate values
    reg [63:0] numerator_temp, denominator_temp;

    // Error checking
    reg invalid_input;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            num <= 0;
            den <= 0;
            temp_gcd <= 0;
            counter <= 0;
            a <= 0;
            b <= 0;
            temp <= 0;
            pow10_L <= 0;
            pow10_LK <= 0;
            pow10_K <= 0;
            A <= 0;
            B <= 0;
            loop_counter <= 0;
            numerator_temp <= 0;
            denominator_temp <= 0;
            numerator <= 0;
            denominator <= 0;
            done <= 0;
            error <= 0;
            invalid_input <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    error <= 0;
                    if (start) begin
                        // Validate inputs
                        invalid_input <= (frac_digits == 0) || (repeat_count == 0) || (repeat_count > frac_digits) || (frac_digits > 8);
                        if (!invalid_input) begin
                            state <= PARSE;
                        end else begin
                            error <= 1;
                            state <= IDLE;
                        end
                    end
                end

                PARSE: begin
                    // Calculate powers of 10
                    pow10_L <= 1;
                    pow10_LK <= 1;
                    pow10_K <= 1;
                    loop_counter <= frac_digits;
                    state <= COMPUTE_SCALED;
                end

                COMPUTE_SCALED: begin
                    if (loop_counter > 0) begin
                        if (loop_counter > (frac_digits - repeat_count)) begin
                            pow10_L <= pow10_L * 10;
                        end
                        if (loop_counter > repeat_count) begin
                            pow10_LK <= pow10_LK * 10;
                        end
                        pow10_K <= pow10_K * 10;
                        loop_counter <= loop_counter - 1;
                    end else begin
                        // Separate A (non-repeating) and B (repeating)
                        A <= decimal_frac_part / pow10_K;
                        B <= decimal_frac_part % pow10_K;

                        // Compute numerator and denominator
                        numerator_temp <= decimal_int_part * (pow10_L - pow10_LK) + A * (pow10_K - 1) + B;
                        denominator_temp <= (pow10_L - pow10_LK) * (pow10_K - 1);

                        // Set up for GCD
                        a <= numerator_temp;
                        b <= denominator_temp;
                        state <= CALCULATE_GCD;
                    end
                end

                CALCULATE_GCD: begin
                    if (b != 0) begin
                        temp <= b;
                        b <= a % b;
                        a <= temp;
                    end else begin
                        temp_gcd <= a;
                        state <= REDUCE;
                    end
                end

                REDUCE: begin
                    numerator <= numerator_temp / temp_gcd;
                    denominator <= denominator_temp / temp_gcd;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule