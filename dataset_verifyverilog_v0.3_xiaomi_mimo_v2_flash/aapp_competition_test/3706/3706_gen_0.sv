module karen_and_game (
    input clk, rst_n, start,
    input [7:0] grid_flat [0:63],
    output reg done, error,
    output reg [31:0] move_count,
    output reg output_valid, move_type,
    output reg [3:0] move_index
);

// Parameters
parameter ROWS = 8;
parameter COLS = 8;
parameter DATA_WIDTH = 8;

// States
localparam [2:0] IDLE        = 3'd0;
localparam [2:0] COMP_ROW    = 3'd1;
localparam [2:0] COMP_COL    = 3'd2;
localparam [2:0] CHECK       = 3'd3;
localparam [2:0] COMPUTE_TOTAL = 3'd4;
localparam [2:0] OUTPUT_ROWS = 3'd5;
localparam [2:0] OUTPUT_COLS = 3'd6;
localparam [2:0] DONE_STATE  = 3'd7;

// Registers
reg [2:0] state, next_state;
reg [2:0] row_idx, col_idx;
reg [2:0] out_row_idx, out_col_idx;
reg [DATA_WIDTH-1:0] min_row [0:ROWS-1];
reg [DATA_WIDTH-1:0] min_col [0:COLS-1];
reg [DATA_WIDTH-1:0] temp_min;
reg [DATA_WIDTH-1:0] temp_val;
reg [31:0] total;
reg [2:0] cycle_count;
localparam [2:0] MAX_CYCLES = 3'd6;

integer i, j;

// State transition and outputs
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        error <= 1'b0;
        move_count <= 32'd0;
        output_valid <= 1'b0;
        move_type <= 1'b0;
        move_index <= 4'd0;
        row_idx <= 3'd0;
        col_idx <= 3'd0;
        out_row_idx <= 3'd0;
        out_col_idx <= 3'd0;
        temp_min <= 8'd0;
        temp_val <= 8'd0;
        total <= 32'd0;
        cycle_count <= 3'd0;
        // Initialize arrays
        for (i = 0; i < 8; i = i + 1) begin
            min_row[i] <= 8'd0;
            min_col[i] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                error <= 1'b0;
                output_valid <= 1'b0;
                if (start) begin
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                    temp_min <= grid_flat[0];
                    cycle_count <= 3'd0;
                end
            end

            COMP_ROW: begin
                if (row_idx < ROWS) begin
                    if (col_idx < COLS) begin
                        temp_val <= grid_flat[row_idx * COLS + col_idx];
                        col_idx <= col_idx + 3'd1;
                    end else begin
                        min_row[row_idx] <= temp_min;
                        row_idx <= row_idx + 3'd1;
                        col_idx <= 3'd0;
                        if (row_idx < ROWS - 1)
                            temp_min <= grid_flat[(row_idx + 1) * COLS];
                    end
                end
            end

            COMP_COL: begin
                if (col_idx < COLS) begin
                    if (row_idx < ROWS) begin
                        temp_val <= grid_flat[row_idx * COLS + col_idx] - min_row[row_idx];
                        row_idx <= row_idx + 3'd1;
                    end else begin
                        min_col[col_idx] <= temp_min;
                        col_idx <= col_idx + 3'd1;
                        row_idx <= 3'd0;
                        if (col_idx < COLS - 1)
                            temp_min <= grid_flat[0] - min_row[0];
                    end
                end
            end

            CHECK: begin
                if (row_idx < ROWS) begin
                    if (col_idx < COLS) begin
                        temp_val <= grid_flat[row_idx * COLS + col_idx] - min_row[row_idx] - min_col[col_idx];
                        col_idx <= col_idx + 3'd1;
                    end else begin
                        row_idx <= row_idx + 3'd1;
                        col_idx <= 3'd0;
                    end
                end
            end

            COMPUTE_TOTAL: begin
                total <= 32'd0;
                cycle_count <= cycle_count + 3'd1;
            end

            OUTPUT_ROWS: begin
                if (out_row_idx < ROWS) begin
                    if (min_row[out_row_idx] > 8'd0) begin
                        output_valid <= 1'b1;
                        move_type <= 1'b0;
                        move_index <= out_row_idx + 4'd1;
                        min_row[out_row_idx] <= min_row[out_row_idx] - 8'd1;
                    end else begin
                        out_row_idx <= out_row_idx + 3'd1;
                        output_valid <= 1'b0;
                    end
                end else begin
                    output_valid <= 1'b0;
                end
            end

            OUTPUT_COLS: begin
                if (out_col_idx < COLS) begin
                    if (min_col[out_col_idx] > 8'd0) begin
                        output_valid <= 1'b1;
                        move_type <= 1'b1;
                        move_index <= out_col_idx + 4'd1;
                        min_col[out_col_idx] <= min_col[out_col_idx] - 8'd1;
                    end else begin
                        out_col_idx <= out_col_idx + 3'd1;
                        output_valid <= 1'b0;
                    end
                end else begin
                    output_valid <= 1'b0;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) begin
                next_state = COMP_ROW;
            end else begin
                next_state = IDLE;
            end
        end

        COMP_ROW: begin
            if (row_idx == ROWS) begin
                next_state = COMP_COL;
            end else begin
                next_state = COMP_ROW;
            end
        end

        COMP_COL: begin
            if (col_idx == COLS) begin
                next_state = CHECK;
            end else begin
                next_state = COMP_COL;
            end
        end

        CHECK: begin
            if (temp_val != 8'd0) begin
                next_state = DONE_STATE;
            end else if (row_idx == ROWS) begin
                next_state = COMPUTE_TOTAL;
            end else begin
                next_state = CHECK;
            end
        end

        COMPUTE_TOTAL: begin
            if (cycle_count < MAX_CYCLES) begin
                next_state = COMPUTE_TOTAL;
            end else begin
                // After cycles, calculate total
                if (total == 32'd0) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = OUTPUT_ROWS;
                end
            end
        end

        OUTPUT_ROWS: begin
            if (out_row_idx < ROWS && output_valid) begin
                next_state = OUTPUT_ROWS;
            end else if (out_row_idx < ROWS && !output_valid) begin
                next_state = OUTPUT_ROWS;
            end else begin
                next_state = OUTPUT_COLS;
            end
        end

        OUTPUT_COLS: begin
            if (out_col_idx < COLS && output_valid) begin
                next_state = OUTPUT_COLS;
            end else if (out_col_idx < COLS && !output_valid) begin
                next_state = OUTPUT_COLS;
            end else begin
                next_state = DONE_STATE;
            end
        end

        DONE_STATE: begin
            next_state = IDLE;
        end

        default: next_state = IDLE;
    endcase
end

endmodule