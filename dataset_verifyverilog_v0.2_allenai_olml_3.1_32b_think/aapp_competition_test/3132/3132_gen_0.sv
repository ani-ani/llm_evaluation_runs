module building_detector (
input clk,
input rst_n,
input start,
input [15:0] grid_row_0,
input [15:0] grid_row_1,
input [15:0] grid_row_2,
input [15:0] grid_row_3,
input [15:0] grid_row_4,
input [15:0] grid_row_5,
input [15:0] grid_row_6,
input [15:0] grid_row_7,
input [15:0] grid_row_8,
input [15:0] grid_row_9,
input [15:0] grid_row_10,
input [15:0] grid_row_11,
input [15:0] grid_row_12,
input [15:0] grid_row_13,
input [15:0] grid_row_14,
input [15:0] grid_row_15,
output reg [3:0] building1_row,
output reg [3:0] building1_col,
output reg [3:0] building1_size,
output reg [3:0] building2_row,
output reg [3:0] building2_col,
output reg [3:0] building2_size,
output reg done
reg [3:0] building1_row, building1_col, building1_size;
reg [3:0] building2_row, building2_col, building2_size;
reg [2:0] state;
reg [3:0] row_scan, col_scan;
always @(negedge rst_n) begin
    building1_row <= 4'd0;
    building1_col <= 4'd0;
    building1_size <= 4'd0;
    building2_row <= 4'd0;
    building2_col <= 4'd0;
    building2_size <= 4'd0;
    state <= 2'd0;
    row_scan <= 4'd0;
    col_scan <= 4'd0;
    done <= 1'b0;
end
always @(posedge clk) begin
case (state)
    2'd0: // IDLE
        if (start == 1'b1) begin
            state <= 1'd1; // move to SCAN
        end
        done <= 1'b0;
    endcase

    2'd1: // SCAN
        // Determine the current bit
        wire bit;
case (row_scan)
    4'd0: bit = grid_row_0[col_scan];
    4'd1: bit = grid_row_1[col_scan];
    4'd2: bit = grid_row_2[col_scan];
    4'd3: bit = grid_row_3[col_scan];
    4'd4: bit = grid_row_4[col_scan];
    4'd5: bit = grid_row_5[col_scan];
    4'd6: bit = grid_row_6[col_scan];
    4'd7: bit = grid_row_7[col_scan];
    4'd8: bit = grid_row_8[col_scan];
    4'd9: bit = grid_row_9[col_scan];
    4'd10: bit = grid_row_10[col_scan];
    4'd11: bit = grid_row_11[col_scan];
    4'd12: bit = grid_row_12[col_scan];
    4'd13: bit = grid_row_13[col_scan];
    4'd14: bit = grid_row_14[col_scan];
    4'd15: bit = grid_row_15[col_scan];
endcase

if (bit == 1'b1) begin
    if (building1_size == 4'd0) begin // Assign to first building
        building1_row <= row_scan;
        building1_col <= col_scan;
        building1_size <= 4'd1;
    end else if (building2_size == 4'd0) begin // Assign to second
        building2_row <= row_scan;
        building2_col <= col_scan;
        building2_size <= 4'd1;
        if (building1_size !=4'd0 && building2_size !=4'd0) begin
            state <= 2'd2; // Move to OUTPUT
        end
    end
end

if (col_scan < 15) begin
    col_scan <= col_scan + 1;
end else begin
    col_scan <= 4'd0;
    if (row_scan < 15) begin
        row_scan <= row_scan + 1;
    end else begin
        if (building1_size == 4'd0 || building2_size == 4'd0) begin
            row_scan <= 4'd0;
            col_scan <= 4'd0;
        end
    end
end
endcase

2'd2: // OUTPUT
    done <= 1'b1;
endcase
endcase
end
endmodule