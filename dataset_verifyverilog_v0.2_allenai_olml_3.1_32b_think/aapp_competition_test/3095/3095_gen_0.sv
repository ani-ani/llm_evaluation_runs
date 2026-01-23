module extremely_cool_checker (
   input clk,
   input rst_n, // active low
   input start,
   input [3:0] rows,
   input [3:0] cols,
   input [7:0] matrix_data [0:63],
   output reg is_cool,
   output reg done
);

parameter IDLE = 2'b00;
parameter CHECKING = 2'b01;
parameter DONE = 2'b10;

reg [1:0] state;
reg [3:0] target_rows, target_cols;
reg [2:0] max_r, max_c;
reg [2:0] current_r, current_c;
reg fail_reg;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      target_rows <= 4'd0;
      target_cols <= 4'd0;
      max_r <= 3'd0;
      max_c <= 3'd0;
      current_r <= 3'd0;
      current_c <= 3'd0;
      fail_reg <= 1'b1;
      is_cool <= 1'b0;
      done <= 1'b0;
   end else begin
      if (state == IDLE) begin
          if (start) begin
              if (rows < 2 || cols < 2) begin
                  state <= DONE;
                  is_cool <= 1'b1;
                  done <= 1'b1;
              end else begin
                  state <= CHECKING;
                  target_rows <= rows;
                  target_cols <= cols;
                  max_r <= rows - 2;
                  max_c <= cols - 2;
                  current_r <= 3'd0;
                  current_c <= 3'd0;
              end
          end
          done <= 1'b0;
          is_cool <= 1'b0;
      end else if (state == CHECKING) begin
          integer index_a = current_r * 8 + current_c;
          integer index_b = index_a + 1;
          integer index_c_val = (current_r + 1) * 8 + current_c;
          integer index_d = index_c_val + 1;
          signed [7:0] a = matrix_data[index_a];
          signed [7:0] b = matrix_data[index_b];
          signed [7:0] c_val = matrix_data[index_c_val];
          signed [7:0] d = matrix_data[index_d];
          if ( (a + d) > (b + c_val) ) begin
              fail_reg <= 1'b0;
          end
          if (current_c < max_c) begin
              current_c <= current_c + 1;
          end else begin
              current_c <= 3'd0;
              if (current_r < max_r) begin
                  current_r <= current_r + 1;
              end else begin
                  state <= DONE;
                  is_cool <= !fail_reg;
                  done <= 1'b1;
              end
          end
          done <= 1'b0;
          is_cool <= 1'b0;
      end else if (state == DONE) begin
          done <= 1'b1;
      end
   end
endmodule