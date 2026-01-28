module grid_stamp_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] target [0:7][0:7],
    input wire [3:0] rows,
    input wire [3:0] cols,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_ROW  = 3'd1;
    localparam [2:0] INIT_COL  = 3'd2;
    localparam [2:0] CHECK_3X3 = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] row_idx, col_idx;
    reg [3:0] center_r, center_c;
    reg [1:0] ref_color;
    reg valid_region;
    reg all_white;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Localparam for color encoding
    localparam [1:0] W = 2'd3;

    // Helper logic for 3x3 extraction and checking
    wire [1:0] cell_00, cell_01, cell_02;
    wire [1:0] cell_10, cell_11, cell_12;
    wire [1:0] cell_20, cell_21, cell_22;

    assign cell_00 = target[center_r-1][center_c-1];
    assign cell_01 = target[center_r-1][center_c];
    assign cell_02 = target[center_r-1][center_c+1];
    assign cell_10 = target[center_r][center_c-1];
    assign cell_11 = target[center_r][center_c];
    assign cell_12 = target[center_r][center_c+1];
    assign cell_20 = target[center_r+1][center_c-1];
    assign cell_21 = target[center_r+1][center_c];
    assign cell_22 = target[center_r+1][center_c+1];

    // Combinational check for valid 3x3 region
    wire is_all_white;
    wire is_all_same_color;
    wire is_same_as_ref;

    assign is_all_white = (cell_00 == W) && (cell_01 == W) && (cell_02 == W) &&
                          (cell_10 == W) && (cell_11 == W) && (cell_12 == W) &&
                          (cell_20 == W) && (cell_21 == W) && (cell_22 == W);

    assign is_same_as_ref = (cell_00 == ref_color) && (cell_01 == ref_color) && (cell_02 == ref_color) &&
                            (cell_10 == ref_color) && (cell_11 == ref_color) && (cell_12 == ref_color) &&
                            (cell_20 == ref_color) && (cell_21 == ref_color) && (cell_22 == ref_color);

    // Region is valid if all white OR all same non-white color
    assign is_all_same_color = is_same_as_ref && (ref_color != W);

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            center_r <= 4'd0;
            center_c <= 4'd0;
            ref_color <= 2'd0;
            valid_region <= 1'b1;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    valid_region <= 1'b1;
                    cycle_count <= 8'd0;
                end
                INIT_ROW: begin
                    row_idx <= 4'd1;
                    center_r <= 4'd1;
                end
                INIT_COL: begin
                    col_idx <= 4'd1;
                    center_c <= 4'd1;
                end
                CHECK_3X3: begin
                    // Check if current region is valid
                    if (!(is_all_white || is_all_same_color)) begin
                        valid_region <= 1'b0;
                    end
                end
                UPDATE: begin
                    // Update indices
                    if (center_c < cols - 2) begin
                        center_c <= center_c + 4'd1;
                        col_idx <= col_idx + 4'd1;
                    end else begin
                        center_c <= 4'd1;
                        col_idx <= 4'd1;
                        if (center_r < rows - 2) begin
                            center_r <= center_r + 4'd1;
                            row_idx <= row_idx + 4'd1;
                        end
                    end
                    // Set reference color based on current region if not all white
                    if (!is_all_white && valid_region) begin
                        ref_color <= cell_00;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                    // Result is 1 only if no invalid regions found and all conditions met
                    // Additional check: if there are non-white cells, they must form valid 3x3 blocks
                    if (valid_region) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT_ROW;
                else
                    next_state = IDLE;
            end
            INIT_ROW: begin
                if (rows < 4'd3) begin
                    // If grid too small, only check single cells
                    if (rows > 4'd0 && cols > 4'd0)
                        next_state = CHECK_3X3;
                    else
                        next_state = FINISH;
                end else begin
                    next_state = INIT_COL;
                end
            end
            INIT_COL: begin
                if (cols < 4'd3) begin
                    next_state = CHECK_3X3;
                end else begin
                    next_state = CHECK_3X3;
                end
            end
            CHECK_3X3: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                // Check if we've processed all regions
                if ((center_r >= rows - 2) && (center_c >= cols - 2) && (rows >= 4'd3) && (cols >= 4'd3)) begin
                    next_state = FINISH;
                end else if ((rows < 4'd3) || (cols < 4'd3)) begin
                    // For small grids, process single cells
                    if (center_c < cols && center_r < rows) begin
                        next_state = CHECK_3X3;
                    end else begin
                        next_state = FINISH;
                    end
                end else begin
                    next_state = CHECK_3X3;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase

        // Timeout protection
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = FINISH;
        end
    end

endmodule