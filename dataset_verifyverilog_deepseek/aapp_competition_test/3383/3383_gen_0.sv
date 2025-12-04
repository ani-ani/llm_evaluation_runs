module ice_cream_optimizer (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [1:0] k,
  input [8:0] a,
  input [8:0] b,
  input [8:0] t [0:3],
  input [8:0] u [0:3][0:3],
  output reg [31:0] max_ratio,
  output reg done
);

  typedef enum {IDLE, INIT, COMPUTE, DONE} state_t;
  state_t state, next_state;

  reg [4:0] s_reg;
  reg signed [13:0] dp_prev [0:3];
  reg signed [13:0] dp_current [0:3];
  reg signed [13:0] max_tastiness_val;
  reg [31:0] max_ratio_reg;

  wire [11:0] denominator = a * s_reg[3:0] + b;
  wire signed [13:0] max_t_comb;
  wire [31:0] current_ratio;

  always_comb begin : calc_max_t
    max_t_comb = -14'sd8192;
    for (int f = 0; f < 4; f++) begin
      if (f < k && dp_current[f] > max_t_comb)
        max_t_comb = dp_current[f];
    end
  end

  assign current_ratio = (max_t_comb > 0 && denominator != 0) ? 
                         ({ {18'h0}, max_t_comb[12:0] } << 16) / denominator : 32'b0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_ratio <= 0;
      max_ratio_reg <= 0;
      s_reg <= 0;
      foreach (dp_prev[i]) dp_prev[i] <= 14'sh2000;
      foreach (dp_current[i]) dp_current[i] <= 14'sh2000;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= INIT;
            max_ratio_reg <= 0;
            s_reg <= 1;
          end
        end

        INIT: begin
          foreach (dp_current[i]) begin
            if (i < k) dp_current[i] <= $signed(t[i]);
            else dp_current[i] <= 14'sh2000;
          end
          state <= COMPUTE;
        end

        COMPUTE: begin
          if (s_reg > n) begin
            state <= DONE;
            done <= 1;
            max_ratio <= max_ratio_reg;
          end else begin
            if (s_reg > 1) begin
              foreach (dp_current[i]) begin
                if (i < k) begin
                  reg signed [13:0] max_val = -14'sd8192;
                  foreach (dp_prev[j]) begin
                    if (j < k) begin
                      reg signed [13:0] sum = dp_prev[j] + $signed(t[i]) + $signed(u[j][i]);
                      if (sum > max_val) max_val = sum;
                    end
                  end
                  dp_current[i] <= max_val;
                end else begin
                  dp_current[i] <= 14'sh2000;
                end
              end
            end

            if (current_ratio > max_ratio_reg)
              max_ratio_reg <= current_ratio;

            if (s_reg <= n) begin
              foreach (dp_prev[i]) dp_prev[i] <= dp_current[i];
              s_reg <= s_reg + 1;
            end
          end
        end

        DONE: begin
          if (!start) state <= IDLE;
        end
      endcase
    end
  end
endmodule