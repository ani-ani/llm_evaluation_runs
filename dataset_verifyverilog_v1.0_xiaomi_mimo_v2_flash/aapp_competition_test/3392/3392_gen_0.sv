module largest_connected_component #(
    parameter N = 4,
    parameter DATA_WIDTH = 8,
    parameter SUM_WIDTH = 9,
    parameter SIZE_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] h_00, h_01, h_02, h_03,
    input wire [DATA_WIDTH-1:0] h_10, h_11, h_12, h_13,
    input wire [DATA_WIDTH-1:0] h_20, h_21, h_22, h_23,
    input wire [DATA_WIDTH-1:0] h_30, h_31, h_32, h_33,
    input wire [DATA_WIDTH-1:0] v_00, v_01, v_02, v_03,
    input wire [DATA_WIDTH-1:0] v_10, v_11, v_12, v_13,
    input wire [DATA_WIDTH-1:0] v_20, v_21, v_22, v_23,
    input wire [DATA_WIDTH-1:0] v_30, v_31, v_32, v_33,
    output reg [SIZE_WIDTH-1:0] max_size,
    output reg done
);

    // Grid indices
    localparam [1:0] ROW_0 = 2'd0;
    localparam [1:0] ROW_1 = 2'd1;
    localparam [1:0] ROW_2 = 2'd2;
    localparam [1:0] ROW_3 = 2'd3;
    localparam [1:0] COL_0 = 2'd0;
    localparam [1:0] COL_1 = 2'd1;
    localparam [1:0] COL_2 = 2'd2;
    localparam [1:0] COL_3 = 2'd3;

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_SUMS = 4'd1;
    localparam [3:0] FIND_COMPONENTS = 4'd2;
    localparam [3:0] EXPLORE = 4'd3;
    localparam [3:0] PROCESS_STACK = 4'd4;
    localparam [3:0] UPDATE_MAX = 4'd5;
    localparam [3:0] RESET_VISITED = 4'd6;
    localparam [3:0] DONE = 4'd7;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Storage for sums
    reg [SUM_WIDTH-1:0] sums [0:N-1][0:N-1];
    reg visited [0:N-1][0:N-1];
    reg visited_next [0:N-1][0:N-1];

    // Stack for flood fill (max 16 cells)
    reg [3:0] stack_x [0:15];
    reg [3:0] stack_y [0:15];
    reg [4:0] stack_ptr;
    reg [4:0] stack_size;

    // Cell tracking
    reg [1:0] row_idx;
    reg [1:0] col_idx;
    reg [1:0] explore_row;
    reg [1:0] explore_col;
    reg [1:0] neighbor_row;
    reg [1:0] neighbor_col;

    // Current component
    reg [SUM_WIDTH-1:0] current_sum;
    reg [SIZE_WIDTH-1:0] component_size;

    // Intermediate sums for computation
    reg [SUM_WIDTH-1:0] temp_sum;
    reg [1:0] calc_row;
    reg [1:0] calc_col;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_size <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    sums[i][j] <= {SUM_WIDTH{1'b0}};
                    visited[i][j] <= 1'b0;
                    visited_next[i][j] <= 1'b0;
                end
            end
            for (i = 0; i < 16; i = i + 1) begin
                stack_x[i] <= 4'd0;
                stack_y[i] <= 4'd0;
            end
            stack_ptr <= 5'd0;
            stack_size <= 5'd0;
            row_idx <= 2'd0;
            col_idx <= 2'd0;
            explore_row <= 2'd0;
            explore_col <= 2'd0;
            neighbor_row <= 2'd0;
            neighbor_col <= 2'd0;
            current_sum <= {SUM_WIDTH{1'b0}};
            component_size <= 8'd0;
            calc_row <= 2'd0;
            calc_col <= 2'd0;
            temp_sum <= {SUM_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    max_size <= 8'd0;
                    row_idx <= 2'd0;
                    col_idx <= 2'd0;
                    calc_row <= 2'd0;
                    calc_col <= 2'd0;
                    if (start) begin
                        state <= COMPUTE_SUMS;
                    end
                end

                COMPUTE_SUMS: begin
                    case (calc_row)
                        2'd0: begin
                            case (calc_col)
                                2'd0: temp_sum <= h_00 + v_00;
                                2'd1: temp_sum <= h_01 + v_01;
                                2'd2: temp_sum <= h_02 + v_02;
                                2'd3: temp_sum <= h_03 + v_03;
                            endcase
                        end
                        2'd1: begin
                            case (calc_col)
                                2'd0: temp_sum <= h_10 + v_10;
                                2'd1: temp_sum <= h_11 + v_11;
                                2'd2: temp_sum <= h_12 + v_12;
                                2'd3: temp_sum <= h_13 + v_13;
                            endcase
                        end
                        2'd2: begin
                            case (calc_col)
                                2'd0: temp_sum <= h_20 + v_20;
                                2'd1: temp_sum <= h_21 + v_21;
                                2'd2: temp_sum <= h_22 + v_22;
                                2'd3: temp_sum <= h_23 + v_23;
                            endcase
                        end
                        2'd3: begin
                            case (calc_col)
                                2'd0: temp_sum <= h_30 + v_30;
                                2'd1: temp_sum <= h_31 + v_31;
                                2'd2: temp_sum <= h_32 + v_32;
                                2'd3: temp_sum <= h_33 + v_33;
                            endcase
                        end
                    endcase
                    
                    if (calc_col < 2'd3) begin
                        calc_col <= calc_col + 2'd1;
                    end else begin
                        calc_col <= 2'd0;
                        if (calc_row < 2'd3) begin
                            calc_row <= calc_row + 2'd1;
                        end else begin
                            calc_row <= 2'd0;
                            state <= FIND_COMPONENTS;
                        end
                    end
                end

                FIND_COMPONENTS: begin
                    sums[row_idx][col_idx] <= temp_sum;
                    if (col_idx < 2'd3) begin
                        col_idx <= col_idx + 2'd1;
                    end else begin
                        col_idx <= 2'd0;
                        if (row_idx < 2'd3) begin
                            row_idx <= row_idx + 2'd1;
                        end else begin
                            row_idx <= 2'd0;
                            explore_row <= 2'd0;
                            explore_col <= 2'd0;
                            state <= EXPLORE;
                        end
                    end
                end

                EXPLORE: begin
                    if (!visited[explore_row][explore_col]) begin
                        current_sum <= sums[explore_row][explore_col];
                        component_size <= 8'd0;
                        stack_x[5'd0] <= explore_row;
                        stack_y[5'd0] <= explore_col;
                        stack_ptr <= 5'd1;
                        stack_size <= 5'd1;
                        visited[explore_row][explore_col] <= 1'b1;
                        state <= PROCESS_STACK;
                    end else begin
                        if (explore_col < 2'd3) begin
                            explore_col <= explore_col + 2'd1;
                        end else begin
                            explore_col <= 2'd0;
                            if (explore_row < 2'd3) begin
                                explore_row <= explore_row + 2'd1;
                            end else begin
                                explore_row <= 2'd0;
                                state <= UPDATE_MAX;
                            end
                        end
                    end
                end

                PROCESS_STACK: begin
                    if (stack_ptr > 5'd0) begin
                        stack_ptr <= stack_ptr - 5'd1;
                        component_size <= component_size + 8'd1;
                        explore_row <= stack_x[stack_ptr - 5'd1];
                        explore_col <= stack_y[stack_ptr - 5'd1];
                        state <= RESET_VISITED;
                    end else begin
                        state <= EXPLORE;
                    end
                end

                RESET_VISITED: begin
                    if (explore_row == 2'd0) begin
                        neighbor_row <= 2'd1;
                    end else if (explore_row == 2'd1) begin
                        neighbor_row <= 2'd0;
                    end else if (explore_row == 2'd2) begin
                        neighbor_row <= 2'd3;
                    end else begin
                        neighbor_row <= 2'd2;
                    end
                    
                    if (explore_col == 2'd0) begin
                        neighbor_col <= 2'd1;
                    end else if (explore_col == 2'd1) begin
                        neighbor_col <= 2'd0;
                    end else if (explore_col == 2'd2) begin
                        neighbor_col <= 2'd3;
                    end else begin
                        neighbor_col <= 2'd2;
                    end
                    state <= FIND_COMPONENTS;
                end

                UPDATE_MAX: begin
                    if (component_size > max_size) begin
                        max_size <= component_size;
                    end
                    state <= FIND_COMPONENTS;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= DONE;
            end
        end
    end
endmodule