module min_effort_balancing(
  input clk,
  input rst_n,
  input start,
  input [2:0] k_in,
  input [7:0] seq_bits,
  input [7:0][10:0] costs,
  output reg [10:0] min_effort,
  output reg impossible_flag,
  output reg done
);

  reg [3:0] cycle;
  reg [3:0] required_flips;
  reg signed [4:0] balance;
  reg [2:0] bit_idx;
  reg [7:0][10:0] candidate_costs;
  reg [3:0] can_idx;
  reg processing;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle <= 4'd0;
      required_flips <= 4'd0;
      balance <= 5'd0;
      bit_idx <= 3'd0;
      can_idx <= 4'd0;
      candidate_costs <= '{8{11'd0}};
      min_effort <= 11'd0;
      impossible_flag <= 1'b0;
      done <= 1'b0;
      processing <= 1'b0;
    end else begin
      done <= 1'b0;
      if (start) begin
        cycle <= 4'd0;
        required_flips <= 4'd0;
        balance <= 5'd0;
        bit_idx <= 3'd0;
        can_idx <= 4'd0;
        candidate_costs <= '{8{11'd0}};
        processing <= 1'b1;
      end else if (processing) begin
        cycle <= cycle + 4'd1;
        if (cycle < 4'd8) begin
          if (seq_bits[bit_idx]) begin
            if (balance > 5'd0) begin
              balance <= balance - 5'd1;
            end else begin
              required_flips <= required_flips + 4'd1;
              balance <= balance + 5'd1; // Flip to '('
              candidate_costs[can_idx] <= costs[bit_idx];
              can_idx <= can_idx + 4'd1;
            end
          end else begin
            balance <= balance + 5'd1;
          end
          bit_idx <= bit_idx + 3'd1;
        end else if (cycle == 4'd8) begin
          if (required_flips > {1'b0, k_in}) begin
            min_effort <= 11'd0;
            impossible_flag <= 1'b1;
          end else begin
            automatic integer m = (k_in - required_flips + 1);
            automatic integer m_valid = (m > required_flips) ? required_flips : m;
            automatic integer i, j;
            automatic logic signed [10:0] sorted_costs [0:7];
            automatic logic signed [10:0] temp;
            automatic logic signed [10:0] sum_val = 0;
            for (i=0; i<required_flips; i=i+1) sorted_costs[i] = candidate_costs[i];
            for (i=required_flips; i<8; i=i+1) sorted_costs[i] = 11'h7FF;
            for (i=0; i<required_flips; i=i+1) begin
              for (j=0; j<required_flips-i-1; j=j+1) begin
                if (sorted_costs[j] > sorted_costs[j+1]) begin
                  temp = sorted_costs[j];
                  sorted_costs[j] = sorted_costs[j+1];
                  sorted_costs[j+1] = temp;
                end
              end
            end
            for (i=0; i<m_valid; i=i+1) sum_val = sum_val + sorted_costs[i];
            min_effort <= sum_val;
            impossible_flag <= 1'b0;
          end
        end else if (cycle == 4'd14) begin
          processing <= 1'b0;
          done <= 1'b1;
        end
      end
    end
  end
endmodule