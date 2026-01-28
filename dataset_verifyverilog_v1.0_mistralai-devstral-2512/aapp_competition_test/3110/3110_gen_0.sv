module matrix_completion(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] m,
    input wire [3:0] n,
    input wire [7:0] grid [0:5][0:5],
    output reg [15:0] result,
    output reg done,
    output reg found
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INITIALIZE = 3'd1;
    localparam [2:0] VALIDATE_ROW = 3'd2;
    localparam [2:0] VALIDATE_L_RULE = 3'd3;
    localparam [2:0] NEXT_CELL = 3'd4;
    localparam [2:0] COMPLETE = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] current_row, current_col;
    reg [7:0] unknown_count;
    reg [7:0] depth;
    reg [7:0] current_digit;
    reg [7:0] temp_grid [0:5][0:5];
    reg [8:0] row_used [0:5];
    reg [7:0] l_value, r_value, u_value;
    reg [7:0] sum, product, diff, quot1, quot2;
    reg [7:0] i, j;
    reg [7:0] temp_row, temp_col;
    reg [7:0] temp_digit;
    reg [7:0] temp_count;
    reg [7:0] temp_depth;
    reg [7:0] temp_current_digit;
    reg [7:0] temp_unknown_count;
    reg [7:0] temp_current_row, temp_current_col;
    reg [7:0] temp_l_value, temp_r_value, temp_u_value;
    reg [7:0] temp_sum, temp_product, temp_diff, temp_quot1, temp_quot2;
    reg [7:0] temp_i, temp_j;
    reg [7:0] temp_temp_row, temp_temp_col;
    reg [7:0] temp_temp_digit;
    reg [7:0] temp_temp_count;
    reg [7:0] temp_temp_depth;
    reg [7:0] temp_temp_current_digit;
    reg [7:0] temp_temp_unknown_count;
    reg [7:0] temp_temp_current_row, temp_temp_current_col;
    reg [7:0] temp_temp_l_value, temp_temp_r_value, temp_temp_u_value;
    reg [7:0] temp_temp_sum, temp_temp_product, temp_temp_diff, temp_temp_quot1, temp_temp_quot2;
    reg [7:0] temp_temp_i, temp_temp_j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            found <= 1'b0;
            current_row <= 8'd0;
            current_col <= 8'd0;
            unknown_count <= 8'd0;
            depth <= 8'd0;
            current_digit <= 8'd0;
            for (i = 0; i < 6; i = i + 1) begin
                for (j = 0; j < 6; j = j + 1) begin
                    temp_grid[i][j] <= 8'd0;
                end
            end
            for (i = 0; i < 6; i = i + 1) begin
                row_used[i] <= 9'd0;
            end
            l_value <= 8'd0;
            r_value <= 8'd0;
            u_value <= 8'd0;
            sum <= 8'd0;
            product <= 8'd0;
            diff <= 8'd0;
            quot1 <= 8'd0;
            quot2 <= 8'd0;
            temp_row <= 8'd0;
            temp_col <= 8'd0;
            temp_digit <= 8'd0;
            temp_count <= 8'd0;
            temp_depth <= 8'd0;
            temp_current_digit <= 8'd0;
            temp_unknown_count <= 8'd0;
            temp_current_row <= 8'd0;
            temp_current_col <= 8'd0;
            temp_l_value <= 8'd0;
            temp_r_value <= 8'd0;
            temp_u_value <= 8'd0;
            temp_sum <= 8'd0;
            temp_product <= 8'd0;
            temp_diff <= 8'd0;
            temp_quot1 <= 8'd0;
            temp_quot2 <= 8'd0;
            temp_i <= 8'd0;
            temp_j <= 8'd0;
            temp_temp_row <= 8'd0;
            temp_temp_col <= 8'd0;
            temp_temp_digit <= 8'd0;
            temp_temp_count <= 8'd0;
            temp_temp_depth <= 8'd0;
            temp_temp_current_digit <= 8'd0;
            temp_temp_unknown_count <= 8'd0;
            temp_temp_current_row <= 8'd0;
            temp_temp_current_col <= 8'd0;
            temp_temp_l_value <= 8'd0;
            temp_temp_r_value <= 8'd0;
            temp_temp_u_value <= 8'd0;
            temp_temp_sum <= 8'd0;
            temp_temp_product <= 8'd0;
            temp_temp_diff <= 8'd0;
            temp_temp_quot1 <= 8'd0;
            temp_temp_quot2 <= 8'd0;
            temp_temp_i <= 8'd0;
            temp_temp_j <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INITIALIZE;
                end
            end
            INITIALIZE: begin
                next_state = VALIDATE_ROW;
            end
            VALIDATE_ROW: begin
                next_state = VALIDATE_L_RULE;
            end
            VALIDATE_L_RULE: begin
                next_state = NEXT_CELL;
            end
            NEXT_CELL: begin
                next_state = COMPLETE;
            end
            COMPLETE: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    found <= (result > 16'd0);
                end
                default: begin
                    done <= 1'b0;
                    found <= 1'b0;
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
        end else begin
            case (state)
                COMPLETE: begin
                    result <= result + 16'd1;
                end
                default: begin
                    result <= result;
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_row <= 8'd0;
            current_col <= 8'd0;
            unknown_count <= 8'd0;
            depth <= 8'd0;
            current_digit <= 8'd0;
        end else begin
            case (state)
                INITIALIZE: begin
                    for (i = 0; i < 6; i = i + 1) begin
                        for (j = 0; j < 6; j = j + 1) begin
                            temp_grid[i][j] <= grid[i][j];
                        end
                    end
                    for (i = 0; i < 6; i = i + 1) begin
                        row_used[i] <= 9'd0;
                    end
                    for (i = 0; i < 6; i = i + 1) begin
                        for (j = 0; j < 6; j = j + 1) begin
                            if (temp_grid[i][j] != 8'd0) begin
                                row_used[i][temp_grid[i][j] - 8'd1] <= 1'b1;
                            end
                        end
                    end
                    unknown_count <= 8'd0;
                    for (i = 0; i < 6; i = i + 1) begin
                        for (j = 0; j < 6; j = j + 1) begin
                            if (temp_grid[i][j] == 8'd0) begin
                                unknown_count <= unknown_count + 8'd1;
                            end
                        end
                    end
                    current_row <= 8'd0;
                    current_col <= 8'd0;
                    depth <= 8'd0;
                    current_digit <= 8'd1;
                end
                NEXT_CELL: begin
                    if (temp_grid[current_row][current_col] == 8'd0) begin
                        if (current_digit <= 8'd9) begin
                            if (!row_used[current_row][current_digit - 8'd1]) begin
                                temp_grid[current_row][current_col] <= current_digit;
                                row_used[current_row][current_digit - 8'd1] <= 1'b1;
                                depth <= depth + 8'd1;
                                current_digit <= 8'd1;
                                if (current_col == 5) begin
                                    current_row <= current_row + 8'd1;
                                    current_col <= 8'd0;
                                end else begin
                                    current_col <= current_col + 8'd1;
                                end
                            end else begin
                                current_digit <= current_digit + 8'd1;
                            end
                        end else begin
                            temp_grid[current_row][current_col] <= 8'd0;
                            row_used[current_row][current_digit - 8'd1] <= 1'b0;
                            depth <= depth - 8'd1;
                            if (current_col == 0) begin
                                current_row <= current_row - 8'd1;
                                current_col <= 5;
                            end else begin
                                current_col <= current_col - 8'd1;
                            end
                            current_digit <= temp_grid[current_row][current_col] + 8'd1;
                        end
                    end else begin
                        if (current_col == 5) begin
                            current_row <= current_row + 8'd1;
                            current_col <= 8'd0;
                        end else begin
                            current_col <= current_col + 8'd1;
                        end
                    end
                end
                default: begin
                    current_row <= current_row;
                    current_col <= current_col;
                    unknown_count <= unknown_count;
                    depth <= depth;
                    current_digit <= current_digit;
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l_value <= 8'd0;
            r_value <= 8'd0;
            u_value <= 8'd0;
            sum <= 8'd0;
            product <= 8'd0;
            diff <= 8'd0;
            quot1 <= 8'd0;
            quot2 <= 8'd0;
        end else begin
            case (state)
                VALIDATE_L_RULE: begin
                    for (i = 1; i < 6; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            l_value <= temp_grid[i][j];
                            r_value <= temp_grid[i][j + 8'd1];
                            u_value <= temp_grid[i - 8'd1][j];
                            sum <= l_value + r_value;
                            product <= l_value * r_value;
                            diff <= (l_value > r_value) ? (l_value - r_value) : (r_value - l_value);
                            quot1 <= (l_value % r_value == 8'd0) ? (l_value / r_value) : 8'd0;
                            quot2 <= (r_value % l_value == 8'd0) ? (r_value / l_value) : 8'd0;
                            if (u_value != sum && u_value != product && u_value != diff && u_value != quot1 && u_value != quot2) begin
                                next_state <= IDLE;
                            end
                        end
                    end
                end
                default: begin
                    l_value <= l_value;
                    r_value <= r_value;
                    u_value <= u_value;
                    sum <= sum;
                    product <= product;
                    diff <= diff;
                    quot1 <= quot1;
                    quot2 <= quot2;
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_row <= 8'd0;
            temp_col <= 8'd0;
            temp_digit <= 8'd0;
            temp_count <= 8'd0;
            temp_depth <= 8'd0;
            temp_current_digit <= 8'd0;
            temp_unknown_count <= 8'd0;
            temp_current_row <= 8'd0;
            temp_current_col <= 8'd0;
            temp_l_value <= 8'd0;
            temp_r_value <= 8'd0;
            temp_u_value <= 8'd0;
            temp_sum <= 8'd0;
            temp_product <= 8'd0;
            temp_diff <= 8'd0;
            temp_quot1 <= 8'd0;
            temp_quot2 <= 8'd0;
            temp_i <= 8'd0;
            temp_j <= 8'd0;
            temp_temp_row <= 8'd0;
            temp_temp_col <= 8'd0;
            temp_temp_digit <= 8'd0;
            temp_temp_count <= 8'd0;
            temp_temp_depth <= 8'd0;
            temp_temp_current_digit <= 8'd0;
            temp_temp_unknown_count <= 8'd0;
            temp_temp_current_row <= 8'd0;
            temp_temp_current_col <= 8'd0;
            temp_temp_l_value <= 8'd0;
            temp_temp_r_value <= 8'd0;
            temp_temp_u_value <= 8'd0;
            temp_temp_sum <= 8'd0;
            temp_temp_product <= 8'd0;
            temp_temp_diff <= 8'd0;
            temp_temp_quot1 <= 8'd0;
            temp_temp_quot2 <= 8'd0;
            temp_temp_i <= 8'd0;
            temp_temp_j <= 8'd0;
        end else begin
            temp_row <= current_row;
            temp_col <= current_col;
            temp_digit <= current_digit;
            temp_count <= unknown_count;
            temp_depth <= depth;
            temp_current_digit <= current_digit;
            temp_unknown_count <= unknown_count;
            temp_current_row <= current_row;
            temp_current_col <= current_col;
            temp_l_value <= l_value;
            temp_r_value <= r_value;
            temp_u_value <= u_value;
            temp_sum <= sum;
            temp_product <= product;
            temp_diff <= diff;
            temp_quot1 <= quot1;
            temp_quot2 <= quot2;
            temp_i <= i;
            temp_j <= j;
            temp_temp_row <= temp_row;
            temp_temp_col <= temp_col;
            temp_temp_digit <= temp_digit;
            temp_temp_count <= temp_count;
            temp_temp_depth <= temp_depth;
            temp_temp_current_digit <= temp_current_digit;
            temp_temp_unknown_count <= temp_unknown_count;
            temp_temp_current_row <= temp_current_row;
            temp_temp_current_col <= temp_current_col;
            temp_temp_l_value <= temp_l_value;
            temp_temp_r_value <= temp_r_value;
            temp_temp_u_value <= temp_u_value;
            temp_temp_sum <= temp_sum;
            temp_temp_product <= temp_product;
            temp_temp_diff <= temp_diff;
            temp_temp_quot1 <= temp_quot1;
            temp_temp_quot2 <= temp_quot2;
            temp_temp_i <= temp_i;
            temp_temp_j <= temp_j;
        end
    end

endmodule