module first_non_repeating_char (
output reg [7:0] result,
output reg found,
output reg done,
input clk,
input rst_n, // active low
input start,
input [7:0] char_array [7:0]
);

parameter IDLE = 2'd0,
COUNT_CHARS = 2'd1,
SEARCH_RESULT = 2'd2,
COMPLETE = 2'd3;

reg [1:0] state;
reg [7:0][7:0] stored_char_array;
reg [3:0] count [0:7]; // 8 positions
reg [2:0] i_idx;
reg [3:0] j_idx;
reg [2:0] search_idx;
reg [7:0] result_reg;
reg found_reg;
reg done_reg;

always @(negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      stored_char_array <= 8'b0; // Initialize to zero, but it's an array of 8x8, so this may not fully initialize? But in Verilog, it will set all elements to 0.
      i_idx <= 3'd0;
      j_idx <= 4'd0;
      search_idx <= 3'd0;
      result_reg <= 8'b0;
      found_reg <=0;
      done_reg <=0;
   end
end

always @(posedge clk) begin
   if (state == IDLE) begin
      if (start) begin
         stored_char_array <= char_array;
         state <= COUNT_CHARS;
      end
   end else if (state == COUNT_CHARS) begin
      if (i_idx < 8) begin
         if (j_idx == 8) begin
            if (i_idx < 7) begin
               i_idx <= i_idx + 1;
               j_idx <= 0;
               count[i_idx] <= 1;
            end else begin
               i_idx <= 8;
               j_idx <= 0;
            end
         end else begin
            if (j_idx == 0) begin
               count[i_idx] <= 1;
               j_idx <= 1;
            end else begin
               if (j_idx != i_idx) begin
                  if (stored_char_array[j_idx] == stored_char_array[i_idx]) begin
                     count[i_idx] <= count[i_idx] + 1;
                  end
               end
               j_idx <= j_idx + 1;
            end
         end
      end else begin
         state <= SEARCH_RESULT;
      end
   end else if (state == SEARCH_RESULT) begin
      if (search_idx < 8) begin
         if (count[search_idx] == 1) begin
            result_reg <= stored_char_array[search_idx];
            found_reg <= 1;
            state <= COMPLETE;
         end else begin
            search_idx <= search_idx + 1;
         end
      end else begin
         result_reg <= 8'b0;
         found_reg <= 0;
         state <= COMPLETE;
      end
   end else if (state == COMPLETE) begin
      done_reg <= 1;
   end
end

assign result = result_reg;
assign found = found_reg;
assign done = done_reg;

endmodule