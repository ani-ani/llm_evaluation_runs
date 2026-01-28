module PathCounter(
    input clk,
    input rst_n,
    input start,
    input [2:0] x_init,
    input [2:0] grid_0_0, input [2:0] grid_0_1, input [2:0] grid_0_2, input [2:0] grid_0_3, input [2:0] grid_0_4, input [2:0] grid_0_5, input [2:0] grid_0_6, input [2:0] grid_0_7,
    input [2:0] grid_1_0, input [2:0] grid_1_1, input [2:0] grid_1_2, input [2:0] grid_1_3, input [2:0] grid_1_4, input [2:0] grid_1_5, input [2:0] grid_1_6, input [2:0] grid_1_7,
    input [2:0] grid_2_0, input [2:0] grid_2_1, input [2:0] grid_2_2, input [2:0] grid_2_3, input [2:0] grid_2_4, input [2:0] grid_2_5, input [2:0] grid_2_6, input [2:0] grid_2_7,
    input [2:0] grid_3_0, input [2:0] grid_3_1, input [2:0] grid_3_2, input [2:0] grid_3_3, input [2:0] grid_3_4, input [2:0] grid_3_5, input [2:0] grid_3_6, input [2:0] grid_3_7,
    input [2:0] grid_4_0, input [2:0] grid_4_1, input [2:0] grid_4_2, input [2:0] grid_4_3, input [2:0] grid_4_4, input [2:0] grid_4_5, input [2:0] grid_4_6, input [2:0] grid_4_7,
    input [2:0] grid_5_0, input [2:0] grid_5_1, input [2:0] grid_5_2, input [2:0] grid_5_3, input [2:0] grid_5_4, input [2:0] grid_5_5, input [2:0] grid_5_6, input [2:0] grid_5_7,
    input [2:0] grid_6_0, input [2:0] grid_6_1, input [2:0] grid_6_2, input [2:0] grid_6_3, input [2:0] grid_6_4, input [2:0] grid_6_5, input [2:0] grid_6_6, input [2:0] grid_6_7,
    input [2:0] grid_7_0, input [2:0] grid_7_1, input [2:0] grid_7_2, input [2:0] grid_7_3, input [2:0] grid_7_4, input [2:0] grid_7_5, input [2:0] grid_7_6, input [2:0] grid_7_7,
    output reg [19:0] result,
    output reg done,
    output reg begin_repairs
);

    localparam [2:0] SEA = 3'd0;
    localparam [2:0] BLOCK = 3'd1;
    localparam [2:0] RIGHT = 3'd2;
    localparam [2:0] LEFT = 3'd3;
    localparam [2:0] CASTLE = 3'd4;

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_GRID = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    reg [2:0] grid [0:7][0:7];
    reg [19:0] dp [0:7][0:7];
    reg [2:0] current_row;
    reg [2:0] current_col;
    reg [19:0] temp_result;
    reg [19:0] mod_const = 20'd1000003;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 20'd0;
            done <= 1'b0;
            begin_repairs <= 1'b0;
            cycle_count <= 8'd0;
            current_row <= 3'd0;
            current_col <= 3'd0;
            temp_result <= 20'd0;
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dp[i][j] <= 20'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    begin_repairs <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD_GRID;
                    end
                end

                LOAD_GRID: begin
                    grid[0][0] <= grid_0_0; grid[0][1] <= grid_0_1; grid[0][2] <= grid_0_2; grid[0][3] <= grid_0_3; grid[0][4] <= grid_0_4; grid[0][5] <= grid_0_5; grid[0][6] <= grid_0_6; grid[0][7] <= grid_0_7;
                    grid[1][0] <= grid_1_0; grid[1][1] <= grid_1_1; grid[1][2] <= grid_1_2; grid[1][3] <= grid_1_3; grid[1][4] <= grid_1_4; grid[1][5] <= grid_1_5; grid[1][6] <= grid_1_6; grid[1][7] <= grid_1_7;
                    grid[2][0] <= grid_2_0; grid[2][1] <= grid_2_1; grid[2][2] <= grid_2_2; grid[2][3] <= grid_2_3; grid[2][4] <= grid_2_4; grid[2][5] <= grid_2_5; grid[2][6] <= grid_2_6; grid[2][7] <= grid_2_7;
                    grid[3][0] <= grid_3_0; grid[3][1] <= grid_3_1; grid[3][2] <= grid_3_2; grid[3][3] <= grid_3_3; grid[3][4] <= grid_3_4; grid[3][5] <= grid_3_5; grid[3][6] <= grid_3_6; grid[3][7] <= grid_3_7;
                    grid[4][0] <= grid_4_0; grid[4][1] <= grid_4_1; grid[4][2] <= grid_4_2; grid[4][3] <= grid_4_3; grid[4][4] <= grid_4_4; grid[4][5] <= grid_4_5; grid[4][6] <= grid_4_6; grid[4][7] <= grid_4_7;
                    grid[5][0] <= grid_5_0; grid[5][1] <= grid_5_1; grid[5][2] <= grid_5_2; grid[5][3] <= grid_5_3; grid[5][4] <= grid_5_4; grid[5][5] <= grid_5_5; grid[5][6] <= grid_5_6; grid[5][7] <= grid_5_7;
                    grid[6][0] <= grid_6_0; grid[6][1] <= grid_6_1; grid[6][2] <= grid_6_2; grid[6][3] <= grid_6_3; grid[6][4] <= grid_6_4; grid[6][5] <= grid_6_5; grid[6][6] <= grid_6_6; grid[6][7] <= grid_6_7;
                    grid[7][0] <= grid_7_0; grid[7][1] <= grid_7_1; grid[7][2] <= grid_7_2; grid[7][3] <= grid_7_3; grid[7][4] <= grid_7_4; grid[7][5] <= grid_7_5; grid[7][6] <= grid_7_6; grid[7][7] <= grid_7_7;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count == 8'd1) begin
                        integer i, j;
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (grid[i][j] == CASTLE) begin
                                    dp[i][j] <= 20'd1;
                                end else begin
                                    dp[i][j] <= 20'd0;
                                end
                            end
                        end
                    end else if (cycle_count > 8'd1 && cycle_count <= 8'd9) begin
                        current_row <= 8'd8 - cycle_count;
                        integer j;
                        for (j = 0; j < 8; j = j + 1) begin
                            current_col <= j;
                            if (grid[current_row][current_col] == BLOCK) begin
                                dp[current_row][current_col] <= 20'd0;
                            end else if (grid[current_row][current_col] == RIGHT) begin
                                if (current_col < 7 && grid[current_row][current_col + 1] != BLOCK) begin
                                    dp[current_row][current_col] <= dp[current_row][current_col + 1];
                                end else begin
                                    dp[current_row][current_col] <= 20'd0;
                                end
                            end else if (grid[current_row][current_col] == LEFT) begin
                                if (current_col > 0 && grid[current_row][current_col - 1] != BLOCK) begin
                                    dp[current_row][current_col] <= dp[current_row][current_col - 1];
                                end else begin
                                    dp[current_row][current_col] <= 20'd0;
                                end
                            end else begin
                                if (current_row < 7 && grid[current_row + 1][current_col] != BLOCK) begin
                                    dp[current_row][current_col] <= dp[current_row + 1][current_col];
                                end else begin
                                    dp[current_row][current_col] <= 20'd0;
                                end
                            end
                        end
                    end else if (cycle_count == 8'd10) begin
                        temp_result <= dp[7][x_init];
                        if (temp_result == 20'd0) begin
                            begin_repairs <= 1'b1;
                        end else begin
                            begin_repairs <= 1'b0;
                        end
                        state <= DONE_STATE;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule