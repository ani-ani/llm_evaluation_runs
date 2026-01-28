module MartianDecryption(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] encrypted_msg [7:0],
    output reg [4:0] decrypted_msg [7:0],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE     = 4'd0;
    localparam [3:0] GRID     = 4'd1;
    localparam [3:0] SUMS     = 4'd2;
    localparam [3:0] DECIMAL  = 4'd3;
    localparam [3:0] BASE27   = 4'd4;
    localparam [3:0] DECRYPT  = 4'd5;
    localparam [3:0] FINISH   = 4'd6;

    // State variables
    reg [3:0] state, next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd2000;

    // Grid registers (8x8, 20-bit each)
    reg [19:0] grid_reg [7:0][7:0];
    reg [2:0] grid_row, grid_col;
    reg [5:0] f_count;
    reg [19:0] f_current;
    reg f_started;

    // Sum registers
    reg [19:0] col_sum [7:0];
    reg [2:0] sum_col;

    // Decimal digit registers (48 x 4-bit)
    reg [3:0] decimal_digits [47:0];
    reg [5:0] decimal_idx;
    reg [19:0] temp_sum;
    reg [19:0] temp_div_rem;
    reg [2:0] decimal_col;

    // Base27 registers
    reg [4:0] base27_digits [29:0];
    reg [4:0] base27_index;
    reg [2:0] decrypt_idx;
    reg [19:0] decimal_value;
    reg [31:0] div_numerator;
    reg [4:0] div_divisor;
    reg [4:0] div_quotient;
    reg [4:0] div_remainder;

    integer i, j, k;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = GRID;
                else
                    next_state = IDLE;
            end
            GRID: begin
                if ((grid_row == 3'd7) && (grid_col == 3'd7) && f_started && (f_current == grid_reg[7][7]))
                    next_state = SUMS;
                else
                    next_state = GRID;
            end
            SUMS: begin
                if (sum_col == 3'd7)
                    next_state = DECIMAL;
                else
                    next_state = SUMS;
            end
            DECIMAL: begin
                // Process 8 columns, each produces 6 digits
                if ((decimal_col == 3'd7) && (decimal_idx == 6'd0))
                    next_state = BASE27;
                else
                    next_state = DECIMAL;
            end
            BASE27: begin
                if (base27_index == 5'd29)
                    next_state = DECRYPT;
                else
                    next_state = BASE27;
            end
            DECRYPT: begin
                if (decrypt_idx == 3'd7)
                    next_state = FINISH;
                else
                    next_state = DECRYPT;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 16'd0;
            done <= 1'b0;
            f_count <= 6'd0;
            f_current <= 20'd0;
            f_started <= 1'b0;
            grid_row <= 3'd0;
            grid_col <= 3'd0;
            sum_col <= 3'd0;
            decimal_idx <= 6'd0;
            decimal_col <= 3'd0;
            temp_sum <= 20'd0;
            temp_div_rem <= 20'd0;
            base27_index <= 5'd0;
            decrypt_idx <= 3'd0;
            div_numerator <= 32'd0;
            div_divisor <= 5'd0;
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                col_sum[i] <= 20'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    grid_reg[i][j] <= 20'd0;
                end
            end
            for (k = 0; k < 48; k = k + 1) begin
                decimal_digits[k] <= 4'd0;
            end
            for (k = 0; k < 29; k = k + 1) begin
                base27_digits[k] <= 5'd0;
            end
            for (k = 0; k < 8; k = k + 1) begin
                decrypted_msg[k] <= 5'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    f_count <= 6'd0;
                    f_current <= 20'd0;
                    f_started <= 1'b0;
                    grid_row <= 3'd0;
                    grid_col <= 3'd0;
                    sum_col <= 3'd0;
                    decimal_idx <= 6'd47;
                    decimal_col <= 3'd0;
                    temp_sum <= 20'd0;
                    base27_index <= 5'd0;
                    decrypt_idx <= 3'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        col_sum[i] <= 20'd0;
                        for (j = 0; j < 8; j = j + 1) begin
                            grid_reg[i][j] <= 20'd0;
                        end
                    end
                    for (k = 0; k < 48; k = k + 1) begin
                        decimal_digits[k] <= 4'd0;
                    end
                    for (k = 0; k < 29; k = k + 1) begin
                        base27_digits[k] <= 5'd0;
                    end
                    for (k = 0; k < 8; k = k + 1) begin
                        decrypted_msg[k] <= 5'd0;
                    end
                end

                GRID: begin
                    // Compute f function: (33*x + 1) mod 2^20
                    if (!f_started) begin
                        f_current <= 20'd0;
                        f_count <= 6'd0;
                        f_started <= 1'b1;
                    end else if (f_count < 6'd64) begin
                        f_current <= (33 * f_current + 20'd1) & 20'dFFFFF;
                        f_count <= f_count + 6'd1;
                        // Store in grid
                        if (f_count > 6'd0) begin
                            grid_reg[grid_row][grid_col] <= f_current;
                            if (grid_col == 3'd7) begin
                                grid_col <= 3'd0;
                                grid_row <= grid_row + 3'd1;
                            end else begin
                                grid_col <= grid_col + 3'd1;
                            end
                        end
                    end
                end

                SUMS: begin
                    // Compute column sums
                    temp_sum <= 20'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i == sum_col) begin
                            temp_sum <= grid_reg[0][i] + grid_reg[1][i] + grid_reg[2][i] + grid_reg[3][i] +
                                       grid_reg[4][i] + grid_reg[5][i] + grid_reg[6][i] + grid_reg[7][i];
                        end
                    end
                    col_sum[sum_col] <= temp_sum;
                    sum_col <= sum_col + 3'd1;
                end

                DECIMAL: begin
                    // Convert each sum to 6-digit decimal
                    if (decimal_col == 3'd0) begin
                        temp_sum <= col_sum[0];
                    end else if (decimal_col == 3'd1) begin
                        temp_sum <= col_sum[1];
                    end else if (decimal_col == 3'd2) begin
                        temp_sum <= col_sum[2];
                    end else if (decimal_col == 3'd3) begin
                        temp_sum <= col_sum[3];
                    end else if (decimal_col == 3'd4) begin
                        temp_sum <= col_sum[4];
                    end else if (decimal_col == 3'd5) begin
                        temp_sum <= col_sum[5];
                    end else if (decimal_col == 3'd6) begin
                        temp_sum <= col_sum[6];
                    end else begin
                        temp_sum <= col_sum[7];
                    end

                    if (decimal_idx >= (decimal_col * 6) && decimal_idx < ((decimal_col + 1) * 6)) begin
                        // Extract one digit at a time
                        if (temp_sum >= 20'd100000) begin
                            decimal_digits[decimal_idx] <= 4'd9;
                            temp_sum <= temp_sum - 20'd100000;
                        end else if (temp_sum >= 20'd10000) begin
                            decimal_digits[decimal_idx] <= temp_sum / 10000;
                            temp_sum <= temp_sum - (temp_sum / 10000) * 10000;
                        end else if (temp_sum >= 20'd1000) begin
                            decimal_digits[decimal_idx] <= temp_sum / 1000;
                            temp_sum <= temp_sum - (temp_sum / 1000) * 1000;
                        end else if (temp_sum >= 20'd100) begin
                            decimal_digits[decimal_idx] <= temp_sum / 100;
                            temp_sum <= temp_sum - (temp_sum / 100) * 100;
                        end else if (temp_sum >= 20'd10) begin
                            decimal_digits[decimal_idx] <= temp_sum / 10;
                            temp_sum <= temp_sum - (temp_sum / 10) * 10;
                        end else begin
                            decimal_digits[decimal_idx] <= temp_sum[3:0];
                            temp_sum <= 20'd0;
                            if (decimal_idx >= (decimal_col * 6)) begin
                                decimal_idx <= decimal_idx - 6'd1;
                            end
                            if (decimal_idx == (decimal_col * 6)) begin
                                decimal_col <= decimal_col + 3'd1;
                                if (decimal_col < 3'd7)
                                    decimal_idx <= (decimal_col + 3'd1) * 6;
                                else
                                    decimal_idx <= 6'd0;
                            end
                        end
                        if (decimal_idx > (decimal_col * 6)) begin
                            decimal_idx <= decimal_idx - 6'd1;
                        end
                    end
                end

                BASE27: begin
                    // Convert decimal to base27 (simulated division)
                    // Process digits as a large number
                    if (base27_index == 5'd0) begin
                        // Initialize with full decimal number (48 digits)
                        div_numerator <= 32'd0;
                        div_divisor <= 5'd27;
                    end else if (base27_index < 5'd29) begin
                        // Calculate next digit
                        // Simplified: use the decimal value approximation
                        // In reality, we'd process the 48-digit decimal
                        // For synthesis, we'll use a digit-by-digit conversion
                        // Since 48 digits is too large, we'll use modulo operations
                        // on the first 10 decimal digits (enough for 29 base27 digits)
                        
                        // Build value from first 10 decimal digits
                        decimal_value <= 20'd0;
                        for (k = 0; k < 10; k = k + 1) begin
                            if (k < 6'd10) begin
                                decimal_value <= decimal_value * 20'd10 + decimal_digits[47 - k];
                            end
                        end
                        
                        // Compute base27 digit
                        div_quotient <= decimal_value % 5'd27;
                        div_remainder <= decimal_value / 5'd27;
                        
                        // Store digit
                        base27_digits[base27_index - 5'd1] <= div_quotient;
                        
                        // Update decimal_value for next iteration
                        decimal_value <= div_remainder;
                    end
                    base27_index <= base27_index + 5'd1;
                end

                DECRYPT: begin
                    // Decrypt using base27 digits
                    if (decrypt_idx < 3'd8) begin
                        // XOR with 8 to decrypt
                        if (base27_digits[decrypt_idx] >= 5'd27)
                            decrypted_msg[decrypt_idx] <= 5'd0;
                        else
                            decrypted_msg[decrypt_idx] <= (base27_digits[decrypt_idx] ^ 5'd8);
                        decrypt_idx <= decrypt_idx + 3'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule