module table_sorter (input clk, input rst_n, input start, input [2:0] row_idx, input [7:0] col_val_0, col_val_1, col_val_2, col_val_3, col_val_4, col_val_5, col_val_6, col_val_7, output reg result, output reg done);

reg [3:0] row_status;
reg [7:0] table [3][8];
reg [5:0] pair_idx;
reg [2:0] row_idx_proc;
reg pair_valid;
reg found_solution;
reg [31:0] timer;
reg [1:0] state;

always @(posedge clk) if (!rst_n) begin
    row_status <= 0;
table <= 0;
pair_idx <= 0;
row_idx_proc <= 0;
pair_valid <= 1;
found_solution <= 0;
timer <= 0;
state <= 0;
result <= 0;
done <= 0;
end else begin
    if (state == 0) begin
        if (row_idx < 4) begin
            table[row_idx] <= {col_val_0, col_val_1, col_val_2, col_val_3, col_val_4, col_val_5, col_val_6, col_val_7};
            row_status[row_idx] <= 1;
        end
        if (start == 1 && row_status == 4'b1111) begin
            state <= 1;
        end
    end else if (state == 1) begin
        if (timer > 1024) begin
            result <= 0;
done <= 1;
state <= 2;
        end else begin
            timer <= timer + 1;
        end
        if (found_solution) begin
            result <= 1;
done <= 1;
state <= 2;
        end else if (pair_idx == 36) begin
            result <= 0;
done <= 1;
state <= 2;
        end
    end
end

localparam c1_start = {0, 8, 15, 21, 26, 30, 33, 35};
wire [5:0] c1, c2;
assign c1 = 0, c2 = 0;

if (pair_idx >= c1_start[0] && pair_idx < c1_start[0] + 8) begin
    c1 = 0;
c2 = pair_idx - c1_start[0];
end else if (pair_idx >= c1_start[1] && pair_idx < c1_start[1] + 7) begin
    c1 = 1;
c2 = 1 + (pair_idx - c1_start[1]);
end else if (pair_idx >= c1_start[2] && pair_idx < c1_start[2] + 6) begin
    c1 = 2;
c2 = 2 + (pair_idx - c1_start[2]);
end else if (pair_idx >= c1_start[3] && pair_idx < c1_start[3] + 5) begin
    c1 = 3;
c2 = 3 + (pair_idx - c1_start[3]);
end else if (pair_idx >= c1_start[4] && pair_idx < c1_start[4] + 4) begin
    c1 = 4;
c2 = 4 + (pair_idx - c1_start[4]);
end else if (pair_idx >= c1_start[5] && pair_idx < c1_start[5] + 3) begin
    c1 = 5;
c2 = 5 + (pair_idx - c1_start[5]);
end else if (pair_idx >= c1_start[6] && pair_idx < c1_start[6] + 2) begin
    c1 = 6;
c2 = 6 + (pair_idx - c1_start[6]);
end else if (pair_idx >= c1_start[7] && pair_idx < c1_start[7] + 1) begin
    c1 = 7;
c2 = 7 + (pair_idx - c1_start[7]);
end

endmodule