module monotonic_subgrid_count #(
    parameter MAX_R = 3,
    parameter MAX_C = 3,
    parameter DATA_WIDTH = 8,
    parameter COUNT_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] r,
    input wire [1:0] c,
    input wire [DATA_WIDTH-1:0] grid_0_0, grid_0_1, grid_0_2,
    input wire [DATA_WIDTH-1:0] grid_1_0, grid_1_1, grid_1_2,
    input wire [DATA_WIDTH-1:0] grid_2_0, grid_2_1, grid_2_2,
    output reg [COUNT_WIDTH-1:0] count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_GRID = 3'd1;
    localparam [2:0] INIT = 3'd2;
    localparam [2:0] CHECK_SUBGRID = 3'd3;
    localparam [2:0] UPDATE_COUNT = 3'd4;
    localparam [2:0] NEXT_COL_MASK = 3'd5;
    localparam [2:0] NEXT_ROW_MASK = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    // Internal signals
    reg [2:0] state;
    reg [COUNT_WIDTH-1:0] temp_count;
    reg [MAX_R-1:0] row_mask;
    reg [MAX_C-1:0] col_mask;
    reg grid_loaded;
    reg [DATA_WIDTH-1:0] grid [0:MAX_R-1][0:MAX_C-1];
    reg [1:0] i, j;
    reg [DATA_WIDTH-1:0] row_values [0:MAX_R-1];
    reg is_valid;
    reg is_increasing;
    reg is_decreasing;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            done <= 0;
            grid_loaded <= 0;
            temp_count <= 0;
            row_mask <= 0;
            col_mask <= 0;
            for (i = 0; i < MAX_R; i = i + 1) begin
                for (j = 0; j < MAX_C; j = j + 1) begin
                    grid[i][j] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD_GRID;
                        grid_loaded <= 0;
                    end
                end

                LOAD_GRID: begin
                    grid[0][0] <= grid_0_0; grid[0][1] <= grid_0_1; grid[0][2] <= grid_0_2;
                    grid[1][0] <= grid_1_0; grid[1][1] <= grid_1_1; grid[1][2] <= grid_1_2;
                    grid[2][0] <= grid_2_0; grid[2][1] <= grid_2_1; grid[2][2] <= grid_2_2;
                    grid_loaded <= 1;
                    state <= INIT;
                end

                INIT: begin
                    temp_count <= 0;
                    row_mask <= 1;
                    col_mask <= 1;
                    state <= CHECK_SUBGRID;
                end

                CHECK_SUBGRID: begin
                    state <= UPDATE_COUNT;
                end

                UPDATE_COUNT: begin
                    if (is_valid) begin
                        temp_count <= temp_count + 1;
                    end
                    state <= NEXT_COL_MASK;
                end

                NEXT_COL_MASK: begin
                    if (col_mask < (1 << c) - 1) begin
                        col_mask <= col_mask + 1;
                        state <= CHECK_SUBGRID;
                    end else begin
                        state <= NEXT_ROW_MASK;
                    end
                end

                NEXT_ROW_MASK: begin
                    if (row_mask < (1 << r) - 1) begin
                        row_mask <= row_mask + 1;
                        col_mask <= 1;
                        state <= CHECK_SUBGRID;
                    end else begin
                        count <= temp_count;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for monotonicity check
    always @(*) begin
        is_valid = 1;
        is_increasing = 1;
        is_decreasing = 1;

        // Extract values for current subgrid
        for (i = 0; i < MAX_R; i = i + 1) begin
            if (row_mask[i]) begin
                for (j = 0; j < MAX_C; j = j + 1) begin
                    if (col_mask[j]) begin
                        row_values[i] = grid[i][j];
                    end
                end
            end
        end

        // Check if all selected rows are monotonic
        for (i = 0; i < MAX_R; i = i + 1) begin
            if (row_mask[i]) begin
                for (j = i + 1; j < MAX_R; j = j + 1) begin
                    if (row_mask[j]) begin
                        if (row_values[i] > row_values[j]) begin
                            is_increasing = 0;
                        end
                        if (row_values[i] < row_values[j]) begin
                            is_decreasing = 0;
                        end
                    end
                end
            end
        end

        is_valid = is_increasing || is_decreasing;
    end

endmodule