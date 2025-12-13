module xorbonacci_queries(
  input clk,
  input rst_n,
  input start,
  input [1:0] K,          // Current max K=4 (values 1-4)
  input [7:0] a1, a2, a3, a4,  // Initial terms (unused terms ignored)
  input [1:0] Q,          // Number of queries (1-4)
  input [3:0] l1, r1,      // Query 1 parameters (max index=16)
  input [3:0] l2, r2,      // Query 2 parameters
  input [3:0] l3, r3,      // Query 3 parameters
  input [3:0] l4, r4,      // Query 4 parameters
  output reg done,
  output reg [7:0] res1,   // Query 1 result
  output reg [7:0] res2,   // Query 2 result
  output reg [7:0] res3,   // Query 3 result
  output reg [7:0] res4    // Query 4 result
);

  // Internal sequence storage, 1-based indexing (x[0] unused)
  reg [7:0] x [0:16];

  // FSM states
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_GEN   = 2'b01,
    S_QUERY = 2'b10
  } state_t;

  state_t state, next_state;

  // Counters and control
  reg [4:0] idx;      // 1..16 generation index

  // Latched start to detect rising edge
  reg start_d;
  wire start_pulse = start & ~start_d;

  //----------------------------------------------------------------------
  // Sequential logic: state, counters, registers
  //----------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_IDLE;
      idx      <= 5'd0;
      done     <= 1'b0;
      res1     <= 8'd0;
      res2     <= 8'd0;
      res3     <= 8'd0;
      res4     <= 8'd0;
      start_d  <= 1'b0;
      x[0]     <= 8'd0; // unused
      x[1]     <= 8'd0;
      x[2]     <= 8'd0;
      x[3]     <= 8'd0;
      x[4]     <= 8'd0;
      x[5]     <= 8'd0;
      x[6]     <= 8'd0;
      x[7]     <= 8'd0;
      x[8]     <= 8'd0;
      x[9]     <= 8'd0;
      x[10]    <= 8'd0;
      x[11]    <= 8'd0;
      x[12]    <= 8'd0;
      x[13]    <= 8'd0;
      x[14]    <= 8'd0;
      x[15]    <= 8'd0;
      x[16]    <= 8'd0;
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start_pulse) begin
            // Initialize first K terms
            x[1] <= a1;
            x[2] <= (K >= 2) ? a2 : 8'd0;
            x[3] <= (K >= 3) ? a3 : 8'd0;
            x[4] <= (K >= 4) ? a4 : 8'd0;
            // Clear remaining (optional, but deterministic)
            x[5]  <= 8'd0;
            x[6]  <= 8'd0;
            x[7]  <= 8'd0;
            x[8]  <= 8'd0;
            x[9]  <= 8'd0;
            x[10] <= 8'd0;
            x[11] <= 8'd0;
            x[12] <= 8'd0;
            x[13] <= 8'd0;
            x[14] <= 8'd0;
            x[15] <= 8'd0;
            x[16] <= 8'd0;
            // Start generating from index max( K+1, 1 )
            if (K < 1)
              idx <= 5'd1;
            else if (K < 16)
              idx <= K + 1;
            else
              idx <= 5'd17; // already done if K>=16
          end
        end

        S_GEN: begin
          // Generate term at current idx using previous K terms
          // Only execute when idx in [K+1 .. 16]
          if (idx <= 16) begin
            case (K)
              2'd1: x[idx] <= x[idx-1];
              2'd2: x[idx] <= x[idx-1] ^ x[idx-2];
              2'd3: x[idx] <= x[idx-1] ^ x[idx-2] ^ x[idx-3];
              default: x[idx] <= x[idx-1] ^ x[idx-2] ^ x[idx-3] ^ x[idx-4]; // K==4
            endcase
            idx <= idx + 1'b1;
          end
        end

        S_QUERY: begin
          // Compute all query results in one cycle from precomputed x[1..16]
          // Helper function behavior is inlined via local automatic function calls
          res1 <= (Q >= 1) ? range_xor(l1, r1) : 8'd0;
          res2 <= (Q >= 2) ? range_xor(l2, r2) : 8'd0;
          res3 <= (Q >= 3) ? range_xor(l3, r3) : 8'd0;
          res4 <= (Q >= 4) ? range_xor(l4, r4) : 8'd0;
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  //----------------------------------------------------------------------
  // Next-state logic
  //----------------------------------------------------------------------
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start_pulse) begin
          // If K >= 16, sequence is fully defined by given terms (or subset)
          // and no generation is needed.
          if (K >= 4 && 16 <= K)
            next_state = S_QUERY;
          else if ((K >= 1) && (K < 16))
            next_state = S_GEN;
          else
            next_state = S_GEN;
        end
      end

      S_GEN: begin
        if (idx > 16)
          next_state = S_QUERY;
      end

      S_QUERY: begin
        // Hold done high until next start pulse brings us back implicitly via S_IDLE
        // Transition back to IDLE when start goes low and then high again.
        if (!start)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  //----------------------------------------------------------------------
  // Range XOR function over x[1..16]
  //----------------------------------------------------------------------
  function automatic [7:0] range_xor;
    input [3:0] l;
    input [3:0] r;
    integer i;
    reg [7:0] acc;
    begin
      acc = 8'd0;
      if (l >= 1 && r >= l) begin
        for (i = l; i <= r; i = i + 1) begin
          if (i >= 1 && i <= 16)
            acc = acc ^ x[i];
        end
      end
      range_xor = acc;
    end
  endfunction

endmodule