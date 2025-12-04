module max_pair_diff (
  input  logic              clk,
  input  logic              rst_n,
  input  logic [7:0][5:0]   pairs,
  input  logic              start,
  output logic [5:0]        max_diff,
  output logic              done
);

  // Internal signals with _d and _dd suffixes
  logic              start_d, start_dd;
  logic [2:0]        index_d, index_dd;
  logic [5:0]        max_diff_d, max_diff_dd;
  logic              active_d, active_dd;
  logic              done_d, done_dd;
  logic [5:0]        a_d, a_dd;
  logic [5:0]        b_d, b_dd;
  logic [5:0]        diff_d, diff_dd;

  // Combinational logic
  always_comb begin
    // Default pass-through
    start_dd    = start_d;
    index_dd    = index_d;
    max_diff_dd = max_diff_d;
    active_dd   = active_d;
    done_dd     = 1'b0;         // done is a single-cycle pulse
    a_dd        = a_d;
    b_dd        = b_d;
    diff_dd     = diff_d;

    // Capture new start when idle
    if (!active_d && start) begin
      active_dd   = 1'b1;
      index_dd    = 3'd0;
      max_diff_dd = 6'd0;
    end

    if (active_d) begin
      // Extract current pair {a,b} from pairs[index]
      a_dd = pairs[index_d][5:3];
      b_dd = pairs[index_d][2:0];

      // Compute absolute difference
      if (a_dd >= b_dd) begin
        diff_dd = a_dd - b_dd;
      end else begin
        diff_dd = b_dd - a_dd;
      end

      // Update max_diff
      if (diff_dd > max_diff_d) begin
        max_diff_dd = diff_dd;
      end

      // Increment index and check completion after 8 cycles
      if (index_d == 3'd7) begin
        active_dd = 1'b0;
        done_dd   = 1'b1;
      end
      index_dd = index_d + 3'd1;
    end
  end

  // Sequential logic with asynchronous active-low reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d    <= 1'b0;
      index_d    <= 3'd0;
      max_diff_d <= 6'd0;
      active_d   <= 1'b0;
      done_d     <= 1'b0;
      a_d        <= 6'd0;
      b_d        <= 6'd0;
      diff_d     <= 6'd0;
    end else begin
      start_d    <= start;
      index_d    <= index_dd;
      max_diff_d <= max_diff_dd;
      active_d   <= active_dd;
      done_d     <= done_dd;
      a_d        <= a_dd;
      b_d        <= b_dd;
      diff_d     <= diff_dd;
    end
  end

  // Outputs
  assign max_diff = max_diff_d;
  assign done     = done_d;

endmodule