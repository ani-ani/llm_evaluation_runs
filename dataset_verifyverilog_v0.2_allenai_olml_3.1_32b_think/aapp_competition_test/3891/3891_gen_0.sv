module black_square_center (
    input clk,
    input rst_n, // active low
    input start,
    input cell_valid,
    input cell_is_black,
    input [7:0] row_index,
    input [7:0] col_index,
    output reg [7:0] center_row,
    output reg [7:0] center_col,
    output reg done
);
parameter N_ROWS = 8;
parameter N_COLS = 8;
localparam TOTAL_CELLS = N_ROWS * N_COLS;
localparam IDLE = 3'b000;
localparam SCANNING = 3'b001;
localparam CALCULATING = 3'b010;
localparam DONE_STATE = 3'b100;
reg [7:0] min_row, max_row, min_col, max_col;
reg [7:0] center_row_reg, center_col_reg;
reg [7:0] cell_count;
reg [2:0] state;
reg done_reg;
localparam INIT_MIN = 8'd255;
localparam INIT_MAX = 8'd0;
localparam INIT_COUNT = 8'd0;
assign center_row = center_row_reg;
assign center_col = center_col_reg;
assign done = done_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        min_row <= INIT_MIN;
        max_row <= INIT_MAX;
        min_col <= INIT_MIN;
        max_col <= INIT_MAX;
        cell_count <= INIT_COUNT;
        center_row_reg <= INIT_MIN;
        center_col_reg <= INIT_MIN;
        done_reg <= 1'b0;
    end else begin
        if (start) begin
            if (state == IDLE) begin
                state <= SCANNING;
                min_row <= INIT_MIN;
                max_row <= INIT_MAX;
                min_col <= INIT_MIN;
                max_col <= INIT_MAX;
                cell_count <= INIT_COUNT;
                center_row_reg <= INIT_MIN;
                center_col_reg <= INIT_MIN;
            end else begin
                state <= IDLE;
                min_row <= INIT_MIN;
                max_row <= INIT_MAX;
                min_col <= INIT_MIN;
                max_col <= INIT_MAX;
                cell_count <= INIT_COUNT;
                center_row_reg <= INIT_MIN;
                center_col_reg <= INIT_MIN;
            end
        end else begin
            case (state)
                SCANNING: begin
                    if (cell_valid) begin
                        cell_count <= cell_count + 1;
                        if (cell_is_black) begin
                            min_row <= min(min_row, row_index);
                            max_row <= max(max_row, row_index);
                            min_col <= min(min_col, col_index);
                            max_col <= max(max_col, col_index);
                        end
                    end
                    if (cell_count == TOTAL_CELLS) begin
                        state <= CALCULATING;
                    end
                end
                CALCULATING: begin
                    center_row_reg <= (min_row + max_row) / 2 + 1;
                    center_col_reg <= (min_col + max_col) / 2 + 1;
                    state <= DONE_STATE;
                end
                DONE_STATE: begin
                    done_reg <= 1'b1;
                end
            endcase
        end
    end
end
endmodule
