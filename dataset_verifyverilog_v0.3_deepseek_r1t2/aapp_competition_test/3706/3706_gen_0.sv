module karen_and_game (
    input clk, rst_n, start,
    input [7:0] grid_flat [63:0],
    output reg done, error,
    output reg [31:0] move_count,
    output reg output_valid, move_type,
    output reg [3:0] move_index
);

// State declarations
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMP_ROW = 3'd1;
localparam [2:0] COMP_COL = 3'd2;
localparam [2:0] CHECK = 3'd3;
localparam [2:0] COMPUTE_TOTAL = 3'd4;
localparam [2:0] OUTPUT_ROWS = 3'd5;
localparam [2:0] OUTPUT_COLS = 3'd6;
localparam [2:0] DONE_STATE = 3'd7;

reg [2:0] state, next_state;
reg [2:0] row_idx, col_idx;
reg [7:0] min_row [0:7];
reg [7:0] min_col [0:7];
reg [7:0] temp_min;
reg [31:0] total;
reg [2:0] out_row_idx, out_col_idx;
integer i;

// Sequential logic
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
        temp_min <= 8'd0;
        total <= 32'd0;
        out_row_idx <= 3'd0;
        out_col_idx <= 3'd0;
        
        // Initialize arrays
        for (i = 0; i < 8; i = i + 1) begin
            min_row[i] <= 8'd0;
            min_col[i] <= 8'd0;
        end
    end
    else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                error <= 1'b0;
                if (start) begin
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                    temp_min <= grid_flat[0];
                end
            end
            
            COMP_ROW: begin
                if (row_idx < 3'd7) begin
                    if (col_idx < 3'd7) begin
                        if (grid_flat[{row_idx, 3'b0} + col_idx] < temp_min)
                            temp_min <= grid_flat[{row_idx, 3'b0} + col_idx];
                        col_idx <= col_idx + 3'd1;
                    end
                    else begin
                        min_row[row_idx] <= temp_min;
                        row_idx <= row_idx + 3'd1;
                        col_idx <= 3'd0;
                        if (row_idx < 3'd7)
                            temp_min <= grid_flat[{row_idx + 3'd1, 3'b0}];
                    end
                end
                else begin
                    min_row[7] <= temp_min;
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                    temp_min <= grid_flat[0] - min_row[0];
                end
            end
            
            COMP_COL: begin
                if (col_idx < 3'd7) begin
                    if (row_idx < 3'd7) begin
                        if ((grid_flat[{row_idx, 3'b0} + col_idx] - min_row[row_idx]) < temp_min)
                            temp_min <= grid_flat[{row_idx, 3'b0} + col_idx] - min_row[row_idx];
                        row_idx <= row_idx + 3'd1;
                    end
                    else begin
                        min_col[col_idx] <= temp_min;
                        col_idx <= col_idx + 3'd1;
                        row_idx <= 3'd0;
                        if (col_idx < 3'd7)
                            temp_min <= grid_flat[col_idx + 3'd1] - min_row[0];
                    end
                end
                else begin
                    min_col[7] <= temp_min;
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                end
            end
            
            CHECK: begin
                if (row_idx < 3'd7) begin
                    if (col_idx < 3'd7) begin
                        if ((grid_flat[{row_idx, 3'b0} + col_idx] - min_row[row_idx] - min_col[col_idx]) != 8'd0)
                            error <= 1'b1;
                        col_idx <= col_idx + 3'd1;
                    end
                    else begin
                        row_idx <= row_idx + 3'd1;
                        col_idx <= 3'd0;
                    end
                end
            end
            
            COMPUTE_TOTAL: begin
                total <= 32'd0;
                for (i = 0; i < 8; i = i + 1)
                    total <= total + min_row[i] + min_col[i];
                move_count <= total;
                out_row_idx <= 3'd0;
                out_col_idx <= 3'd0;
            end
            
            OUTPUT_ROWS: begin
                output_valid <= 1'b0;
                if (out_row_idx < 3'd7) begin
                    if (min_row[out_row_idx] != 8'd0) begin
                        output_valid <= 1'b1;
                        move_type <= 1'b0;
                        move_index <= {1'b0, out_row_idx} + 4'd1;
                        min_row[out_row_idx] <= min_row[out_row_idx] - 8'd1;
                    end
                    else begin
                        out_row_idx <= out_row_idx + 3'd1;
                    end
                end
                else begin
                    out_col_idx <= 3'd0;
                end
            end
            
            OUTPUT_COLS: begin
                output_valid <= 1'b0;
                if (out_col_idx < 3'd7) begin
                    if (min_col[out_col_idx] != 8'd0) begin
                        output_valid <= 1'b1;
                        move_type <= 1'b1;
                        move_index <= {1'b0, out_col_idx} + 4'd1;
                        min_col[out_col_idx] <= min_col[out_col_idx] - 8'd1;
                    end
                    else begin
                        out_col_idx <= out_col_idx + 3'd1;
                    end
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE:          if (start) next_state = COMP_ROW;
        COMP_ROW:      if (row_idx == 3'd7 && col_idx == 3'd7) next_state = COMP_COL;
        COMP_COL:      if (col_idx == 3'd7 && row_idx == 3'd7) next_state = CHECK;
        CHECK:         if (row_idx == 3'd7 && col_idx == 3'd7) next_state = error ? DONE_STATE : COMPUTE_TOTAL;
        COMPUTE_TOTAL: next_state = (total == 32'd0) ? DONE_STATE : OUTPUT_ROWS;
        OUTPUT_ROWS:   if (out_row_idx == 3'd7 && min_row[7] == 8'd0) next_state = OUTPUT_COLS;
        OUTPUT_COLS:   if (out_col_idx == 3'd7 && min_col[7] == 8'd0) next_state = DONE_STATE;
        DONE_STATE:    next_state = IDLE;
        default:       next_state = IDLE;
    endcase
end

endmodule