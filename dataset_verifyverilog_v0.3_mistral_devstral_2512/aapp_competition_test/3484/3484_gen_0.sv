module LatinSquareSolver (
    input clk,
    input rst_n,
    input start,
    input [1:0] k,
    input [3:0] in_row0_0, in_row0_1, in_row0_2, in_row0_3,
    input [3:0] in_row1_0, in_row1_1, in_row1_2, in_row1_3,
    input [3:0] in_row2_0, in_row2_1, in_row2_2, in_row2_3,
    input [3:0] in_row3_0, in_row3_1, in_row3_2, in_row3_3,
    output reg done,
    output reg yes,
    output reg [3:0] result_0_0, result_0_1, result_0_2, result_0_3,
    output reg [3:0] result_1_0, result_1_1, result_1_2, result_1_3,
    output reg [3:0] result_2_0, result_2_1, result_2_2, result_2_3,
    output reg [3:0] result_3_0, result_3_1, result_3_2, result_3_3
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] VALIDATE = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] PLACE = 3'd3;
    localparam [2:0] BACKTRACK = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Internal registers
    reg [3:0] grid [0:3][0:3];
    reg [2:0] next_try [0:3][0:3];
    reg [2:0] state;
    reg [2:0] current_row;
    reg [2:0] current_col;
    reg [3:0] check_val;
    reg [2:0] val_row, val_col;
    reg [3:0] col_used [0:3];

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            yes <= 1'b0;
            state <= IDLE;
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    grid[i][j] <= 4'd0;
                    next_try[i][j] <= 3'd0;
                end
            end
            result_0_0 <= 4'd0; result_0_1 <= 4'd0; result_0_2 <= 4'd0; result_0_3 <= 4'd0;
            result_1_0 <= 4'd0; result_1_1 <= 4'd0; result_1_2 <= 4'd0; result_1_3 <= 4'd0;
            result_2_0 <= 4'd0; result_2_1 <= 4'd0; result_2_2 <= 4'd0; result_2_3 <= 4'd0;
            result_3_0 <= 4'd0; result_3_1 <= 4'd0; result_3_2 <= 4'd0; result_3_3 <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    yes <= 1'b0;
                    if (start) begin
                        grid[0][0] <= in_row0_0; grid[0][1] <= in_row0_1; grid[0][2] <= in_row0_2; grid[0][3] <= in_row0_3;
                        grid[1][0] <= in_row1_0; grid[1][1] <= in_row1_1; grid[1][2] <= in_row1_2; grid[1][3] <= in_row1_3;
                        grid[2][0] <= in_row2_0; grid[2][1] <= in_row2_1; grid[2][2] <= in_row2_2; grid[2][3] <= in_row2_3;
                        grid[3][0] <= in_row3_0; grid[3][1] <= in_row3_1; grid[3][2] <= in_row3_2; grid[3][3] <= in_row3_3;
                        for (i = 0; i < 4; i = i + 1) begin
                            for (j = 0; j < 4; j = j + 1) begin
                                if (i < k) next_try[i][j] <= 3'd5;
                                else next_try[i][j] <= 3'd1;
                            end
                        end
                        state <= VALIDATE;
                        val_row <= 3'd0;
                        val_col <= 3'd0;
                    end
                end

                VALIDATE: begin
                    if (val_row < k) begin
                        if (grid[val_row][0] < 4'd1 || grid[val_row][0] > 4'd4 ||
                            grid[val_row][1] < 4'd1 || grid[val_row][1] > 4'd4 ||
                            grid[val_row][2] < 4'd1 || grid[val_row][2] > 4'd4 ||
                            grid[val_row][3] < 4'd1 || grid[val_row][3] > 4'd4) begin
                            yes <= 1'b0;
                            state <= DONE;
                        end else if (grid[val_row][0] == grid[val_row][1] ||
                                    grid[val_row][0] == grid[val_row][2] ||
                                    grid[val_row][0] == grid[val_row][3] ||
                                    grid[val_row][1] == grid[val_row][2] ||
                                    grid[val_row][1] == grid[val_row][3] ||
                                    grid[val_row][2] == grid[val_row][3]) begin
                            yes <= 1'b0;
                            state <= DONE;
                        end else begin
                            val_row <= val_row + 3'd1;
                        end
                    end else begin
                        state <= SEARCH;
                        current_row <= 3'd0;
                        current_col <= 3'd0;
                    end
                end

                SEARCH: begin
                    if (current_row < 4'd4) begin
                        if (current_col < 4'd4) begin
                            if (next_try[current_row][current_col] == 3'd5) begin
                                current_col <= current_col + 3'd1;
                            end else begin
                                check_val <= next_try[current_row][current_col];
                                state <= PLACE;
                            end
                        end else begin
                            current_row <= current_row + 3'd1;
                            current_col <= 3'd0;
                        end
                    end else begin
                        yes <= 1'b1;
                        state <= DONE;
                    end
                end

                PLACE: begin
                    if (check_val < 4'd1 || check_val > 4'd4) begin
                        next_try[current_row][current_col] <= 3'd5;
                        state <= BACKTRACK;
                    end else begin
                        for (i = 0; i < 4; i = i + 1) begin
                            if (i != current_col && grid[current_row][i] == check_val) begin
                                next_try[current_row][current_col] <= next_try[current_row][current_col] + 3'd1;
                                state <= SEARCH;
                            end
                        end
                        for (i = 0; i < 4; i = i + 1) begin
                            if (i != current_row && grid[i][current_col] == check_val) begin
                                next_try[current_row][current_col] <= next_try[current_row][current_col] + 3'd1;
                                state <= SEARCH;
                            end
                        end
                        grid[current_row][current_col] <= check_val;
                        next_try[current_row][current_col] <= 3'd5;
                        state <= SEARCH;
                    end
                end

                BACKTRACK: begin
                    if (current_col == 3'd0) begin
                        if (current_row == 3'd0) begin
                            yes <= 1'b0;
                            state <= DONE;
                        end else begin
                            current_row <= current_row - 3'd1;
                            current_col <= 3'd3;
                        end
                    end else begin
                        current_col <= current_col - 3'd1;
                    end
                    next_try[current_row][current_col] <= next_try[current_row][current_col] + 3'd1;
                    state <= SEARCH;
                end

                DONE: begin
                    done <= 1'b1;
                    if (yes) begin
                        result_0_0 <= grid[0][0]; result_0_1 <= grid[0][1]; result_0_2 <= grid[0][2]; result_0_3 <= grid[0][3];
                        result_1_0 <= grid[1][0]; result_1_1 <= grid[1][1]; result_1_2 <= grid[1][2]; result_1_3 <= grid[1][3];
                        result_2_0 <= grid[2][0]; result_2_1 <= grid[2][1]; result_2_2 <= grid[2][2]; result_2_3 <= grid[2][3];
                        result_3_0 <= grid[3][0]; result_3_1 <= grid[3][1]; result_3_2 <= grid[3][2]; result_3_3 <= grid[3][3];
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule