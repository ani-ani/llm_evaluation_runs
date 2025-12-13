module armstrong_checker (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [15:0] number,
    output logic        result,
    output logic        done
);

    // FSM States
    typedef enum logic [2:0] {
        IDLE         = 3'd0,
        COUNT_DIGITS = 3'd1,
        CALC_POWER   = 3'd2,
        ACCUM_DIGIT  = 3'd3,
        NEXT_DIGIT   = 3'd4,
        COMPARE      = 3'd5,
        FINISH       = 3'd6
    } state_t;

    state_t       state, next_state;

    // Registers
    logic [15:0]  original_num;    // Latched input number
    logic [15:0]  temp_num;        // For digit counting
    logic [3:0]   digit_count;     // Number of digits (max 5 needed for 65535, but spec says 4)
    logic [15:0]  work_num;        // For digit extraction
    logic [3:0]   cur_digit;       // Current digit
    logic [15:0]  power_acc;       // Power accumulation for digit^digits
    logic [3:0]   power_cnt;       // Exponent loop counter
    logic [15:0]  sum;             // Running sum of digit^digits

    // Sequential logic for state and registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            original_num <= 16'd0;
            temp_num     <= 16'd0;
            digit_count  <= 4'd0;
            work_num     <= 16'd0;
            cur_digit    <= 4'd0;
            power_acc    <= 16'd0;
            power_cnt    <= 4'd0;
            sum          <= 16'd0;
            result       <= 1'b0;
            done         <= 1'b0;
        end else begin
            state <= next_state;

            // Default strobes
            case (state)
                IDLE: begin
                    done   <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        original_num <= number;
                        temp_num     <= number;
                        digit_count  <= (number == 16'd0) ? 4'd1 : 4'd0;
                        sum          <= 16'd0;
                    end
                end

                COUNT_DIGITS: begin
                    if (temp_num != 16'd0) begin
                        temp_num    <= temp_num / 16'd10;
                        digit_count <= digit_count + 4'd1;
                    end
                end

                CALC_POWER: begin
                    // Initialize power calculation for current digit
                    if (state != CALC_POWER) begin
                        // no-op, handled on state entry via NEXT_DIGIT
                    end else begin
                        if (power_cnt == 4'd0) begin
                            power_acc <= 16'd1;
                            power_cnt <= digit_count;
                        end else if (power_cnt != 4'd0) begin
                            power_acc <= power_acc * cur_digit;
                            power_cnt <= power_cnt - 4'd1;
                        end
                    end
                end

                ACCUM_DIGIT: begin
                    sum <= sum + power_acc;
                end

                NEXT_DIGIT: begin
                    work_num <= work_num / 16'd10;
                end

                COMPARE: begin
                    result <= (sum == original_num);
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: ;
            endcase
        end
    end

    // Next state logic and combinational control for transitions
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COUNT_DIGITS;
                end
            end

            COUNT_DIGITS: begin
                if (temp_num == 16'd0) begin
                    // Prepare for digit processing
                    next_state = NEXT_DIGIT;
                end
            end

            NEXT_DIGIT: begin
                // On entry to NEXT_DIGIT, either this is first setup or after finishing a digit
                // If first time after COUNT_DIGITS, work_num is not yet set
                if (work_num == 16'd0) begin
                    // First-time setup
                    if (original_num == 16'd0) begin
                        // Special case 0: single digit 0^1 = 0
                        cur_digit  = 4'd0;
                        power_cnt  = digit_count; // 1
                        power_acc  = 16'd1;
                        next_state = CALC_POWER;
                    end else begin
                        // Initialize work_num and extract first digit
                        cur_digit  = original_num % 16'd10;
                        work_num   = original_num;
                        power_cnt  = digit_count;
                        power_acc  = 16'd1;
                        next_state = CALC_POWER;
                    end
                end else begin
                    // After processing a digit, move to next digit
                    if (work_num == 16'd0) begin
                        next_state = COMPARE;
                    end else begin
                        cur_digit  = work_num % 16'd10;
                        power_cnt  = digit_count;
                        power_acc  = 16'd1;
                        next_state = CALC_POWER;
                    end
                end
            end

            CALC_POWER: begin
                if (power_cnt == 4'd0) begin
                    next_state = ACCUM_DIGIT;
                end else begin
                    next_state = CALC_POWER;
                end
            end

            ACCUM_DIGIT: begin
                next_state = NEXT_DIGIT;
            end

            COMPARE: begin
                next_state = FINISH;
            end

            FINISH: begin
                // Wait for next start pulse while in IDLE after FINISH
                if (start) begin
                    next_state = COUNT_DIGITS;
                end else begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
