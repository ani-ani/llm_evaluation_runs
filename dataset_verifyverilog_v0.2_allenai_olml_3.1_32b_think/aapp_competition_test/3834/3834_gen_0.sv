module rectangular_grid_checker (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] row_data [7:0], // 8 rows of 8 bits each
    input [2:0] row_index,
    input load_row,
    output reg [3:0] result,
    output reg done
);

reg [2:0] state; // 0: IDLE, 1: LOAD_GRID, 2: PROCESSING, 3: DONE
reg [7][8] grid; // 8x8 grid
reg [6:0] invalid_count;
reg [7:0] timer;
reg done_flag;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
        grid <= 8'b0;
        invalid_count <= 8'd0;
        timer <= 8'd0;
        done_flag <= 1'b0;
        result <= 4'd0;
    end else begin
        case (state)
            3'd0: // IDLE
                if (load_row) begin
                    grid[row_index] <= row_data;
                    state <= 3'd1; // transition to LOAD_GRID
                end else if (start) begin
                    state <= 3'd2; // move to PROCESSING
                    timer <= 8'd0;
                end
            3'd1: // LOAD_GRID
                // Immediately return to IDLE
                state <= 3'd0;
            3'd2: // PROCESSING
                if (timer == 8'd127) begin
                    invalid_count <= ( (grid[0][0] == grid[1][1] && grid[0][1] != grid[1][0]) ? 1 : 0 ) +
                        ( (grid[0][1] == grid[1][2] && grid[0][2] != grid[1][1]) ? 1 : 0 ) +
                        ( (grid[0][2] == grid[1][3] && grid[0][3] != grid[1][2]) ? 1 : 0 ) +
                        ( (grid[0][3] == grid[1][4] && grid[0][4] != grid[1][3]) ? 1 : 0 ) +
                        ( (grid[0][4] == grid[1][5] && grid[0][5] != grid[1][4]) ? 1 : 0 ) +
                        ( (grid[0][5] == grid[1][6] && grid[0][6] != grid[1][5]) ? 1 : 0 ) +
                        ( (grid[0][6] == grid[1][7] && grid[0][7] != grid[1][6]) ? 1 : 0 ) +
                        ( (grid[1][0] == grid[2][1] && grid[1][1] != grid[2][0]) ? 1 : 0 ) +
                        ( (grid[1][1] == grid[2][2] && grid[1][2] != grid[2][1]) ? 1 : 0 ) +
                        ( (grid[1][2] == grid[2][3] && grid[1][3] != grid[2][2]) ? 1 : 0 ) +
                        ( (grid[1][3] == grid[2][4] && grid[1][4] != grid[2][3]) ? 1 : 0 ) +
                        ( (grid[1][4] == grid[2][5] && grid[1][5] != grid[2][4]) ? 1 : 0 ) +
                        ( (grid[1][5] == grid[2][6] && grid[1][6] != grid[2][5]) ? 1 : 0 ) +
                        ( (grid[1][6] == grid[2][7] && grid[1][7] != grid[2][6]) ? 1 : 0 ) +
                        ( (grid[2][0] == grid[3][1] && grid[2][1] != grid[3][0]) ? 1 : 0 ) +
                        ( (grid[2][1] == grid[3][2] && grid[2][2] != grid[3][1]) ? 1 : 0 ) +
                        ( (grid[2][2] == grid[3][3] && grid[2][3] != grid[3][2]) ? 1 : 0 ) +
                        ( (grid[2][3] == grid[3][4] && grid[2][4] != grid[3][3]) ? 1 : 0 ) +
                        ( (grid[2][4] == grid[3][5] && grid[2][5] != grid[3][4]) ? 1 : 0 ) +
                        ( (grid[2][5] == grid[3][6] && grid[2][6] != grid[3][5]) ? 1 : 0 ) +
                        ( (grid[2][6] == grid[3][7] && grid[2][7] != grid[3][6]) ? 1 : 0 ) +
                        ( (grid[3][0] == grid[4][1] && grid[3][1] != grid[4][0]) ? 1 : 0 ) +
                        ( (grid[3][1] == grid[4][2] && grid[3][2] != grid[4][1]) ? 1 : 0 ) +
                        ( (grid[3][2] == grid[4][3] && grid[3][3] != grid[4][2]) ? 1 : 0 ) +
                        ( (grid[3][3] == grid[4][4] && grid[3][4] != grid[4][3]) ? 1 : 0 ) +
                        ( (grid[3][4] == grid[4][5] && grid[3][5] != grid[4][4]) ? 1 : 0 ) +
                        ( (grid[3][5] == grid[4][6] && grid[3][6] != grid[4][5]) ? 1 : 0 ) +
                        ( (grid[3][6] == grid[4][7] && grid[3][7] != grid[4][6]) ? 1 : 0 ) +
                        ( (grid[4][0] == grid[5][1] && grid[4][1] != grid[5][0]) ? 1 : 0 ) +
                        ( (grid[4][1] == grid[5][2] && grid[4][2] != grid[5][1]) ? 1 : 0 ) +
                        ( (grid[4][2] == grid[5][3] && grid[4][3] != grid[5][2]) ? 1 : 0 ) +
                        ( (grid[4][3] == grid[5][4] && grid[4][4] != grid[5][3]) ? 1 : 0 ) +
                        ( (grid[4][4] == grid[5][5] && grid[4][5] != grid[5][4]) ? 1 : 0 ) +
                        ( (grid[4][5] == grid[5][6] && grid[4][6] != grid[5][5]) ? 1 : 0 ) +
                        ( (grid[4][6] == grid[5][7] && grid[4][7] != grid[5][6]) ? 1 : 0 ) +
                        ( (grid[5][0] == grid[6][1] && grid[5][1] != grid[6][0]) ? 1 : 0 ) +
                        ( (grid[5][1] == grid[6][2] && grid[5][2] != grid[6][1]) ? 1 : 0 ) +
                        ( (grid[5][2] == grid[6][3] && grid[5][3] != grid[6][2]) ? 1 : 0 ) +
                        ( (grid[5][3] == grid[6][4] && grid[5][4] != grid[6][3]) ? 1 : 0 ) +
                        ( (grid[5][4] == grid[6][5] && grid[5][5] != grid[6][4]) ? 1 : 0 ) +
                        ( (grid[5][5] == grid[6][6] && grid[5][6] != grid[6][5]) ? 1 : 0 ) +
                        ( (grid[5][6] == grid[6][7] && grid[5][7] != grid[6][6]) ? 1 : 0 ) +
                        ( (grid[6][0] == grid[7][1] && grid[6][1] != grid[7][0]) ? 1 : 0 ) +
                        ( (grid[6][1] == grid[7][2] && grid[6][2] != grid[7][1]) ? 1 : 0 ) +
                        ( (grid[6][2] == grid[7][3] && grid[6][3] != grid[7][2]) ? 1 : 0 ) +
                        ( (grid[6][3] == grid[7][4] && grid[6][4] != grid[7][3]) ? 1 : 0 ) +
                        ( (grid[6][4] == grid[7][5] && grid[6][5] != grid[7][4]) ? 1 : 0 ) +
                        ( (grid[6][5] == grid[7][6] && grid[6][6] != grid[7][5]) ? 1 : 0 ) +
                        ( (grid[6][6] == grid[7][7] && grid[6][7] != grid[7][6]) ? 1 : 0 );
                    if (invalid_count > 4) begin
                        result <= 5;
                    end else begin
                        result <= invalid_count;
                    end
                    done_flag <= 1'b1;
                    state <= 3'd3; // DONE
                end else begin
                    timer <= timer + 1;
                end
            3'd3: // DONE
                // Remain in DONE state
                state <= 3'd3;
        endcase
    end
end

// Output assignments
assign done = done_flag;

endmodule