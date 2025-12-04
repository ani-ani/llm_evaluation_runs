module next_perfect_square (
  input clk,
  input rst_n,
  input start,       // high to begin a new computation
  input [15:0] N,    // 16-bit input number
  output logic [31:0] result, // 32-bit perfect square (next perfect square > N)
  output logic done   // high when result is valid
);

  // Internal state
  logic [15:0] n_r;      // captured input N
  logic [15:0] root;     // integer sqrt candidate built by successive approximation
  logic [7:0] bit_idx;   // which bit of the root we are testing (MSB->LSB)
  logic [4:0] cycle;     // cycle counter within a run (0..16)
  logic busy;            // high while computing

  // Ready when not busy (new inputs can be applied every 17 cycles)
  assign done = (cycle == 5'd16); // Valid in cycle 17 (after 16 cycles of sqrt + 1 cycle of square)

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_r    <= '0;
      root   <= '0;
      bit_idx <= 7;
      cycle  <= '0;
      busy   <= '0;
      result <= '0;
    end else begin
      // Default: hold current values; update in the clock where transitions occur
      n_r    <= n_r;
      root   <= root;
      bit_idx <= bit_idx;
      cycle  <= cycle;
      busy   <= busy;
      result <= result;

      if (!busy) begin
        // Capture new input and start sqrt computation
        if (start) begin
          n_r    <= N;
          root   <= '0;
          bit_idx <= 7;  // test bits from MSB to LSB
          cycle  <= 5'd1; // first trial step
          busy   <= 1'b1;
        end
      end else begin
        // Iterations 1..16: successive approximation for integer sqrt
        // Build candidate: try setting current bit in the root and see if (root+2^bit)^2 <= N
        // If so, keep the bit; else clear it.
        if (cycle >= 5'd1 && cycle <= 5'd16) begin
          logic [15:0] test_cand;
          logic [31:0] test_cand_sq;
          logic [31:0] n_ext;
          logic        le;

          test_cand   = {root[14:0], 1'b1} << bit_idx; // set current bit
          test_cand_sq = $unsigned(test_cand) * $unsigned(test_cand);
          n_ext       = $unsigned(n_r);
          le          = (test_cand_sq <= n_ext);
          root        <= (le ? test_cand : root);

          if (bit_idx == 8'd0) begin
            // After 16 iterations we have floor(sqrt(N)), proceed to square next integer
            // Step 1: floor = root; Step 2: next = floor + 1; Step 3: square
            logic [15:0] next_int;
            logic [31:0] sq;

            // Handle overflow for N near 16'hFFFF: next_int = min(root+1, 16'hFFFF)
            next_int = (root == 16'hFFFF) ? 16'hFFFF : (root + 1'b1);
            sq       = $unsigned(next_int) * $unsigned(next_int);
            result   <= sq;
            cycle    <= 5'd16; // stay here this cycle; next cycle will set cycle==16 -> done
          end else begin
            bit_idx <= bit_idx - 1'b1;
            cycle   <= cycle + 1'b1;
          end
        end else if (cycle == 5'd16) begin
          // Hold done for this cycle, then de-assert busy to allow new start next cycle
          busy <= 1'b0;
          cycle <= 5'd17; // stick to 17 to keep done high until busy is dropped
        end
        // else: cycle == 17 (holding done), do nothing until busy drops
      end
    end
  end

endmodule
