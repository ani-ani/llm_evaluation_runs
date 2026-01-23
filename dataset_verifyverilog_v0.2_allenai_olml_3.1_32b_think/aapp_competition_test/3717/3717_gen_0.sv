module find_common_point (
   input clk,
   input rst_n,
   input start,
   input signed [7:0] x1_in, y1_in, x2_in, y2_in,
   input [2:0] n,
   output reg [7:0] result_x,
   output reg [7:0] result_y,
   output reg done,
   output reg valid
);

localparam IDLE = 3'd0,
LOAD_RECTS = 3'd1,
COMPUTE_PREFIX = 3'd2,
COMPUTE_SUFFIX = 3'd3,
CHECK_EXCLUSION = 3'd4,
DONE = 3'd5;

reg [2:0] state = IDLE;
reg [7:0] n_val = 0;
reg [2:0] load_count = 0;
reg [2:0] prefix_idx = 0;
reg [2:0] suffix_idx = 0;
reg [2:0] exclusion_idx = 0;

reg signed [7:0] rect_buf [7:0][4] = 0;
reg signed [7:0] prefix_max_x1 [7:0] = 0;
reg signed [7:0] prefix_max_y1 [7:0] = 0;
reg signed [7:0] prefix_min_x2 [7:0] = 0;
reg signed [7:0] prefix_min_y2 [7:0] = 0;
reg signed [7:0] suffix_max_x1 [7:0] = 0;
reg signed [7:0] suffix_max_y1 [7:0] = 0;
reg signed [7:0] suffix_min_x2 [7:0] = 0;
reg signed [7:0] suffix_min_y2 [7:0] = 0;
reg signed [7:0] ex_max_x1, ex_max_y1, ex_min_x2, ex_min_y2;
reg [7:0] result_x = 0;
reg [7:0] result_y = 0;
reg done = 0;
reg valid = 0;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      n_val <= 8'd0;
      load_count <= 8'd0;
      prefix_idx <= 8'd0;
      suffix_idx <= 8'd0;
      exclusion_idx <= 8'd0;
      result_x <= 8'd0;
      result_y <= 8'd0;
      done <= 1'b0;
      valid <= 1'b0;
   end else begin
      case (state)
         IDLE: 
            if (start) begin
               state <= LOAD_RECTS;
               n_val <= n;
               load_count <= 8'd0;
            end
         LOAD_RECTS: 
            if (load_count < n_val) begin
               rect_buf[load_count][0] <= x1_in;
               rect_buf[load_count][1] <= y1_in;
               rect_buf[load_count][2] <= x2_in;
               rect_buf[load_count][3] <= y2_in;
               load_count <= load_count + 1;
            end else begin
               state <= COMPUTE_PREFIX;
               load_count <= 8'd0;
            end
         COMPUTE_PREFIX: 
            if (prefix_idx < n_val) begin
               if (prefix_idx == 8'd0) begin
                  prefix_max_x1[prefix_idx] <= rect_buf[0][0];
                  prefix_max_y1[prefix_idx] <= rect_buf[0][1];
                  prefix_min_x2[prefix_idx] <= rect_buf[0][2];
                  prefix_min_y2[prefix_idx] <= rect_buf[0][3];
               end else begin
                  prefix_max_x1[prefix_idx] <= (prefix_max_x1[prefix_idx-1] > rect_buf[prefix_idx][0]) ? prefix_max_x1[prefix_idx-1] : rect_buf[prefix_idx][0];
                  prefix_max_y1[prefix_idx] <= (prefix_max_y1[prefix_idx-1] > rect_buf[prefix_idx][1]) ? prefix_max_y1[prefix_idx-1] : rect_buf[prefix_idx][1];
                  prefix_min_x2[prefix_idx] <= (prefix_min_x2[prefix_idx-1] < rect_buf[prefix_idx][2]) ? prefix_min_x2[prefix_idx-1] : rect_buf[prefix_idx][2];
                  prefix_min_y2[prefix_idx] <= (prefix_min_y2[prefix_idx-1] < rect_buf[prefix_idx][3]) ? prefix_min_y2[prefix_idx-1] : rect_buf[prefix_idx][3];
               end
               prefix_idx <= prefix_idx + 1;
            end else begin
               state <= COMPUTE_SUFFIX;
               prefix_idx <= 8'd0;
            end
         COMPUTE_SUFFIX: 
            if (suffix_idx > n_val-1) begin
               state <= COMPUTE_SUFFIX;
            end else if (suffix_idx == n_val-1) begin
               if (n_val > 0) begin
                  suffix_max_x1[suffix_idx] <= rect_buf[n_val-1][0];
                  suffix_max_y1[suffix_idx] <= rect_buf[n_val-1][1];
                  suffix_min_x2[suffix_idx] <= rect_buf[n_val-1][2];
                  suffix_min_y2[suffix_idx] <= rect_buf[n_val-1][3];
               end
               suffix_idx <= n_val - 2;
            end else if (suffix_idx >= 0) begin
               suffix_max_x1[suffix_idx] <= (rect_buf[suffix_idx][0] > suffix_max_x1[suffix_idx+1]) ? rect_buf[suffix_idx][0] : suffix_max_x1[suffix_idx+1];
               suffix_max_y1[suffix_idx] <= (rect_buf[suffix_idx][1] > suffix_max_y1[suffix_idx+1]) ? rect_buf[suffix_idx][1] : suffix_max_y1[suffix_idx+1];
               suffix_min_x2[suffix_idx] <= (rect_buf[suffix_idx][2] < suffix_min_x2[suffix_idx+1]) ? rect_buf[suffix_idx][2] : suffix_min_x2[suffix_idx+1];
               suffix_min_y2[suffix_idx] <= (rect_buf[suffix_idx][3] < suffix_min_y2[suffix_idx+1]) ? rect_buf[suffix_idx][3] : suffix_min_y2[suffix_idx+1];
               suffix_idx <= suffix_idx - 1;
            end else begin
               state <= CHECK_EXCLUSION;
            end
         CHECK_EXCLUSION: 
            if (exclusion_idx < n_val) begin
               if (exclusion_idx == 8'd0) begin
                  if (n_val > 1) begin
                     ex_max_x1 <= suffix_max_x1[1];
                     ex_max_y1 <= suffix_max_y1[1];
                     ex_min_x2 <= suffix_min_x2[1];
                     ex_min_y2 <= suffix_min_y2[1];
                  end
               end else if (exclusion_idx == n_val-1) begin
                  ex_max_x1 <= prefix_max_x1[exclusion_idx-1];
                  ex_max_y1 <= prefix_max_y1[exclusion_idx-1];
                  ex_min_x2 <= prefix_min_x2[exclusion_idx-1];
                  ex_min_y2 <= prefix_min_y2[exclusion_idx-1];
               end else begin
                  ex_max_x1 <= (prefix_max_x1[exclusion_idx-1] > suffix_max_x1[exclusion_idx+1]) ? prefix_max_x1[exclusion_idx-1] : suffix_max_x1[exclusion_idx+1];
                  ex_max_y1 <= (prefix_max_y1[exclusion_idx-1] > suffix_max_y1[exclusion_idx+1]) ? prefix_max_y1[exclusion_idx-1] : suffix_max_y1[exclusion_idx+1];
                  ex_min_x2 <= (prefix_min_x2[exclusion_idx-1] < suffix_min_x2[exclusion_idx+1]) ? prefix_min_x2[exclusion_idx-1] : suffix_min_x2[exclusion_idx+1];
                  ex_min_y2 <= (prefix_min_y2[exclusion_idx-1] < suffix_min_y2[exclusion_idx+1]) ? prefix_min_y2[exclusion_idx-1] : suffix_min_y2[exclusion_idx+1];
               end
               if (ex_max_x1 <= ex_min_x2 && ex_max_y1 <= ex_min_y2) begin
                  result_x <= ex_max_x1;
                  result_y <= ex_max_y1;
                  valid <= 1'b1;
                  done <= 1'b1;
                  state <= DONE;
               end else begin
                  exclusion_idx <= exclusion_idx + 1;
               end
            end else begin
               done <= 1'b1;
               valid <= 1'b0;
               state <= DONE;
            end
         DONE: 
            state <= DONE;
      endcase
   end
endmodule