module widget_packing(
  input clk,
  input rst_n,
  input start,
  input [31:0] N,
  output reg [31:0] empty_squares,
  output reg done
);

  // Internal registers
  logic start_d;
  logic start_pulse;
  logic computing;
  logic [5:0] cycle;
  logic [31:0] N_reg;
  logic [31:0] H0;
  logic [31:0] min_empty;
  logic [31:0] sqrt_low, sqrt_high;
  logic [31:0] N_div2;
  logic [31:0] H_cand;

  // Edge detection for start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end
  assign start_pulse = start && !start_d;

  // Main FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      computing <= 1'b0;
      cycle <= 6'b0;
      done <= 1'b0;
      empty_squares <= 32'b0;
      min_empty <= 32'hFFFFFFFF;
      H0 <= 32'b0;
      sqrt_low <= 32'b0;
      sqrt_high <= 16'hFFFF; // 65535
      N_div2 <= 32'b0;
      H_cand <= 32'b0;
    end else begin
      if (start_pulse && !computing) begin
        // Latch input and start computation
        N_reg <= N;
        computing <= 1'b1;
        cycle <= 6'b0;
        done <= 1'b0;
        empty_squares <= 32'b0;
        min_empty <= 32'hFFFFFFFF;
        H0 <= 32'b0;
        sqrt_low <= 32'b0;
        sqrt_high <= 16'hFFFF; // 65535
        N_div2 <= N >> 1;
        H_cand <= 32'b0;
      end

      if (computing) begin
        cycle <= cycle + 1;

        // 5-step binary approximation for sqrt(N/2)
        if (cycle < 6) begin // cycles 0..4
          logic [31:0] mid = (sqrt_low + sqrt_high) >> 1;
          logic [63:0] sq = (logic [63:0])mid * mid;
          if (sq <= N_div2) begin
            sqrt_low <= mid;
          end else begin
            sqrt_high <= mid - 1;
          end
          if (cycle == 5) begin // after 5 iterations, capture floor sqrt
            H0 <= sqrt_low;
          end
        end else if (cycle >= 6 && cycle < 10) begin // evaluate 4 H candidates
          // Determine which candidate to evaluate this cycle
          case (cycle - 6)
            0: H_cand <= (H0 >= 2) ? (H0 - 2) : 1;
            1: H_cand <= (H0 >= 1) ? (H0 - 1) : 1;
            2: H_cand <= H0;
            3: H_cand <= H0 + 1;
          endcase

          // Compute W_raw = ceil(N/H)
          logic [63:0] sum = (logic [63:0])N_reg + H_cand - 1;
          logic [31:0] W_raw = sum / H_cand;

          // Clamp W to [ceil(H/2), 2*H]
          logic [31:0] H_half_ceil = (H_cand + 1) >> 1; // ceil(H/2)
          logic [31:0] H2 = H_cand << 1; // 2*H
          logic [31:0] W;
          if (W_raw < H_half_ceil) W = H_half_ceil;
          else if (W_raw > H2) W = H2;
          else W = W_raw;

          // Compute empty squares = W*H - N
          logic [63:0] product = (logic [63:0])W * H_cand;
          logic [31:0] empty = product[31:0];

          // Update minimum if H_cand is valid (>=1) and empty is smaller
          if (H_cand >= 1 && empty < min_empty) begin
            min_empty <= empty;
          end
        end

        // After 32 cycles, output result and assert done
        if (cycle == 31) begin
          empty_squares <= min_empty;
          done <= 1'b1;
          computing <= 1'b0; // finish
        end
      end
    end
  end

endmodule