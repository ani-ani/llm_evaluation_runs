module multi_int_concat(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [3:0][7:0] nums,
    output logic [31:0] result,
    output logic        done
);

    // State encoding
    typedef enum logic [1:0] {
        IDLE           = 2'b00,
        PROCESS_NUM    = 2'b01,
        CONVERT_DIGITS = 2'b10,
        FINISH         = 2'b11
    } state_t;

    state_t state, next_state;

    // Internal registers
    logic [1:0]  num_index;          // 0..3 for nums index
    logic [7:0]  cur_num_raw;        // current raw 8-bit signed
    logic        overall_sign;       // 1 if result negative (from first number only)
    logic [7:0]  cur_abs;            // absolute value of current number (0..128)
    logic [7:0]  tmp_val;            // mutable copy for digit extraction
    logic [3:0]  digit_cnt;          // number of digits remaining to emit for current number
    logic [63:0] accum;              // accumulation of digits as they are concatenated
    logic [5:0]  total_digits;       // count of total digits appended so far
    logic        start_latched;

    // Sign-extended view of nums for signed operations
    function automatic signed [7:0] as_signed(input logic [7:0] x);
        as_signed = signed'(x);
    endfunction

    // Compute absolute (8-bit, handling -128 safely by saturating to 128)
    function automatic [7:0] abs8(input signed [7:0] x);
        if (x[7] == 1'b1) begin
            // negative
            if (x == -128) abs8 = 8'd128; // special case
            else abs8 = -x;
        end else begin
            abs8 = x;
        end
    endfunction

    // Digit count for up to 3 digits for 0..255 (or 128 special)
    function automatic [3:0] digit_count(input [7:0] val);
        if (val >= 8'd100)      digit_count = 4'd3;
        else if (val >= 8'd10)  digit_count = 4'd2;
        else                    digit_count = 4'd1;
    endfunction

    // Next-state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_latched)
                    next_state = PROCESS_NUM;
            end
            PROCESS_NUM: begin
                next_state = CONVERT_DIGITS;
            end
            CONVERT_DIGITS: begin
                if (digit_cnt == 0) begin
                    if (num_index == 2'd3)
                        next_state = FINISH;
                    else
                        next_state = PROCESS_NUM;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Latch start pulse (1-cycle responsiveness; simple edge-safe scheme)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_latched <= 1'b0;
        end else begin
            if (state == IDLE)
                start_latched <= start;
            else if (state != IDLE)
                start_latched <= 1'b0;
        end
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            num_index    <= 2'd0;
            overall_sign <= 1'b0;
            cur_abs      <= 8'd0;
            tmp_val      <= 8'd0;
            digit_cnt    <= 4'd0;
            accum        <= 64'd0;
            total_digits <= 6'd0;
            result       <= 32'd0;
            done         <= 1'b0;
        end else begin
            state <= next_state;
            done  <= 1'b0;

            case (state)
                IDLE: begin
                    if (start_latched) begin
                        // Initialization for new operation
                        num_index    <= 2'd0;
                        accum        <= 64'd0;
                        total_digits <= 6'd0;

                        // Determine overall sign from first number only
                        if (as_signed(nums[0])[7])
                            overall_sign <= 1'b1;
                        else
                            overall_sign <= 1'b0;
                    end
                end

                PROCESS_NUM: begin
                    // Load current number
                    cur_num_raw <= nums[num_index];

                    // Absolute value handling
                    if (num_index == 2'd0) begin
                        // First number: sign already captured; use absolute value
                        cur_abs <= abs8(as_signed(nums[0]));
                    end else begin
                        // Subsequent numbers: ignore sign, use absolute value
                        cur_abs <= abs8(as_signed(nums[num_index]));
                    end

                    // Prepare digit extraction: compute digit count and init tmp_val
                    tmp_val   <= cur_abs;
                    digit_cnt <= digit_count(cur_abs);
                end

                CONVERT_DIGITS: begin
                    if (digit_cnt != 0) begin
                        // Extract next most significant digit for 0..255
                        logic [3:0] digit;
                        logic [7:0] val_next;

                        if (digit_cnt == 4'd3) begin
                            // Hundreds digit
                            digit    = tmp_val / 8'd100;
                            val_next = tmp_val % 8'd100;
                        end else if (digit_cnt == 4'd2) begin
                            // Tens digit
                            digit    = tmp_val / 8'd10;
                            val_next = tmp_val % 8'd10;
                        end else begin
                            // Ones digit
                            digit    = tmp_val[3:0];
                            val_next = 8'd0;
                        end

                        // Append digit to accumulation
                        accum        <= accum * 10 + digit;
                        total_digits <= total_digits + 1'b1;

                        // Update for next digit
                        tmp_val   <= val_next;
                        digit_cnt <= digit_cnt - 1'b1;
                    end

                    // When digit_cnt hits 0, state machine transitions in next cycle
                end

                FINISH: begin
                    // Apply overall sign from first number
                    if (overall_sign) begin
                        // Cap to 32-bit signed (two's complement)
                        result <= -$signed(accum[31:0]);
                    end else begin
                        result <= accum[31:0];
                    end
                    done      <= 1'b1;

                    // Prepare for potential next start
                    num_index    <= 2'd0;
                    total_digits <= 6'd0;
                    accum        <= 64'd0;
                end
            endcase

            // Advance num_index when leaving CONVERT_DIGITS and digits done
            if (state == CONVERT_DIGITS && digit_cnt == 0 && next_state == PROCESS_NUM) begin
                num_index <= num_index + 2'd1;
            end
        end
    end

endmodule