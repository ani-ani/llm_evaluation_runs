module left_insertion (
   input clk,
   input rst_n,
   input start,
   input [7:0] value,
   input [2:0] array_size,
   input [7:0] array_data [0:7],
   output reg [3:0] result,
   output reg done
);

reg [3:0] low, high;
reg [1:0] state;
reg update_low;

always @(posedge clk) begin
   if (!rst_n) begin
      low <= 4'b0;
      high <= 4'b0;
      state <= 2'b00;
      update_low <= 1'b0;
      result <= 4'b0;
      done <= 1'b0;
   end else begin
      if (state == 2'b00) begin
         if (start) begin
            low <= 4'b0;
            high <= array_size;
            state <= 2'b01;
         end else begin
            state <= 2'b00;
         end
      end else if (state == 2'b01) begin
         reg [3:0] mid;
         mid = low + high;
         mid = mid >> 1;
         update_low <= (value > array_data[mid]);
         state <= 2'b10;
      end else if (state == 2'b10) begin
         reg [3:0] mid, new_low, new_high;
         mid = (low + high) >> 1;
         if (update_low) begin
            new_low = mid + 1;
            new_high = high;
         end else begin
            new_low = low;
            new_high = mid;
         end
         if (new_low >= new_high) begin
            state <= 2'b11;
            result <= new_low;
            done <= 1'b1;
            low <= new_low;
            high <= new_high;
         end else begin
            state <= 2'b01;
            low <= new_low;
            high <= new_high;
         end
      end else if (state == 2'b11) begin
         state <= 2'b11;
         done <= 1'b1;
      end
   end
endmodule
