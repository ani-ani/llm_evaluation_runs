module form_largest_number #(
  parameter int N = 4
) (
  input  logic [N-1:0][3:0] digits,
  output logic [13:0]       max_num
);

  // Internal sorted digits
  logic [N-1:0][3:0] sorted;

  // Combinational sorting network (descending order) using simple bubble-sort style network
  integer i, j;
  logic [3:0] tmp;

  always_comb begin
    // Initialize
    sorted = digits;

    // Simple O(N^2) compare-swap network (synthesizable, fully combinational)
    for (i = 0; i < N-1; i = i + 1) begin
      for (j = 0; j < N-1-i; j = j + 1) begin
        if (sorted[j] < sorted[j+1]) begin
          tmp          = sorted[j];
          sorted[j]    = sorted[j+1];
          sorted[j+1]  = tmp;
        end
      end
    end

    // Compute max_num based on N and sorted digits
    // Precomputed powers of 10 (0..7): 1,10,100,1000,10000,100000,1000000,10000000
    // For N up to 8, result fits within 27 bits; here output is fixed at 14 bits for N=4.
    max_num = '0;
    unique case (N)
      1: begin
        max_num = sorted[0] * 14'd1;
      end
      2: begin
        max_num = sorted[0] * 14'd10
                + sorted[1] * 14'd1;
      end
      3: begin
        max_num = sorted[0] * 14'd100
                + sorted[1] * 14'd10
                + sorted[2] * 14'd1;
      end
      4: begin
        max_num = sorted[0] * 14'd1000
                + sorted[1] * 14'd100
                + sorted[2] * 14'd10
                + sorted[3] * 14'd1;
      end
      5: begin
        max_num = sorted[0] * 14'd10000
                + sorted[1] * 14'd1000
                + sorted[2] * 14'd100
                + sorted[3] * 14'd10
                + sorted[4] * 14'd1;
      end
      6: begin
        max_num = sorted[0] * 14'd10000  // truncated for 14-bit output
                + sorted[1] * 14'd1000
                + sorted[2] * 14'd100
                + sorted[3] * 14'd10
                + sorted[4] * 14'd1
                + sorted[5] * 14'd0;
      end
      7: begin
        max_num = sorted[0] * 14'd10000  // truncated
                + sorted[1] * 14'd1000
                + sorted[2] * 14'd100
                + sorted[3] * 14'd10
                + sorted[4] * 14'd1;
      end
      8: begin
        max_num = sorted[0] * 14'd10000  // truncated
                + sorted[1] * 14'd1000
                + sorted[2] * 14'd100
                + sorted[3] * 14'd10
                + sorted[4] * 14'd1;
      end
      default: begin
        max_num = '0;
      end
    endcase
  end

endmodule