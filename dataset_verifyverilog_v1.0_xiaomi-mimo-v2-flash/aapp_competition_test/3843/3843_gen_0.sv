module HourMinutePairs (
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    input [31:0] m,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CALC_DIGITS = 4'd1;
    localparam [3:0] CHECK_DIGITS = 4'd2;
    localparam [3:0] INIT_PERM = 4'd3;
    localparam [3:0] PERM_LOOP = 4'd4;
    localparam [3:0] EXTRACT_DIGITS = 4'd5;
    localparam [3:0] CONVERT_HOURS = 4'd6;
    localparam [3:0] CONVERT_MINUTES = 4'd7;
    localparam [3:0] CHECK_VALID = 4'd8;
    localparam [3:0] INCREMENT = 4'd9;
    localparam [3:0] DONE_STATE = 4'd10;

    // Registers and wires
    reg [3:0] state, next_state;
    reg [31:0] n_reg, m_reg;
    reg [3:0] dh, dm;
    reg [3:0] dh_m1, dm_m1;
    reg [2:0] perm_digits [6:0];  // Up to 7 digits in permutation
    reg [2:0] used_digits [6:0];   // Track used digits
    reg [2:0] hours_digits [6:0];  // First dh digits
    reg [2:0] minutes_digits [6:0]; // Last dm digits
    reg [2:0] current_digit;
    reg [2:0] pos;
    reg [31:0] hours_value;
    reg [31:0] minutes_value;
    reg [15:0] valid_count;
    reg [2:0] digit_idx;
    reg [31:0] power_of_7;
    reg [31:0] temp_value;
    reg valid_h, valid_m;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 32'd0;
            m_reg <= 32'd0;
            dh <= 4'd0;
            dm <= 4'd0;
            dh_m1 <= 4'd0;
            dm_m1 <= 4'd0;
            current_digit <= 3'd0;
            pos <= 3'd0;
            hours_value <= 32'd0;
            minutes_value <= 32'd0;
            valid_count <= 16'd0;
            digit_idx <= 3'd0;
            power_of_7 <= 32'd0;
            temp_value <= 32'd0;
            valid_h <= 1'b0;
            valid_m <= 1'b0;
            cycle_count <= 4'd0;
            // Initialize arrays
            for (integer i = 0; i < 7; i = i + 1) begin
                perm_digits[i] <= 3'd0;
                used_digits[i] <= 3'd0;
                hours_digits[i] <= 3'd0;
                minutes_digits[i] <= 3'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= n;
                        m_reg <= m;
                        valid_count <= 16'd0;
                    end
                end
                
                CALC_DIGITS: begin
                    dh <= 4'd0;
                    dm <= 4'd0;
                    if (n_reg > 32'd1) begin
                        dh_m1 <= 4'd0;
                    end
                    if (m_reg > 32'd1) begin
                        dm_m1 <= 4'd0;
                    end
                end
                
                CHECK_DIGITS: begin
                    // dh and dm calculated here
                end
                
                INIT_PERM: begin
                    pos <= 3'd0;
                    for (integer i = 0; i < 7; i = i + 1) begin
                        used_digits[i] <= 3'd0;
                    end
                end
                
                PERM_LOOP: begin
                    // Generate permutation
                    if (pos < (dh + dm)) begin
                        // Find next unused digit
                        if (current_digit < 7) begin
                            current_digit <= current_digit + 3'd1;
                        end
                    end
                end
                
                EXTRACT_DIGITS: begin
                    // Extract hours and minutes digits
                end
                
                CONVERT_HOURS: begin
                    // Convert hours digits to number
                    if (digit_idx < dh) begin
                        temp_value <= temp_value * 32'd7 + {29'd0, hours_digits[digit_idx]};
                        digit_idx <= digit_idx + 3'd1;
                    end
                end
                
                CONVERT_MINUTES: begin
                    // Convert minutes digits to number
                    if (digit_idx < (dh + dm)) begin
                        temp_value <= temp_value * 32'd7 + {29'd0, minutes_digits[digit_idx - dh]};
                        digit_idx <= digit_idx + 3'd1;
                    end
                end
                
                CHECK_VALID: begin
                    if (hours_value < n_reg && minutes_value < m_reg) begin
                        valid_count <= valid_count + 16'd1;
                    end
                end
                
                INCREMENT: begin
                    // Prepare for next permutation or finish
                end
                
                DONE_STATE: begin
                    result <= valid_count;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CALC_DIGITS;
            end
            
            CALC_DIGITS: begin
                next_state = CHECK_DIGITS;
            end
            
            CHECK_DIGITS: begin
                // Calculate dh and dm
                if (dh_m1 > 4'd7 || dm_m1 > 4'd7 || (dh_m1 + dm_m1) > 4'd7) begin
                    next_state = DONE_STATE;
                end else if (dh_m1 == 4'd0 && n_reg > 32'd1) begin
                    next_state = CALC_DIGITS;
                end else if (dm_m1 == 4'd0 && m_reg > 32'd1) begin
                    next_state = CALC_DIGITS;
                end else begin
                    next_state = INIT_PERM;
                end
            end
            
            INIT_PERM: begin
                if ((dh_m1 + dm_m1) == 4'd0) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PERM_LOOP;
                end
            end
            
            PERM_LOOP: begin
                if (current_digit < 7 && current_digit < (pos + 3'd1)) begin
                    next_state = PERM_LOOP;
                end else if (current_digit < 7 && used_digits[current_digit] == 3'd0) begin
                    next_state = PERM_LOOP;
                end else begin
                    next_state = EXTRACT_DIGITS;
                end
            end
            
            EXTRACT_DIGITS: begin
                next_state = CONVERT_HOURS;
            end
            
            CONVERT_HOURS: begin
                if (digit_idx < dh_m1) begin
                    next_state = CONVERT_HOURS;
                end else begin
                    next_state = CONVERT_MINUTES;
                end
            end
            
            CONVERT_MINUTES: begin
                if (digit_idx < (dh_m1 + dm_m1)) begin
                    next_state = CONVERT_MINUTES;
                end else begin
                    next_state = CHECK_VALID;
                end
            end
            
            CHECK_VALID: begin
                next_state = INCREMENT;
            end
            
            INCREMENT: begin
                if (pos < (dh_m1 + dm_m1) - 1) begin
                    next_state = PERM_LOOP;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Separate always block for digit calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dh_m1 <= 4'd0;
            dm_m1 <= 4'd0;
            dh <= 4'd0;
            dm <= 4'd0;
        end else if (state == CALC_DIGITS) begin
            // Calculate dh_m1 and dm_m1 (log base 7)
            if (n_reg > 32'd1) begin
                if (n_reg <= 32'd7) dh_m1 <= 4'd1;
                else if (n_reg <= 32'd49) dh_m1 <= 4'd2;
                else if (n_reg <= 32'd343) dh_m1 <= 4'd3;
                else if (n_reg <= 32'd2401) dh_m1 <= 4'd4;
                else if (n_reg <= 32'd16807) dh_m1 <= 4'd5;
                else if (n_reg <= 32'd117649) dh_m1 <= 4'd6;
                else dh_m1 <= 4'd7;
            end else begin
                dh_m1 <= 4'd0;
            end
            
            if (m_reg > 32'd1) begin
                if (m_reg <= 32'd7) dm_m1 <= 4'd1;
                else if (m_reg <= 32'd49) dm_m1 <= 4'd2;
                else if (m_reg <= 32'd343) dm_m1 <= 4'd3;
                else if (m_reg <= 32'd2401) dm_m1 <= 4'd4;
                else if (m_reg <= 32'd16807) dm_m1 <= 4'd5;
                else if (m_reg <= 32'd117649) dm_m1 <= 4'd6;
                else dm_m1 <= 4'd7;
            end else begin
                dm_m1 <= 4'd0;
            end
        end
    end

    // Permutation generation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_digit <= 3'd0;
            pos <= 3'd0;
            // Reset arrays
            for (integer i = 0; i < 7; i = i + 1) begin
                perm_digits[i] <= 3'd0;
                used_digits[i] <= 3'd0;
            end
        end else if (state == INIT_PERM) begin
            pos <= 3'd0;
            current_digit <= 3'd0;
            for (integer i = 0; i < 7; i = i + 1) begin
                used_digits[i] <= 3'd0;
            end
        end else if (state == PERM_LOOP) begin
            if (current_digit < 7 && used_digits[current_digit] == 3'd0) begin
                // Found next unused digit
                perm_digits[pos] <= current_digit;
                used_digits[current_digit] <= 3'd1;
                pos <= pos + 3'd1;
                current_digit <= 3'd0;
            end else if (current_digit < 7) begin
                current_digit <= current_digit + 3'd1;
            end else begin
                // Backtrack
                if (pos > 3'd0) begin
                    pos <= pos - 3'd1;
                    current_digit <= perm_digits[pos - 3'd1] + 3'd1;
                    used_digits[perm_digits[pos - 3'd1]] <= 3'd0;
                end
            end
        end
    end

    // Digit extraction and conversion
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_idx <= 3'd0;
            hours_value <= 32'd0;
            minutes_value <= 32'd0;
            for (integer i = 0; i < 7; i = i + 1) begin
                hours_digits[i] <= 3'd0;
                minutes_digits[i] <= 3'd0;
            end
        end else if (state == EXTRACT_DIGITS) begin
            // Extract hours digits
            for (integer i = 0; i < 7; i = i + 1) begin
                if (i < dh_m1) begin
                    hours_digits[i] <= perm_digits[i];
                end else begin
                    hours_digits[i] <= 3'd0;
                end
            end
            // Extract minutes digits
            for (integer j = 0; j < 7; j = j + 1) begin
                if (j < dm_m1 && (j + dh_m1) < 7) begin
                    minutes_digits[j] <= perm_digits[j + dh_m1];
                end else begin
                    minutes_digits[j] <= 3'd0;
                end
            end
            digit_idx <= 3'd0;
            hours_value <= 32'd0;
            minutes_value <= 32'd0;
        end else if (state == CONVERT_HOURS) begin
            if (digit_idx < dh_m1) begin
                hours_value <= hours_value * 32'd7 + {29'd0, hours_digits[digit_idx]};
                digit_idx <= digit_idx + 3'd1;
            end
        end else if (state == CONVERT_MINUTES) begin
            if (digit_idx < (dh_m1 + dm_m1)) begin
                minutes_value <= minutes_value * 32'd7 + {29'd0, minutes_digits[digit_idx - dh_m1]};
                digit_idx <= digit_idx + 3'd1;
            end
        end
    end

endmodule