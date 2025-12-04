module max_zero_diff(
  input clk,
  input rst_n,
  input start,
  input [15:0] data,
  input [3:0] str_len,
  output reg [4:0] max_diff,
  output reg done
);
  reg processing;
  reg [3:0] bit_cnt;
  reg signed [5:0] current_sum;
  reg signed [5:0] max_sum;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing <= 1'b0;
      current_sum <= 6'sb0;
      max_sum <= 6'sb0;
      bit_cnt <= 4'b0;
      max_diff <= 5'b0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;
      if (start && !processing) begin
        processing <= 1'b1;
        bit_cnt <= 4'b0;
        current_sum <= 6'sb0;
        max_sum <= 6'sb0;
      end else if (processing) begin
        if (bit_cnt < str_len) begin
          logic signed [5:0] next_current_sum;
          if (data[15 - bit_cnt] == 1'b0) next_current_sum = current_sum + 6'sd1;
          else next_current_sum = current_sum - 6'sd1;

          if (next_current_sum < 0) current_sum <= 6'sb0;
          else current_sum <= next_current_sum;

          if (next_current_sum > max_sum) max_sum <= next_current_sum;

          bit_cnt <= bit_cnt + 4'b1;

          if (bit_cnt == str_len - 1) begin
            done <= 1'b1;
            max_diff <= max_sum[4:0];
          end
        end else begin
          processing <= 1'b0;
        end
      end
    end
  end
endmodule