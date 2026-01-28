module IceMazeSolver(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_0_0, input [7:0] grid_0_1, input [7:0] grid_0_2, input [7:0] grid_0_3,
    input [7:0] grid_0_4, input [7:0] grid_0_5, input [7:0] grid_0_6, input [7:0] grid_0_7,
    input [7:0] grid_1_0, input [7:0] grid_1_1, input [7:0] grid_1_2, input [7:0] grid_1_3,
    input [7:0] grid_1_4, input [7:0] grid_1_5, input [7:0] grid_1_6, input [7:0] grid_1_7,
    input [7:0] grid_2_0, input [7:0] grid_2_1, input [7:0] grid_2_2, input [7:0] grid_2_3,
    input [7:0] grid_2_4, input [7:0] grid_2_5, input [7:0] grid_2_6, input [7:0] grid_2_7,
    input [7:0] grid_3_0, input [7:0] grid_3_1, input [7:0] grid_3_2, input [7:0] grid_3_3,
    input [7:0] grid_3_4, input [7:0] grid_3_5, input [7:0] grid_3_6, input [7:0] grid_3_7,
    input [7:0] grid_4_0, input [7:0] grid_4_1, input [7:0] grid_4_2, input [7:0] grid_4_3,
    input [7:0] grid_4_4, input [7:0] grid_4_5, input [7:0] grid_4_6, input [7:0] grid_4_7,
    input [7:0] grid_5_0, input [7:0] grid_5_1, input [7:0] grid_5_2, input [7:0] grid_5_3,
    input [7:0] grid_5_4, input [7:0] grid_5_5, input [7:0] grid_5_6, input [7:0] grid_5_7,
    input [7:0] grid_6_0, input [7:0] grid_6_1, input [7:0] grid_6_2, input [7:0] grid_6_3,
    input [7:0] grid_6_4, input [7:0] grid_6_5, input [7:0] grid_6_6, input [7:0] grid_6_7,
    input [7:0] grid_7_0, input [7:0] grid_7_1, input [7:0] grid_7_2, input [7:0] grid_7_3,
    input [7:0] grid_7_4, input [7:0] grid_7_5, input [7:0] grid_7_6, input [7:0] grid_7_7,
    output reg [15:0] result_0_0, output reg [15:0] result_0_1, output reg [15:0] result_0_2, output reg [15:0] result_0_3,
    output reg [15:0] result_0_4, output reg [15:0] result_0_5, output reg [15:0] result_0_6, output reg [15:0] result_0_7,
    output reg [15:0] result_1_0, output reg [15:0] result_1_1, output reg [15:0] result_1_2, output reg [15:0] result_1_3,
    output reg [15:0] result_1_4, output reg [15:0] result_1_5, output reg [15:0] result_1_6, output reg [15:0] result_1_7,
    output reg [15:0] result_2_0, output reg [15:0] result_2_1, output reg [15:0] result_2_2, output reg [15:0] result_2_3,
    output reg [15:0] result_2_4, output reg [15:0] result_2_5, output reg [15:0] result_2_6, output reg [15:0] result_2_7,
    output reg [15:0] result_3_0, output reg [15:0] result_3_1, output reg [15:0] result_3_2, output reg [15:0] result_3_3,
    output reg [15:0] result_3_4, output reg [15:0] result_3_5, output reg [15:0] result_3_6, output reg [15:0] result_3_7,
    output reg [15:0] result_4_0, output reg [15:0] result_4_1, output reg [15:0] result_4_2, output reg [15:0] result_4_3,
    output reg [15:0] result_4_4, output reg [15:0] result_4_5, output reg [15:0] result_4_6, output reg [15:0] result_4_7,
    output reg [15:0] result_5_0, output reg [15:0] result_5_1, output reg [15:0] result_5_2, output reg [15:0] result_5_3,
    output reg [15:0] result_5_4, output reg [15:0] result_5_5, output reg [15:0] result_5_6, output reg [15:0] result_5_7,
    output reg [15:0] result_6_0, output reg [15:0] result_6_1, output reg [15:0] result_6_2, output reg [15:0] result_6_3,
    output reg [15:0] result_6_4, output reg [15:0] result_6_5, output reg [15:0] result_6_6, output reg [15:0] result_6_7,
    output reg [15:0] result_7_0, output reg [15:0] result_7_1, output reg [15:0] result_7_2, output reg [15:0] result_7_3,
    output reg [15:0] result_7_4, output reg [15:0] result_7_5, output reg [15:0] result_7_6, output reg [15:0] result_7_7,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BFS = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Grid and result arrays
    reg [7:0] grid [0:7][0:7];
    reg [15:0] result [0:7][0:7];

    // BFS queue (64 entries max)
    reg [5:0] queue [0:63];
    reg [5:0] queue_head, queue_tail;
    reg queue_empty;

    // Current processing cell
    reg [5:0] current_cell;
    reg [2:0] current_row, current_col;

    // Slide direction and landing position
    reg [1:0] dir;
    reg [2:0] land_row, land_col;

    // Cycle counter for timeout
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // State machine
    reg [2:0] state;

    // Initialize grid and result arrays
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize grid
            grid[0][0] <= grid_0_0; grid[0][1] <= grid_0_1; grid[0][2] <= grid_0_2; grid[0][3] <= grid_0_3;
            grid[0][4] <= grid_0_4; grid[0][5] <= grid_0_5; grid[0][6] <= grid_0_6; grid[0][7] <= grid_0_7;
            grid[1][0] <= grid_1_0; grid[1][1] <= grid_1_1; grid[1][2] <= grid_1_2; grid[1][3] <= grid_1_3;
            grid[1][4] <= grid_1_4; grid[1][5] <= grid_1_5; grid[1][6] <= grid_1_6; grid[1][7] <= grid_1_7;
            grid[2][0] <= grid_2_0; grid[2][1] <= grid_2_1; grid[2][2] <= grid_2_2; grid[2][3] <= grid_2_3;
            grid[2][4] <= grid_2_4; grid[2][5] <= grid_2_5; grid[2][6] <= grid_2_6; grid[2][7] <= grid_2_7;
            grid[3][0] <= grid_3_0; grid[3][1] <= grid_3_1; grid[3][2] <= grid_3_2; grid[3][3] <= grid_3_3;
            grid[3][4] <= grid_3_4; grid[3][5] <= grid_3_5; grid[3][6] <= grid_3_6; grid[3][7] <= grid_3_7;
            grid[4][0] <= grid_4_0; grid[4][1] <= grid_4_1; grid[4][2] <= grid_4_2; grid[4][3] <= grid_4_3;
            grid[4][4] <= grid_4_4; grid[4][5] <= grid_4_5; grid[4][6] <= grid_4_6; grid[4][7] <= grid_4_7;
            grid[5][0] <= grid_5_0; grid[5][1] <= grid_5_1; grid[5][2] <= grid_5_2; grid[5][3] <= grid_5_3;
            grid[5][4] <= grid_5_4; grid[5][5] <= grid_5_5; grid[5][6] <= grid_5_6; grid[5][7] <= grid_5_7;
            grid[6][0] <= grid_6_0; grid[6][1] <= grid_6_1; grid[6][2] <= grid_6_2; grid[6][3] <= grid_6_3;
            grid[6][4] <= grid_6_4; grid[6][5] <= grid_6_5; grid[6][6] <= grid_6_6; grid[6][7] <= grid_6_7;
            grid[7][0] <= grid_7_0; grid[7][1] <= grid_7_1; grid[7][2] <= grid_7_2; grid[7][3] <= grid_7_3;
            grid[7][4] <= grid_7_4; grid[7][5] <= grid_7_5; grid[7][6] <= grid_7_6; grid[7][7] <= grid_7_7;

            // Initialize result arrays
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    result[i][j] <= 16'd0;
                end
            end

            // Initialize BFS queue
            queue_head <= 6'd0;
            queue_tail <= 6'd0;
            queue_empty <= 1'b1;

            // Initialize state and counters
            state <= IDLE;
            cycle_count <= 10'd0;
            done <= 1'b0;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Find goal position and initialize queue
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (grid[i][j] == 8'd77) begin  // 'M'
                                result[i][j] <= 16'd0;
                                queue[0] <= {i, j};
                                queue_head <= 6'd0;
                                queue_tail <= 6'd1;
                                queue_empty <= 1'b0;
                                state <= BFS;
                            end else if (grid[i][j] == 8'd35) begin  // '#'
                                result[i][j] <= 16'd65535;  // -1 in 16-bit signed
                            end else begin
                                result[i][j] <= 16'd65535;  // Initialize to -1
                            end
                        end
                    end
                end

                BFS: begin
                    if (!queue_empty && cycle_count < MAX_CYCLES) begin
                        // Process current cell
                        current_cell <= queue[queue_head];
                        current_row <= current_cell[5:3];
                        current_col <= current_cell[2:0];

                        // Explore all 4 directions
                        for (dir = 0; dir < 4; dir = dir + 1) begin
                            // Compute landing position
                            case (dir)
                                2'd0: begin  // North
                                    land_row <= current_row;
                                    while (land_row > 0 && grid[land_row-1][current_col] == 8'd95) begin  // '_'
                                        land_row <= land_row - 1;
                                    end
                                    land_row <= land_row - 1;
                                    land_col <= current_col;
                                end
                                2'd1: begin  // South
                                    land_row <= current_row;
                                    while (land_row < 7 && grid[land_row+1][current_col] == 8'd95) begin  // '_'
                                        land_row <= land_row + 1;
                                    end
                                    land_row <= land_row + 1;
                                    land_col <= current_col;
                                end
                                2'd2: begin  // East
                                    land_col <= current_col;
                                    while (land_col < 7 && grid[current_row][land_col+1] == 8'd95) begin  // '_'
                                        land_col <= land_col + 1;
                                    end
                                    land_col <= land_col + 1;
                                    land_row <= current_row;
                                end
                                2'd3: begin  // West
                                    land_col <= current_col;
                                    while (land_col > 0 && grid[current_row][land_col-1] == 8'd95) begin  // '_'
                                        land_col <= land_col - 1;
                                    end
                                    land_col <= land_col - 1;
                                    land_row <= current_row;
                                end
                            endcase

                            // Check if landing position is valid and not visited
                            if (land_row >= 0 && land_row < 8 && land_col >= 0 && land_col < 8 &&
                                grid[land_row][land_col] != 8'd35 &&  // Not obstacle
                                result[land_row][land_col] == 16'd65535) begin  // Not visited
                                
                                // Update distance and add to queue
                                result[land_row][land_col] <= result[current_row][current_col] + 16'd1;
                                queue[queue_tail] <= {land_row, land_col};
                                queue_tail <= queue_tail + 6'd1;
                                if (queue_tail == 6'd64) begin
                                    queue_tail <= 6'd0;
                                end
                            end
                        end

                        // Move to next cell in queue
                        queue_head <= queue_head + 6'd1;
                        if (queue_head == 6'd64) begin
                            queue_head <= 6'd0;
                        end
                        if (queue_head == queue_tail) begin
                            queue_empty <= 1'b1;
                        end

                        cycle_count <= cycle_count + 10'd1;
                    end else begin
                        state <= DONE_STATE;
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

    // Update output ports
    always @(posedge clk) begin
        result_0_0 <= result[0][0]; result_0_1 <= result[0][1]; result_0_2 <= result[0][2]; result_0_3 <= result[0][3];
        result_0_4 <= result[0][4]; result_0_5 <= result[0][5]; result_0_6 <= result[0][6]; result_0_7 <= result[0][7];
        result_1_0 <= result[1][0]; result_1_1 <= result[1][1]; result_1_2 <= result[1][2]; result_1_3 <= result[1][3];
        result_1_4 <= result[1][4]; result_1_5 <= result[1][5]; result_1_6 <= result[1][6]; result_1_7 <= result[1][7];
        result_2_0 <= result[2][0]; result_2_1 <= result[2][1]; result_2_2 <= result[2][2]; result_2_3 <= result[2][3];
        result_2_4 <= result[2][4]; result_2_5 <= result[2][5]; result_2_6 <= result[2][6]; result_2_7 <= result[2][7];
        result_3_0 <= result[3][0]; result_3_1 <= result[3][1]; result_3_2 <= result[3][2]; result_3_3 <= result[3][3];
        result_3_4 <= result[3][4]; result_3_5 <= result[3][5]; result_3_6 <= result[3][6]; result_3_7 <= result[3][7];
        result_4_0 <= result[4][0]; result_4_1 <= result[4][1]; result_4_2 <= result[4][2]; result_4_3 <= result[4][3];
        result_4_4 <= result[4][4]; result_4_5 <= result[4][5]; result_4_6 <= result[4][6]; result_4_7 <= result[4][7];
        result_5_0 <= result[5][0]; result_5_1 <= result[5][1]; result_5_2 <= result[5][2]; result_5_3 <= result[5][3];
        result_5_4 <= result[5][4]; result_5_5 <= result[5][5]; result_5_6 <= result[5][6]; result_5_7 <= result[5][7];
        result_6_0 <= result[6][0]; result_6_1 <= result[6][1]; result_6_2 <= result[6][2]; result_6_3 <= result[6][3];
        result_6_4 <= result[6][4]; result_6_5 <= result[6][5]; result_6_6 <= result[6][6]; result_6_7 <= result[6][7];
        result_7_0 <= result[7][0]; result_7_1 <= result[7][1]; result_7_2 <= result[7][2]; result_7_3 <= result[7][3];
        result_7_4 <= result[7][4]; result_7_5 <= result[7][5]; result_7_6 <= result[7][6]; result_7_7 <= result[7][7];
    end

endmodule