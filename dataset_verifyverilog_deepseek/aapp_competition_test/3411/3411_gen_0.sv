module alternating_chain(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [15:0] c,
  input [15:0] r,
  input [7:0] scores [0:7],
  output reg [31:0] min_time,
  output reg done
);
  localparam IDLE = 0;
  localparam COMPUTE = 1;
  localparam DONE = 2;
  
  reg [1:0] state = IDLE;
  reg [4:0] cycle_count = 0;
  reg [31:0] min_time_reg = 32'hFFFFFFFF;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_time <= 0;
      min_time_reg <= 32'hFFFFFFFF;
      cycle_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            min_time_reg <= 32'hFFFFFFFF;
            cycle_count <= 0;
            state <= COMPUTE;
          end
        end
        COMPUTE: begin
          if (cycle_count < 32) begin
            for (int i = 0; i < 8; i++) begin
              int subset_num = cycle_count * 8 + i;
              if (subset_num > 0 && subset_num < 256) begin
                reg [7:0] subset = subset_num;
                integer n_mask = (1 << n) - 1;
                if ((subset & ~n_mask) == 0) begin
                  integer kept_count = 0;
                  for (int k = 0; k < n; k++) kept_count += subset[k];
                  if (kept_count > 0) begin
                    reg vp = 0, vm = 0;
                    for (int com = 0; com < 8; com++) begin
                      if (subset[com] && (com < n)) begin
                        int pos = 0;
                        for (int k = 0; k < com; k++) pos += subset[k];
                        reg required_plus = ~pos[0];
                        reg required_minus = pos[0];
                        reg [7:0] score = scores[com];
                        reg is_zero = (score == 0);
                        reg sign_bit = score[7];
                        if (is_zero || (!required_plus && !sign_bit) || (required_plus && sign_bit)) vp = 1;
                        if (is_zero || (!required_minus && !sign_bit) || (required_minus && sign_bit)) vm = 1;
                      end
                    end
                    integer cost_plus = (n - kept_count) * r + (vp ? c : 0);
                    integer cost_minus = (n - kept_count) * r + (vm ? c : 0);
                    integer cost = (cost_plus < cost_minus) ? cost_plus : cost_minus;
                    if (cost < min_time_reg) min_time_reg = cost;
                  end
                end
              end
            end
            cycle_count++;
          end else begin
            min_time <= min_time_reg;
            done <= 1;
            state <= DONE;
          end
        end
        DONE: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule