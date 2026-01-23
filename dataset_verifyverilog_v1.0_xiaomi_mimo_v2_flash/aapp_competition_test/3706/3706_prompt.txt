module karen_and_game (
    input clk, rst_n, start,
    input [7:0] grid_flat [63:0],  // 8x8 grid flattened
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
parameter IDLE = 0, COMP_ROW = 1, COMP_COL = 2, CHECK = 3, 
          COMPUTE_TOTAL = 4, OUTPUT_ROWS = 5, OUTPUT_COLS = 6, DONE = 7;

reg [2:0] state;
reg [2:0] row_idx, col_idx;
reg [DATA_WIDTH-1:0] min_row [0:ROWS-1];
reg [DATA_WIDTH-1:0] min_col [0:COLS-1];
reg [DATA_WIDTH-1:0] temp_min;
reg [31:0] total;
reg [2:0] out_row_idx, out_col_idx;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset logic
        done <= 0;
        error <= 0;
        move_count <= 0;
        output_valid <= 0;
        move_type <= 0;
        move_index <= 0;
        state <= IDLE;
        row_idx <= 0;
        col_idx <= 0;
        temp_min <= 0;
        total <= 0;
        out_row_idx <= 0;
        out_col_idx <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                error <= 0;
                output_valid <= 0;
                if (start) begin
                    state <= COMP_ROW;
                    row_idx <= 0;
                    col_idx <= 0;
                    temp_min <= grid_flat[0];
                end
            end

            COMP_ROW: begin
                if (row_idx < ROWS) begin
                    if (col_idx < COLS) begin
                        // Get grid value using flattened index
                        if (grid_flat[row_idx*COLS + col_idx] < temp_min)
                            temp_min <= grid_flat[row_idx*COLS + col_idx];
                        col_idx <= col_idx + 1;
                    end else begin
                        min_row[row_idx] <= temp_min;
                        row_idx <= row_idx + 1;
                        col_idx <= 0;
                        if (row_idx < ROWS-1)
                            temp_min <= grid_flat[(row_idx+1)*COLS];
                    end
                end else begin
                    state <= COMP_COL;
                    row_idx <= 0;
                    col_idx <= 0;
                    temp_min <= grid_flat[0] - min_row[0];
                end
            end

            COMP_COL: begin
                if (col_idx < COLS) begin
                    if (row_idx < ROWS) begin
                        reg [DATA_WIDTH-1:0] val = grid_flat[row_idx*COLS + col_idx] - min_row[row_idx];
                        if (row_idx == 0)
                            temp_min <= val;
                        else if (val < temp_min)
                            temp_min <= val;
                        row_idx <= row_idx + 1;
                    end else begin
                        min_col[col_idx] <= temp_min;
                        col_idx <= col_idx + 1;
                        row_idx <= 0;
                        if (col_idx < COLS-1)
                            temp_min <= grid_flat[0] - min_row[0];
                    end
                end else begin
                    state <= CHECK;
                    row_idx <= 0;
                    col_idx <= 0;
                end
            end

            CHECK: begin
                if (row_idx < ROWS) begin
                    if (col_idx < COLS) begin
                        reg [DATA_WIDTH-1:0] val = grid_flat[row_idx*COLS + col_idx] - min_row[row_idx] - min_col[col_idx];
                        if (val != 0) begin
                            error <= 1;
                            state <= DONE;
                        end
                        col_idx <= col_idx + 1;
                    end else begin
                        row_idx <= row_idx + 1;
                        col_idx <= 0;
                    end
                end else begin
                    state <= COMPUTE_TOTAL;
                end
            end

            COMPUTE_TOTAL: begin
                total <= 0;
                for (int i = 0; i < ROWS; i = i + 1)
                    total <= total + min_row[i];
                for (int j = 0; j < COLS; j = j + 1)
                    total <= total + min_col[j];
                move_count <= total;
                if (total == 0)
                    state <= DONE;
                else begin
                    state <= OUTPUT_ROWS;
                    out_row_idx <= 0;
                    out_col_idx <= 0;
                end
            end

            OUTPUT_ROWS: begin
                if (out_row_idx < ROWS) begin
                    if (min_row[out_row_idx] > 0) begin
                        output_valid <= 1;
                        move_type <= 0;  // row
                        move_index <= out_row_idx + 1;
                        min_row[out_row_idx] <= min_row[out_row_idx] - 1;
                    end else begin
                        out_row_idx <= out_row_idx + 1;
                        output_valid <= 0;
                    end
                end else begin
                    state <= OUTPUT_COLS;
                    output_valid <= 0;
                end
            end

            OUTPUT_COLS: begin
                if (out_col_idx < COLS) begin
                    if (min_col[out_col_idx] > 0) begin
                        output_valid <= 1;
                        move_type <= 1;  // column
                        move_index <= out_col_idx + 1;
                        min_col[out_col_idx] <= min_col[out_col_idx] - 1;
                    end else begin
                        out_col_idx <= out_col_idx + 1;
                        output_valid <= 0;
                    end
                end else begin
                    state <= DONE;
                    output_valid <= 0;
                end
            end

            DONE: begin
                done <= 1;
            end
        endcase
    end
end

endmodule