module monopole_magnet_solver (input clk, input rst_n, input start, input [15:0] grid_flat, output reg [3:0] result, output reg done); 
function automatic valid; 
 input [3:0] val; 
 int first, last; 
 begin 
 if (val ==0) return 1; 
 for (int i=3; i>=0; i--) begin 
 if (val & (1<<i)) begin 
 first = i; 
 break; 
 end 
 end 
 for (int i=0; i<4; i++) begin 
 if (val & (1<<i)) begin 
 last = i; 
 break; 
 end 
 end 
 if (first > last) return 1; 
 int mask; 
 mask = (1 << (first - last +1)) -1; 
 mask <<= last; 
 if ((val & mask) == mask) return 1; 
 else return 0; 
 endfunction 
 reg [15:0] grid_reg; 
 reg [2:0] state; 
 localparam IDLE =3'd0, CHECK_ROWS=3'd1, CHECK_COLS=3'd2, CHECK_EMPTY=3'd3, COUNT_COMPONENTS=3'd4, DONE=3'd5, ERROR=3'd6; 
 reg [3:0] result_count; 
 reg error_flag; 
 reg has_empty_row, has_empty_col; 
 reg [3:0] row_val, col_val; 
 reg [1:0] row_cnt, col_cnt; 
 reg [15:0] visited; 
 reg [3:0] count; 
 always @(posedge clk) begin 
 if (!rst_n) begin 
 grid_reg <=0; 
 state <= IDLE; 
 error_flag <=0; 
 has_empty_row <=0; 
 has_empty_col <=0; 
 row_cnt <=0; 
 col_cnt <=0; 
 result_count <=0; 
 visited <=0; 
 count <=0; 
 done <=0; 
 end else begin 
 if (state == IDLE) begin 
 if (start) begin 
 grid_reg <= grid_flat; 
 state <= CHECK_ROWS; 
 row_cnt <=0; 
 end 
 end else if (state == CHECK_ROWS) begin 
 if (row_cnt <4) begin 
 row_val <= {grid_reg[row_cnt*4 +3], grid_reg[row_cnt*4 +2], grid_reg[row_cnt*4 +1], grid_reg[row_cnt*4 +0]}; 
 if (!valid(row_val)) begin 
 error_flag <=1; 
 state <= ERROR; 
 end else begin 
 if (row_val ==0) has_empty_row <=1; 
 row_cnt <= row_cnt +1; 
 if (row_cnt ==4) state <= CHECK_COLS; 
 end 
 end 
 end else if (state == CHECK_COLS) begin 
 if (col_cnt <4) begin 
 col_val <= {grid_reg[col_cnt +12], grid_reg[col_cnt +8], grid_reg[col_cnt +4], grid_reg[col_cnt]}; 
 if (!valid(col_val)) begin 
 error_flag <=1; 
 state <= ERROR; 
 end else begin 
 if (col_val ==0) has_empty_col <=1; 
 col_cnt <= col_cnt +1; 
 if (col_cnt ==4) state <= CHECK_EMPTY; 
 end 
 end else begin 
 if (!error_flag) state <= CHECK_EMPTY; 
 else state <= ERROR; 
 end 
 end else if (state == CHECK_EMPTY) begin 
 if (has_empty_row != has_empty_col) begin 
 error_flag <=1; 
 state <= ERROR; 
 end else begin 
 state <= COUNT_COMPONENTS; 
 end 
 end else if (state == COUNT_COMPONENTS) begin 
 count <= grid_reg[0] + grid_reg[1] + grid_reg[2] + grid_reg[3] + grid_reg[4] + grid_reg[5] + grid_reg[6] + grid_reg[7] + grid_reg[8] + grid_reg[9] + grid_reg[10] + grid_reg[11] + grid_reg[12] + grid_reg[13] + grid_reg[14] + grid_reg[15]; 
 result_count <= count; 
 state <= DONE; 
 end else if (state == DONE || state == ERROR) begin 
 // stay 
 end 
 end 
 end 
 assign result = error_flag ? 4'd15 : result_count; 
 assign done = (state == DONE || state == ERROR); 
 endmodule 
