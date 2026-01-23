module figurine_4pack (
   input clk,
   input rst_n,
   input start,
   input [7:0] w0, w1, w2, w3,
   output reg [13:0] max_weight,
   output reg [13:0] min_weight,
   output reg [13:0] distinct_weights_count,
   output reg [31:0] expected_weight,
   output reg done
);

reg [13:0] max_temp, min_temp;
reg [31:0] expected_temp, distinct_count_temp;
reg [1023:0] seen;
reg [31:0] enumerate_counter;
reg [2:0] state;

always @(posedge clk) begin
   if (!rst_n) begin
      max_weight <= 0;
      min_weight <= 0;
      distinct_weights_count <= 0;
      expected_weight <= 0;
      done <= 0;
      max_temp <= 0;
      min_temp <= 0;
      expected_temp <= 0;
      distinct_count_temp <= 0;
      seen <= 0;
      enumerate_counter <= 0;
      state <= 0;
   end else begin
      case (state)
         0: begin
            if (start) begin
               reg [7:0] max_w = w0;
               if (w1 > max_w) max_w = w1;
               if (w2 > max_w) max_w = w2;
               if (w3 > max_w) max_w = w3;
               max_temp = max_w * 4;
               reg [7:0] min_w = w0;
               if (w1 < min_w) min_w = w1;
               if (w2 < min_w) min_w = w2;
               if (w3 < min_w) min_w = w3;
               min_temp = min_w * 4;
               expected_temp = (w0 + w1 + w2 + w3) * 16384;
               state <= 1;
            end
         end

         1: begin
            if (enumerate_counter < 256) begin
               int idx = enumerate_counter + 0;
               int d0 = idx & 3;
               int temp = idx >> 2;
               int d1 = temp & 3;
               temp = temp >> 2;
               int d2 = temp & 3;
               int d3 = temp & 3;
               int sum = w[d0] + w[d1] + w[d2] + w[d3];
               if (!seen[sum]) begin
                  distinct_count_temp <= distinct_count_temp + 1;
               end
               seen[sum] <= 1;
            end

            if (enumerate_counter + 1 < 256) begin
               int idx = enumerate_counter + 1;
               int d0 = idx & 3;
               int temp = idx >> 2;
               int d1 = temp & 3;
               temp = temp >> 2;
               int d2 = temp & 3;
               int d3 = temp & 3;
               int sum = w[d0] + w[d1] + w[d2] + w[d3];
               if (!seen[sum]) begin
                  distinct_count_temp <= distinct_count_temp + 1;
               end
               seen[sum] <= 1;
            end

            if (enumerate_counter + 2 < 256) begin
               int idx = enumerate_counter + 2;
               int d0 = idx & 3;
               int temp = idx >> 2;
               int d1 = temp & 3;
               temp = temp >> 2;
               int d2 = temp & 3;
               int d3 = temp & 3;
               int sum = w[d0] + w[d1] + w[d2] + w[d3];
               if (!seen[sum]) begin
                  distinct_count_temp <= distinct_count_temp + 1;
               end
               seen[sum] <= 1;
            end

            if (enumerate_counter + 3 < 256) begin
               int idx = enumerate_counter + 3;
               int d0 = idx & 3;
               int temp = idx >> 2;
               int d1 = temp & 3;
               temp = temp >> 2;
               int d2 = temp & 3;
               int d3 = temp & 3;
               int sum = w[d0] + w[d1] + w[d2] + w[d3];
               if (!seen[sum]) begin
                  distinct_count_temp <= distinct_count_temp + 1;
               end
               seen[sum] <= 1;
            end

            if (enumerate_counter + 4 > 256) begin
               enumerate_counter <= 256;
               state <= 2;
               max_weight <= max_temp;
               min_weight <= min_temp;
               distinct_weights_count <= distinct_count_temp;
               expected_weight <= expected_temp;
               done <= 1;
            end else begin
               enumerate_counter <= enumerate_counter + 4;
               state <= 1;
            end
         end

         2: begin
         end

      endcase
   end
end
endmodule