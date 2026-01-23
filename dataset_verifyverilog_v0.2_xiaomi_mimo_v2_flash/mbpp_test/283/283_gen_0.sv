module digit_validator(
    input clk,
    input rst_n,
    input start,
    input [31:0] number,
    output reg valid,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam EXTRACT_DIGIT = 3'b001;
    localparam CHECK_COUNT = 3'b010;
    localparam UPDATE_COUNTER = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] state;
    reg [3:0] counters [0:9]; // 10 counters, 4-bit each
    reg [3:0] current_digit;
    reg [3:0] digit_index;    // 0 to 7 (8 digits)
    reg temp_valid;
    reg [31:0] shift_reg;
    reg start_prev;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            start_prev <= 1'b0;
            // Reset counters
            for (i = 0; i < 10; i = i + 1) begin
                counters[i] <= 4'b0;
            end
        end else begin
            start_prev <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    // Detect rising edge of start
                    if (start && !start_prev) begin
                        // Reset counters and state vars
                        for (i = 0; i < 10; i = i + 1) begin
                            counters[i] <= 4'b0;
                        end
                        digit_index <= 4'd0;
                        shift_reg <= number;
                        temp_valid <= 1'b1;
                        state <= EXTRACT_DIGIT;
                    end
                end

                EXTRACT_DIGIT: begin
                    // Extract the last decimal digit (base 10)
                    current_digit <= shift_reg[3:0];
                    // Right shift by approx 3.3219 bits (divide by 10)
                    // Integer division by 10: N / 10 = floor(N * 205 / 2048)
                    shift_reg <= (shift_reg * 205) >> 11;
                    state <= CHECK_COUNT;
                end

                CHECK_COUNT: begin
                    // Check if count[d] + 1 <= d (lookahead check)
                    // If current_digit is 0, count 1 <= 0 is always false -> invalid
                    if (current_digit == 0) begin
                        temp_valid <= 1'b0;
                    end else if (counters[current_digit] >= current_digit) begin
                        // current count >= digit, so count+1 > digit
                        temp_valid <= 1'b0;
                    end
                    state <= UPDATE_COUNTER;
                end

                UPDATE_COUNTER: begin
                    // Increment the counter for the current digit
                    counters[current_digit] <= counters[current_digit] + 1;
                    
                    if (digit_index == 7) begin
                        state <= DONE;
                    end else begin
                        digit_index <= digit_index + 1;
                        state <= EXTRACT_DIGIT;
                    end
                end

                DONE: begin
                    valid <= temp_valid;
                    done <= 1'b1;
                    // Wait for start to go low to return to IDLE
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
