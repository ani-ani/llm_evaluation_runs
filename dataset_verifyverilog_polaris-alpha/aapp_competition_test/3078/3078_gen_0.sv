module longest_interesting_subsequence(
  input  [15:0] S,
  input  [15:0] A [0:7],
  output reg [3:0] result [0:7]
);

  // Precompute all contiguous subarray sums sum_[i][len]
  // sum_[i][len] is sum of A[i +: len], valid when i+len-1 < 8
  wire [19:0] sum_ [0:7][1:8];

  genvar gi, gl;

  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : GEN_BASE
      assign sum_[gi][1] = {4'd0, A[gi]};
    end
  endgenerate

  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : GEN_SUMS_I
      for (gl = 2; gl <= 8; gl = gl + 1) begin : GEN_SUMS_L
        if (gi + gl - 1 < 8) begin : GEN_VALID
          assign sum_[gi][gl] = sum_[gi][gl-1] + {4'd0, A[gi + gl - 1]};
        end else begin : GEN_INV
          assign sum_[gi][gl] = 20'd0;
        end
      end
    end
  endgenerate

  // Combinational logic to select longest valid even-length subsequence for each start index
  integer i;
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin : PER_START
      reg [3:0] best;
      reg [2:0] maxL;
      reg [2:0] L_even;
      reg [3:0] K;
      reg [2:0] first_idx;
      reg [2:0] last_idx;
      reg [19:0] first_sum;
      reg [19:0] last_sum;

      best  = 4'd0;
      maxL  = (8 - i[2:0]);
      if (maxL[0]) maxL = maxL - 1; // make even

      // Descend over even lengths: L = maxL, maxL-2, ... , 2
      for (L_even = maxL; L_even >= 2; L_even = L_even - 2) begin
        K         = {1'b0, L_even} >> 1; // K = L_even / 2
        first_idx = i[2:0];
        last_idx  = i[2:0] + K[2:0];

        if (i + L_even - 1 < 8) begin
          first_sum = sum_[first_idx][K];
          last_sum  = sum_[last_idx][K];

          if ((first_sum <= {4'd0, S}) && (last_sum <= {4'd0, S}) && (best == 4'd0)) begin
            best = {1'b0, L_even};
          end
        end
      end

      result[i] = best;
    end
  end

endmodule