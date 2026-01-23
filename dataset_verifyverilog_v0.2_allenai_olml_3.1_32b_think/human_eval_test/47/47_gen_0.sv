module median_calculator (input reg clk, input reg rst_n, input reg start, input reg [2:0] num_elements, input reg [7:0] data_in, input reg data_valid, output reg [15:0] result, output reg done, output reg data_ready);
reg [7:0] data_array [7:0];
reg [2:0] count;
reg [3:0] target_count;
reg [2:0] sort_cycle;
reg [2:0] state;
localparam IDLE = 3'd0;
localparam COLLECT = 3'd1;
localparam SORTING = 3'd2;
localparam CALCULATE = 3'd3;
localparam DONE_STATE = 3'd4;
assign result = 16'd0;
assign done = 1'b0;
assign data_ready = 1'b0;
always @(negedge rst_n or posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      target_count <= 4'd0;
      count <= 3'd0;
      sort_cycle <= 3'd0;
      data_array <= 8'b0;
      result <= 16'd0;
      done <=1'b0;
      data_ready <=1'b0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            target_count <= num_elements;
            count <=3'd0;
            sort_cycle <=3'd0;
            data_array <=8'b0;
            data_ready <=1'b1; // Ready to accept data
            state <= COLLECT;
         end else begin
            data_ready <=1'b0;
         end
      end else if (state == COLLECT) begin
         if (data_valid) begin
            data_array[count] <= data_in;
            count <= count +1;
         end
         data_ready <= (count < target_count);
         if (count == target_count) begin
            // Fill remaining elements with -128
            if (target_count <=7) data_array[7] <= 8'b10000000;
            if (target_count <=6) data_array[6] <= 8'b10000000;
            if (target_count <=5) data_array[5] <= 8'b10000000;
            if (target_count <=4) data_array[4] <= 8'b10000000;
            if (target_count <=3) data_array[3] <= 8'b10000000;
            if (target_count <=2) data_array[2] <= 8'b10000000;
            if (target_count <=1) data_array[1] <= 8'b10000000;
            state <= SORTING;
         end
      end else if (state == SORTING) begin
         if (sort_cycle <7) begin
            // Perform sorting step
            if (sort_cycle %2 ==0) begin // even pass: swap even pairs
               if (data_array[0] > data_array[1]) begin
                  data_array[0] <= data_array[1];
                  data_array[1] <= data_array[0];
               end
               if (data_array[2] > data_array[3]) begin
                  data_array[2] <= data_array[3];
                  data_array[3] <= data_array[2];
               end
               if (data_array[4] > data_array[5]) begin
                  data_array[4] <= data_array[5];
                  data_array[5] <= data_array[4];
               end
               if (data_array[6] > data_array[7]) begin
                  data_array[6] <= data_array[7];
                  data_array[7] <= data_array[6];
               end
            end else begin // odd pass: swap odd pairs
               if (data_array[1] > data_array[2]) begin
                  data_array[1] <= data_array[2];
                  data_array[2] <= data_array[1];
               end
               if (data_array[3] > data_array[4]) begin
                  data_array[3] <= data_array[4];
                  data_array[4] <= data_array[3];
               end
               if (data_array[5] > data_array[6]) begin
                  data_array[5] <= data_array[6];
                  data_array[6] <= data_array[5];
               end
            end
            sort_cycle <= sort_cycle +1;
         end else begin
            // Move to calculate
            state <= CALCULATE;
         end
      end else if (state == CALCULATE) begin
         // Compute median
         integer mid;
         mid = target_count /2;
         if (target_count %2 ==1) begin
            // Odd: take middle element
            int idx;
            idx = (8 - target_count) + mid;
            result <= {{data_array[idx], 8'd0}, 8'd0}; // Zero extension, may be incorrect for negatives
         end else begin
            int idx1, idx2;
            idx1 = (8 - target_count) + mid -1;
            idx2 = (8 - target_count) + mid;
            result <= (data_array[idx1] + data_array[idx2] +1) >>1;
         end
         state <= DONE_STATE;
      end else if (state == DONE_STATE) begin
         // Stay in done until next start
      end
   end
end
assign done = (state == DONE_STATE);
endmodule