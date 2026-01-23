module max_subrect_area (
input clk,
input rst_n,
input start,
input [7:0] a_len,
input [7:0] b_len,
input [15:0] x,
input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
input [7:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
output reg [15:0] result,
output reg done
);

reg [2:0] state;
reg [15:0] prefix_a [0:8] = 0;
reg [15:0] prefix_b [0:8] = 0;
reg [15:0] min_sum_a [1:8] = 16'hFFFF;
reg [15:0] min_sum_b [1:8] = 16'hFFFF;
reg [15:0] result_reg = 0;
reg done_reg = 0;
reg [3:0] i_prefix_a = 0;
reg [3:0] i_prefix_b = 0;
reg [3:0] i_min_a = 0;
reg [3:0] start_a = 0;
reg [3:0] i_min_b = 0;
reg [3:0] start_b = 0;
reg [3:0] i_combo = 0;
reg [3:0] j_combo = 0;

localparam IDLE = 3'd0;
localparam CALC_PREFIX_A = 3'd1;
localparam CALC_PREFIX_B = 3'd2;
localparam FIND_MIN_A = 3'd3;
localparam FIND_MIN_B = 3'd4;
localparam CHECK_COMBOS = 3'd5;
localparam DONE = 3'd6;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      result_reg <= 0;
      done_reg <= 0;
      i_prefix_a <= 0;
      i_prefix_b <= 0;
      i_min_a <= 0;
      start_a <= 0;
      i_min_b <= 0;
      start_b <= 0;
      i_combo <= 0;
      j_combo <= 0;
   end else begin
      case (state)
         IDLE: begin
            if (start) state <= CALC_PREFIX_A;
         end
         CALC_PREFIX_A: begin
            if (a_len == 0) state <= CALC_PREFIX_B;
            else if (i_prefix_a < a_len) begin
               prefix_a[i_prefix_a + 1] <= prefix_a[i_prefix_a] + a[i_prefix_a];
               i_prefix_a <= i_prefix_a + 1;
            end else state <= CALC_PREFIX_B;
         end
         CALC_PREFIX_B: begin
            if (b_len == 0) state <= FIND_MIN_A;
            else if (i_prefix_b < b_len) begin
               prefix_b[i_prefix_b + 1] <= prefix_b[i_prefix_b] + b[i_prefix_b];
               i_prefix_b <= i_prefix_b + 1;
            end else state <= FIND_MIN_A;
         end
         FIND_MIN_A: begin
            if (i_min_a < a_len) begin
               if (start_a < (a_len - i_min_a)) begin
                  if (prefix_a[start_a + i_min_a] - prefix_a[start_a] < min_sum_a[i_min_a])
                     min_sum_a[i_min_a] <= prefix_a[start_a + i_min_a] - prefix_a[start_a];
                  start_a <= start_a + 1;
               end else begin
                  start_a <= 0;
                  i_min_a <= i_min_a + 1;
               end
            end else state <= FIND_MIN_B;
         end
         FIND_MIN_B: begin
            if (i_min_b < b_len) begin
               if (start_b < (b_len - i_min_b)) begin
                  if (prefix_b[start_b + i_min_b] - prefix_b[start_b] < min_sum_b[i_min_b])
                     min_sum_b[i_min_b] <= prefix_b[start_b + i_min_b] - prefix_b[start_b];
                  start_b <= start_b + 1;
               end else begin
                  start_b <= 0;
                  i_min_b <= i_min_b + 1;
               end
            end else state <= CHECK_COMBOS;
         end
         CHECK_COMBOS: begin
            if (i_combo <= a_len) begin
               if (j_combo <= b_len) begin
                  if (min_sum_a[i_combo] * min_sum_b[j_combo] <= x) begin
                     if (i_combo * j_combo > result_reg)
                        result_reg <= i_combo * j_combo;
                  end
                  j_combo <= j_combo + 1;
               end else begin
                  j_combo <= 1;
                  i_combo <= i_combo + 1;
               end
            end else begin
               state <= DONE;
               done_reg <= 1;
            end
         end
         DONE: begin
            if (start) begin
               state <= IDLE;
               done_reg <= 0;
            end
         end
      endcase
      result <= result_reg;
      done <= done_reg;
   end
endmodule