module GoldbachValidator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire input_valid,
    input wire [7:0] char_in,
    output reg result,
    output reg done
);

    // State Definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] WAIT_FOR_NUM  = 3'd1;
    localparam [2:0] IN_NUM        = 3'd2;
    localparam [2:0] VALIDATE      = 3'd3;
    localparam [2:0] CHECK_PRIMES  = 3'd4;
    localparam [2:0] CHECK_GOLDBACH= 3'd5;
    localparam [2:0] FINISH        = 3'd6;

    reg [2:0] state, next_state;

    // Constants
    localparam [31:0] MAX_VAL      = 32'd1000000000; // 10^9
    localparam [31:0] TWO          = 32'd2;
    localparam [31:0] THREE        = 32'd3;
    localparam [15:0] MAX_PRIME_CHECK = 16'd31623;

    // Helper for ASCII checks
    wire is_space, is_tab, is_newline, is_digit;
    assign is_space   = (char_in == 8'd32);
    assign is_tab     = (char_in == 8'd9);
    assign is_newline = (char_in == 8'd10);
    assign is_digit   = (char_in >= 8'd48) && (char_in <= 8'd57);

    // Internal Registers
    reg [31:0] int_n, int_p, int_q;
    reg [31:0] current_val;
    reg [1:0] num_count; // 0, 1, 2, 3
    reg leading_zero_err;
    reg overflow_err;
    reg invalid_char_err;
    reg [31:0] divisor;
    reg is_prime_flag;
    reg [1:0] prime_check_idx; // 0 for P, 1 for Q, 2 for done

    // Control Flags
    reg parsing_done;
    reg validation_failed;

    // Sequential Logic: State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            int_n <= 32'd0;
            int_p <= 32'd0;
            int_q <= 32'd0;
            current_val <= 32'd0;
            num_count <= 2'd0;
            leading_zero_err <= 1'b0;
            overflow_err <= 1'b0;
            invalid_char_err <= 1'b0;
            divisor <= 32'd0;
            is_prime_flag <= 1'b0;
            prime_check_idx <= 2'd0;
            parsing_done <= 1'b0;
            validation_failed <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default done to 0 unless in finish state asserting it
            done <= 1'b0;

            case (state)
                IDLE: begin
                    // Reset all data registers on start
                    int_n <= 32'd0;
                    int_p <= 32'd0;
                    int_q <= 32'd0;
                    current_val <= 32'd0;
                    num_count <= 2'd0;
                    leading_zero_err <= 1'b0;
                    overflow_err <= 1'b0;
                    invalid_char_err <= 1'b0;
                    parsing_done <= 1'b0;
                    validation_failed <= 1'b0;
                    result <= 1'b0;
                end

                WAIT_FOR_NUM: begin
                    if (input_valid) begin
                        if (is_digit) begin
                            current_val <= (char_in - 8'd48);
                            if (char_in == 8'd48) // '0'
                                leading_zero_err <= 1'b1;
                            else
                                leading_zero_err <= 1'b0;
                        end else if (!(is_space || is_tab || is_newline)) begin
                            invalid_char_err <= 1'b1;
                        end
                    end
                end

                IN_NUM: begin
                    if (input_valid) begin
                        if (is_digit) begin
                            // Accumulate: val = val * 10 + digit
                            // Check overflow: val > (MAX_VAL - digit) / 10
                            // Simplified: if current_val > MAX_VAL/10, overflow.
                            // Or if current_val * 10 + digit > MAX_VAL
                            if (current_val > 32'd100000000) begin // 10^8
                                overflow_err <= 1'b1;
                            end else begin
                                current_val <= current_val * 10 + (char_in - 8'd48);
                            end
                        end else if (is_space || is_tab || is_newline) begin
                            // End of number
                            if (overflow_err || leading_zero_err) begin
                                validation_failed <= 1'b1;
                            end else begin
                                // Store number
                                if (num_count == 2'd0) int_n <= current_val;
                                else if (num_count == 2'd1) int_p <= current_val;
                                else if (num_count == 2'd2) int_q <= current_val;
                                
                                num_count <= num_count + 1'b1;
                            end
                            current_val <= 32'd0;
                        end else begin
                            invalid_char_err <= 1'b1;
                        end
                    end
                end

                VALIDATE: begin
                    // Prepare for prime check
                    divisor <= 32'd2;
                    is_prime_flag <= 1'b1;
                    // Validation logic
                    if (num_count != 2'd3 || invalid_char_err) begin
                        validation_failed <= 1'b1;
                    end else if (int_n <= THREE || int_n > MAX_VAL) begin
                        validation_failed <= 1'b1;
                    end else if (int_n[0] != 1'b0) begin // Check even (LSB 0)
                        validation_failed <= 1'b1;
                    end else if (int_p < TWO || int_q < TWO) begin
                        validation_failed <= 1'b1;
                    end
                end

                CHECK_PRIMES: begin
                    // Sequential divisor check
                    // We check P first, then Q. prime_check_idx tracks which.
                    // Limit divisor to sqrt(val). sqrt(10^9) ~ 31623.
                    // We iterate divisor. If divisor > sqrt(val), stop.
                    // Optimization: Stop if divisor * divisor > val.
                    
                    // We check P first (idx 0), then Q (idx 1)
                    if (prime_check_idx < 2'd2) begin
                        // Check current divisor
                        if (divisor * divisor > (prime_check_idx == 2'd0 ? int_p : int_q)) begin
                            // Done checking this number
                            if (!is_prime_flag) validation_failed <= 1'b1;
                            prime_check_idx <= prime_check_idx + 1'b1;
                            divisor <= 32'd2;
                            is_prime_flag <= 1'b1;
                        end else begin
                            // Check divisibility
                            if ( (prime_check_idx == 2'd0 ? (int_p % divisor == 0) : (int_q % divisor == 0)) ) begin
                                is_prime_flag <= 1'b0;
                            end
                            // Increment divisor
                            if (divisor == 32'd2) divisor <= 32'd3;
                            else divisor <= divisor + 32'd2; // Check 2, 3, 5, 7... 
                            // Note: skipping evens after 2 is handled by logic above
                            // To be safe against skipped evens like 4, 6... we can just increment by 1 if area permits,
                            // or handle specific skips. Let's stick to +1 for simplicity/synthesis safety,
                            // or +2 with a 2,3,5 start.
                            // Let's use: if divisor==2 -> 3, else divisor+2.
                            if (divisor == 32'd2) divisor <= 32'd3;
                            else divisor <= divisor + 32'd2;
                        end
                    end
                end

                CHECK_GOLDBACH: begin
                    if (!validation_failed) begin
                        if (int_n != (int_p + int_q)) validation_failed <= 1'b1;
                    end
                end

                FINISH: begin
                    result <= !validation_failed;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = IDLE; // Default
        case (state)
            IDLE: begin
                if (start) next_state = WAIT_FOR_NUM;
                else next_state = IDLE;
            end

            WAIT_FOR_NUM: begin
                if (!input_valid) next_state = WAIT_FOR_NUM;
                else begin
                    if (is_digit) next_state = IN_NUM;
                    else if (is_space || is_tab || is_newline) next_state = WAIT_FOR_NUM;
                    else next_state = IN_NUM; // Invalid char handled in seq logic
                end
            end

            IN_NUM: begin
                if (!input_valid) next_state = IN_NUM;
                else begin
                    if (is_digit) next_state = IN_NUM;
                    else if (is_space || is_tab || is_newline) begin
                        if (num_count == 2'd3) next_state = VALIDATE;
                        else next_state = WAIT_FOR_NUM;
                    end else begin
                        next_state = IN_NUM; // Invalid char
                    end
                end
            end

            VALIDATE: begin
                if (validation_failed) next_state = FINISH;
                else next_state = CHECK_PRIMES;
            end

            CHECK_PRIMES: begin
                if (validation_failed) next_state = FINISH;
                else if (prime_check_idx >= 2'd2) next_state = CHECK_GOLDBACH;
                else next_state = CHECK_PRIMES;
            end

            CHECK_GOLDBACH: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE; // Return to idle for next stream
            end

            default: next_state = IDLE;
        endcase
    end

endmodule