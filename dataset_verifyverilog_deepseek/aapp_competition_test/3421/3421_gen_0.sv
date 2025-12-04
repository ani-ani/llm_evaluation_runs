module optimal_subsequence(
  input clk,
  input rst_n,
  input start,
  input [3:0] k,
  input [15:0] data,
  output reg [3:0] first_idx,
  output reg [3:0] length,
  output reg done
);
  typedef enum { IDLE, PROCESSING } state_t;
  state_t state;
  reg [16:0] prefix_sum;
  reg [3:0] best_sum;
  reg [3:0] best_len;
  reg [3:0] best_start;
  reg [4:0] cycle_cnt;
  reg [3:0] k_reg;
  reg [15:0] data_reg;
  wire [3:0] current_l = 4'd16 - cycle_cnt[3:0];

  reg [3:0] sxmax_sum;
  reg [3:0] sxbest_s;

  always_comb begin
    sxmax_sum = 4'd0;
    sxbest_s = 4'd0;
    for (integer s=0; s<=16; s=s+1) begin
      if (s > (16 - current_l)) continue;
      integer end_i = s + current_l;
      if (end_i > 16) continue;
      logic [3:0] sum_val = prefix_sum[end_i] - prefix_sum[s];
      if ((sum_val > sxmax_sum) || ((sum_val == sxmax_sum) && (s < sxbest_s))) begin
        sxmax_sum = sum_val;
        sxbest_s = s;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      best_sum <= 0;
      best_len <= 0;
      best_start <= 0;
      cycle_cnt <= 0;
      first_idx <= 0;
      length <= 0;
      k_reg <= 0;
      data_reg <= 0;
      prefix_sum <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESSING;
            k_reg <= k == 0 ? 4'd1 : k;
            data_reg <= data;
            prefix_sum[0] <= 0;
            for (int i=0; i<16; i=i+1) begin
              prefix_sum[i+1] <= prefix_sum[i] + data_reg[i];
            end
            best_sum <= 0;
            best_len <= 0;
            best_start <= 0;
            cycle_cnt <= 0;
          end
        end

        PROCESSING: begin
          if (current_l >= k_reg) begin
            wire [7:0] new_product = sxmax_sum * best_len;
            wire [7:0] best_product = best_sum * current_l;

            if ((best_len == 0) || (new_product > best_product) ||
                ((new_product == best_product) && (current_l > best_len)) ||
                ((new_product == best_product) && (current_l == best_len) && (sxbest_s < best_start))) begin
              best_sum <= sxmax_sum;
              best_len <= current_l;
              best_start <= sxbest_s;
            end
          end

          if (cycle_cnt < 15) begin
            cycle_cnt <= cycle_cnt + 1;
          end else begin
            done <= 1;
            first_idx <= best_start + 1;
            length <= best_len;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule