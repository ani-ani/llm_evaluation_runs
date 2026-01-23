module find_closest_elements (
   input clk,
   input rst_n,
   input start,
   input [7:0] data_in_valid,
   input [7:0][31:0] numbers,
   output reg [31:0] smaller,
   output reg [31:0] larger,
   output reg done,
   output reg valid
);

parameter N = 8;
parameter IDLE = 3'd0;
parameter INIT = 3'd1;
parameter SORTING = 3'd2;
parameter COMPARING = 3'd3;
parameter DONE = 3'd4;

reg [31:0] stored_numbers [7:0];
reg [31:0] arr [7:0];
reg [2:0] state;
reg [2:0] outer_count;
reg [2:0] inner_count;
reg [2:0] compare_count;
reg [31:0] min_diff;
reg [31:0] smaller_pair;
reg [31:0] larger_pair;
reg [31:0] temp;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      stored_numbers <= {8{32'b0}};
      arr <= {8{32'b0}};
      outer_count <= 0;
      inner_count <=0;
      compare_count <=0;
      min_diff <= 32'hFFFF_FFFF;
      smaller_pair <=32'b0;
      larger_pair <=32'b0;
      temp <=32'b0;
   end else begin
      if (state == IDLE) begin
         if (start && data_in_valid[0]) begin
             stored_numbers <= numbers;
             state <= INIT;
         end else begin
             state <= IDLE;
         end
      end else if (state == INIT) begin
         arr <= stored_numbers;
         outer_count <=0;
         inner_count <=0;
         state <= SORTING;
      end else if (state == SORTING) begin
         if (outer_count < 7) begin
             if (inner_count < (6 - outer_count)) begin
                 if (arr[inner_count] > arr[inner_count +1]) begin
                     temp = arr[inner_count];
                     arr[inner_count] = arr[inner_count +1];
                     arr[inner_count +1] = temp;
                 end
                 inner_count <= inner_count +1;
             end else begin
                 outer_count <= outer_count +1;
                 inner_count <=0;
             end
         end else begin
             state <= COMPARING;
             compare_count <=0;
             min_diff <= 32'hFFFF_FFFF;
             smaller_pair <=32'b0;
             larger_pair <=32'b0;
         end
      end else if (state == COMPARING) begin
         if (compare_count < 7) begin
             min_diff_temp = arr[compare_count +1] - arr[compare_count];
             if (min_diff_temp < min_diff) begin
                 min_diff = min_diff_temp;
                 smaller_pair = arr[compare_count];
                 larger_pair = arr[compare_count +1];
             end
             compare_count <= compare_count +1;
         end else begin
             state <= DONE;
             smaller <= smaller_pair;
             larger <= larger_pair;
             done <=1;
             valid <=1;
         end
      end else if (state == DONE) begin
         done <=1;
         valid <=1;
      end
   end
end