module permutation_cycle_generator (
  input reg [3:0] N,
  input reg [3:0] A,
  input reg [3:0] B,
  output logic valid,
  output logic [31:0] perm
);

  always_comb begin
    valid = 0;
    perm = 0;
    for (int x = 0; x <= N; x++) begin
      if (x * A > N) break;
      int remainder = N - x * A;
      if (remainder % B == 0) begin
        int y = remainder / B;
        valid = 1;
        int idx = 0;
        
        // Generate x cycles of length A
        for (int i = 0; i < x; i++) begin
          int start = i * A + 1;
          for (int j = 0; j < A; j++) begin
            int element;
            if (j < A - 1)
              element = start + 1 + j;
            else
              element = start;
            perm = perm | (element << (4 * idx));
            idx++;
          end
        end
        
        // Generate y cycles of length B
        for (int i = 0; i < y; i++) begin
          int start = x * A + i * B + 1;
          for (int j = 0; j < B; j++) begin
            int element;
            if (j < B - 1)
              element = start + 1 + j;
            else
              element = start;
            perm = perm | (element << (4 * idx));
            idx++;
          end
        end
        break;
      end
    end
  end
endmodule