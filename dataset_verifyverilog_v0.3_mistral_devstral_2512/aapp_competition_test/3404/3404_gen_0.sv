module MartianDecryption(
    input clk,
    input rst_n,
    input start,
    input [7:0][4:0] encrypted_msg,
    output reg [7:0][4:0] decrypted_msg,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] GRID    = 3'd1;
    localparam [2:0] SUMS    = 3'd2;
    localparam [2:0] DECIMAL = 3'd3;
    localparam [2:0] BASE27  = 3'd4;
    localparam [2:0] DECRYPT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state;
    reg [19:0] grid [0:7][0:7];
    reg [19:0] col_sums [0:7];
    reg [3:0] decimal_digits [0:5][0:7];
    reg [4:0] base27_digits [0:28];
    reg [7:0] grid_row;
    reg [7:0] grid_col;
    reg [7:0] sum_idx;
    reg [7:0] decimal_row;
    reg [7:0] decimal_col;
    reg [7:0] base27_idx;
    reg [7:0] decrypt_idx;
    reg [19:0] current_value;
    reg [19:0] temp_value;
    reg [19:0] remainder;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            grid_row <= 8'd0;
            grid_col <= 8'd0;
            sum_idx <= 8'd0;
            decimal_row <= 8'd0;
            decimal_col <= 8'd0;
            base27_idx <= 8'd0;
            decrypt_idx <= 8'd0;
            current_value <= 20'd0;
            temp_value <= 20'd0;
            remainder <= 20'd0;
            
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    grid[i][j] <= 20'd0;
                end
            end
            
            for (i = 0; i < 8; i = i + 1) begin
                col_sums[i] <= 20'd0;
            end
            
            for (i = 0; i < 6; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    decimal_digits[i][j] <= 4'd0;
                end
            end
            
            for (i = 0; i < 29; i = i + 1) begin
                base27_digits[i] <= 5'd0;
            end
            
            for (i = 0; i < 8; i = i + 1) begin
                decrypted_msg[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= GRID;
                        grid_row <= 8'd0;
                        grid_col <= 8'd0;
                        current_value <= 20'd0;
                    end
                end

                GRID: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute f(x) = (33*x + 1) mod 2^20
                    temp_value <= (current_value * 20'd33 + 20'd1) % 20'd1048576;
                    grid[grid_row][grid_col] <= temp_value;
                    current_value <= temp_value;
                    
                    // Move to next grid position
                    if (grid_col == 7) begin
                        if (grid_row == 7) begin
                            state <= SUMS;
                            sum_idx <= 8'd0;
                        end else begin
                            grid_row <= grid_row + 8'd1;
                            grid_col <= 8'd0;
                        end
                    end else begin
                        grid_col <= grid_col + 8'd1;
                    end
                end

                SUMS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute column sums
                    col_sums[sum_idx] <= 20'd0;
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        col_sums[sum_idx] <= col_sums[sum_idx] + grid[i][sum_idx];
                    end
                    col_sums[sum_idx] <= col_sums[sum_idx] % 20'd1048576;
                    
                    // Move to next column
                    if (sum_idx == 7) begin
                        state <= DECIMAL;
                        decimal_row <= 8'd0;
                        decimal_col <= 8'd0;
                    end else begin
                        sum_idx <= sum_idx + 8'd1;
                    end
                end

                DECIMAL: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Convert column sum to 6-digit decimal
                    temp_value <= col_sums[decimal_col];
                    
                    // Extract digit (5 downto 0)
                    if (decimal_row == 0) begin
                        decimal_digits[decimal_row][decimal_col] <= temp_value / 20'd100000;
                    end else if (decimal_row == 1) begin
                        decimal_digits[decimal_row][decimal_col] <= (temp_value % 20'd100000) / 20'd10000;
                    end else if (decimal_row == 2) begin
                        decimal_digits[decimal_row][decimal_col] <= (temp_value % 20'd10000) / 20'd1000;
                    end else if (decimal_row == 3) begin
                        decimal_digits[decimal_row][decimal_col] <= (temp_value % 20'd1000) / 20'd100;
                    end else if (decimal_row == 4) begin
                        decimal_digits[decimal_row][decimal_col] <= (temp_value % 20'd100) / 20'd10;
                    end else if (decimal_row == 5) begin
                        decimal_digits[decimal_row][decimal_col] <= temp_value % 20'd10;
                    end
                    
                    // Move to next digit
                    if (decimal_row == 5) begin
                        if (decimal_col == 7) begin
                            state <= BASE27;
                            base27_idx <= 8'd0;
                            current_value <= 20'd0;
                        end else begin
                            decimal_col <= decimal_col + 8'd1;
                            decimal_row <= 8'd0;
                        end
                    end else begin
                        decimal_row <= decimal_row + 8'd1;
                    end
                end

                BASE27: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Convert 48-digit decimal to base-27
                    // First, convert decimal digits to a single number
                    if (base27_idx == 0) begin
                        integer i, j;
                        for (i = 0; i < 6; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                current_value <= current_value * 20'd10 + decimal_digits[i][j];
                            end
                        end
                    end
                    
                    // Convert to base-27
                    if (current_value == 20'd0) begin
                        base27_digits[base27_idx] <= 5'd0;
                    end else begin
                        remainder <= current_value % 20'd27;
                        base27_digits[base27_idx] <= remainder;
                        current_value <= current_value / 20'd27;
                    end
                    
                    // Move to next digit
                    if (base27_idx == 28 || current_value == 20'd0) begin
                        state <= DECRYPT;
                        decrypt_idx <= 8'd0;
                    end else begin
                        base27_idx <= base27_idx + 8'd1;
                    end
                end

                DECRYPT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Decrypt using first 8 base-27 digits
                    decrypted_msg[decrypt_idx] <= base27_digits[decrypt_idx];
                    
                    // Move to next character
                    if (decrypt_idx == 7) begin
                        state <= DONE_STATE;
                    end else begin
                        decrypt_idx <= decrypt_idx + 8'd1;
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
endmodule