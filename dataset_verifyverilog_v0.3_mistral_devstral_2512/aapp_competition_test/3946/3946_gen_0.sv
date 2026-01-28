module nauuo_visited (
  input clk,
  input rst_n,
  input start,
  input [2:0] m,
  input [2:0] n,
  input [7:0] a [0:7],
  input [15:0] w [0:7],
  output reg [15:0] result [0:7],
  output reg done
);

  // State machine states
  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] ACCUMULATE = 3'd1;
  localparam [2:0] DP_INIT = 3'd2;
  localparam [2:0] DP_COMPUTE = 3'd3;
  localparam [2:0] FINALIZE = 3'd4;
  localparam [2:0] OUTPUT = 3'd5;

  reg [2:0] state;
  reg [15:0] li;
  reg [15:0] di;
  reg [15:0] S;
  reg [3:0] t;
  reg [3:0] i;
  reg [15:0] F [0:8];
  reg [15:0] F_next [0:8];
  reg [15:0] po;
  reg [15:0] ne;
  reg [2:0] out_idx;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      li <= 16'd0;
      di <= 16'd0;
      S <= 16'd0;
      t <= 4'd0;
      i <= 4'd0;
      po <= 16'd0;
      ne <= 16'd0;
      out_idx <= 3'd0;
      for (integer k = 0; k < 8; k = k + 1) begin
        result[k] <= 16'd0;
      end
      for (integer k = 0; k < 9; k = k + 1) begin
        F[k] <= 16'd0;
        F_next[k] <= 16'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= ACCUMULATE;
          end
        end

        ACCUMULATE: begin
          li <= 16'd0;
          di <= 16'd0;
          for (integer k = 0; k < 8; k = k + 1) begin
            if (k < n) begin
              if (a[k]) begin
                li <= li + w[k];
              end else begin
                di <= di + w[k];
              end
            end
          end
          S <= li + di;
          state <= DP_INIT;
        end

        DP_INIT: begin
          F[0] <= 16'd256;
          for (integer k = 1; k < 9; k = k + 1) begin
            F[k] <= 16'd0;
          end
          t <= 4'd0;
          i <= 4'd0;
          state <= DP_COMPUTE;
        end

        DP_COMPUTE: begin
          if (i <= t) begin
            reg [15:0] den = S + (i << 1) - t;
            reg [15:0] inv_den = 16'd256;
            if (den != 16'd0) begin
              inv_den = 16'd256;
            end
            reg [15:0] prob_like = ((li + i) * inv_den) >> 8;
            F_next[i + 1] <= F[i] * prob_like;
            if (di > t - i) begin
              reg [15:0] prob_dislike = ((di - t + i) * inv_den) >> 8;
              F_next[i] <= F[i] * prob_dislike;
            end
            i <= i + 1;
          end else begin
            for (integer k = 0; k < 9; k = k + 1) begin
              F[k] <= F_next[k];
            end
            t <= t + 1;
            i <= 4'd0;
            if (t < m) begin
              state <= DP_COMPUTE;
            end else begin
              state <= FINALIZE;
            end
          end
        end

        FINALIZE: begin
          po <= 16'd0;
          ne <= 16'd0;
          for (integer k = 0; k < 9; k = k + 1) begin
            if (k <= m) begin
              po <= po + F[k] * (li + k);
              ne <= ne + F[k] * (di - m + k);
            end
          end
          state <= OUTPUT;
        end

        OUTPUT: begin
          if (out_idx < n) begin
            if (a[out_idx]) begin
              if (li != 16'd0) begin
                result[out_idx] <= (w[out_idx] * po) / li;
              end else begin
                result[out_idx] <= 16'd0;
              end
            end else begin
              if (di != 16'd0) begin
                result[out_idx] <= (w[out_idx] * ne) / di;
              end else begin
                result[out_idx] <= 16'd0;
              end
            end
            out_idx <= out_idx + 1;
          end else begin
            done <= 1'b1;
            state <= IDLE;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule