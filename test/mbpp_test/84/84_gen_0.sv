module newman_conway(
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] n_in,
  output reg [3:0] result,
  output reg       done
);

  // 16-entry register array, index 0-15; we use indices 1-16 for P(1..16)
  reg [3:0] P [0:15];

  reg [3:0] curr_n;       // current n being computed (for n>=3)
  reg [3:0] target_n;     // latched n_in
  reg       busy;         // computation in progress

  integer i;

  // Asynchronous reset, sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // reset all state
      for (i = 0; i < 16; i = i + 1) begin
        P[i] <= 4'd0;
      end
      result   <= 4'd0;
      done     <= 1'b0;
      busy     <= 1'b0;
      curr_n   <= 4'd0;
      target_n <= 4'd0;
    end else begin
      // default
      done <= 1'b0;

      if (start && !busy) begin
        // latch target and (re)initialize base values
        target_n <= n_in;

        // Initialize all to 0, then set P(1) and P(2)
        for (i = 0; i < 16; i = i + 1) begin
          P[i] <= 4'd0;
        end
        P[1] <= 4'd1; // P(1)
        P[2] <= 4'd1; // P(2)

        if (n_in <= 4'd2) begin
          // result valid same cycle for n=1 or 2
          result <= 4'd1;
          done   <= 1'b1;
          busy   <= 1'b0;
          curr_n <= 4'd0;
        end else begin
          // start iterative computation at n=3
          busy   <= 1'b1;
          curr_n <= 4'd3;
        end

      end else if (busy) begin
        // iterative computation: one n per cycle
        // compute: P(curr_n) = P( P(curr_n-1) ) + P( curr_n - P(curr_n-1) )
        // all indices within 1..16 for given constraints
        reg [3:0] prev_val;
        reg [3:0] idx1;
        reg [3:0] idx2;
        reg [4:0] sum; // allow up to sum 4'd8 safely

        prev_val = P[curr_n - 1];
        idx1     = P[prev_val];
        idx2     = curr_n - prev_val;
        sum      = P[idx1] + P[idx2];

        P[curr_n] <= sum[3:0];

        if (curr_n == target_n) begin
          // computation for requested n complete
          result <= sum[3:0];
          done   <= 1'b1;
          busy   <= 1'b0;
        end else begin
          // move to next n
          curr_n <= curr_n + 4'd1;
        end
      end
    end
  end

endmodule