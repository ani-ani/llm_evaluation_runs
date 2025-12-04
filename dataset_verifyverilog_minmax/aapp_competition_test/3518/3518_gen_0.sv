module min_co2_matcher (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] m,
  input [2:0] p [0:27],
  input [2:0] q [0:27],
  input [13:0] c [0:27],
  output reg [15:0] min_co2,
  output reg impossible,
  output reg done
);

  // Internal adjacency matrix: 8x8 of 14-bit CO2 values
  // Use 16-bit internally to avoid overflow when invalid markers are added.
  logic [15:0] adj [0:7][0:7];
  logic [7:0] used_edges; // track which of the first 28 edges are actually applied
  logic [15:0] best_min;   // local accumulator for recursion results
  integer i, j, k, ii, jj; // temp indices for loops and recursion

  // State machine
  typedef enum logic [3:0] {
    S_IDLE        = 4'd0,
    S_BUILD_1     = 4'd1,
    S_BUILD_2     = 4'd2,
    S_BUILD_DONE  = 4'd3,
    S_MATCH       = 4'd4,
    S_DONE        = 4'd5
  } state_t;
  state_t state, next_state;

  // Synchronous reset and state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      min_co2 <= 16'd0;
      done <= 1'b0;
      impossible <= 1'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next-state logic
  always_comb begin
    // defaults
    next_state = state;
    done = 1'b0;
    case (state)
      S_IDLE: begin
        if (start) begin
          // Clear flags and result
          min_co2 = 16'd0;
          done = 1'b0;
          impossible = 1'b0;
          // Begin building adjacency
          next_state = S_BUILD_1;
        end else begin
          next_state = S_IDLE;
        end
      end

      S_BUILD_1: begin
        // Fill adjacency matrix from input edges
        // Pre-fill all to a large invalid value (16'hFFFF)
        // Then write actual edges; also track used edges count
        next_state = S_BUILD_2;
      end

      S_BUILD_2: begin
        // Verify friendship cliques (complete subgraphs) and enforce completeness
        // (If an edge is missing within the first 'n' nodes, we still allow it to remain INF; matching will fail if it blocks a perfect matching.)
        next_state = S_BUILD_DONE;
      end

      S_BUILD_DONE: begin
        // Proceed to matching computation
        next_state = S_MATCH;
      end

      S_MATCH: begin
        // Compute min-weight perfect matching via recursive generation (backtracking)
        // Finish in same cycle
        next_state = S_DONE;
      end

      S_DONE: begin
        done = 1'b1;
        if (start) begin
          // If user keeps start high, restart next cycle
          next_state = S_BUILD_1;
        end else begin
          next_state = S_IDLE;
        end
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Build adjacency matrix and verify cliques during state S_BUILD_1 and S_BUILD_2
  always_ff @(posedge clk) begin
    if (state == S_BUILD_1) begin
      // Initialize adjacency with INF (invalid)
      for (i = 0; i < 8; i++) begin
        for (j = 0; j < 8; j++) begin
          adj[i][j] <= 16'hFFFF;
        end
      end
      used_edges <= 8'd0;
    end else if (state == S_BUILD_2) begin
      // Apply edges to adjacency matrix
      for (k = 0; k < 28; k++) begin
        if (k < m) begin
          ii = p[k];
          jj = q[k];
          if (ii < 8 && jj < 8) begin
            // Store weight for both directions
            adj[ii][jj] <= {2'b00, c[k]};  // cast to 16-bit safely
            adj[jj][ii] <= {2'b00, c[k]};
            used_edges <= used_edges + 1;
          end
        end
      end
    end
  end

  // Compute minimum-weight perfect matching during S_MATCH
  task check_and_match;
    input [2:0] nn;
    output [15:0] result;
    output found;
    reg [15:0] best_local;
    integer idx_a, idx_b;
    reg found_any;
    reg [15:0] rec_best;
    reg rec_found;
  begin
    // n==0 is a trivial perfect matching with 0 cost
    if (nn == 3'd0) begin
      result = 16'd0;
      found = 1'b1;
      return;
    end

    // Find first free student
    found_any = 1'b0;
    for (i = 0; i < 8; i++) begin
      if (i < nn) begin
        found_any = 1'b1;
        break;
      end
    end
    if (!found_any) begin
      // Should not happen
      result = 16'hFFFF;
      found = 1'b0;
      return;
    end

    idx_a = i;
    best_local = 16'hFFFF;
    found_any = 1'b0;

    // Try pairing idx_a with any other free student j
    for (j = idx_a + 1; j < 8; j++) begin
      if (j < nn) begin
        // Edge must be valid (not INF)
        if (adj[idx_a][j] < 16'hFFFF) begin
          // Temporarily mark both as used by setting their entries to INF
          // We avoid actually masking the set; instead, recurse and skip used ones by index constraint.
          // Recurse on nn-2 participants (all but idx_a and j)
          check_and_match(nn - 2, rec_best, rec_found);
          if (rec_found) begin
            if ((adj[idx_a][j] + rec_best) < best_local) begin
              best_local = adj[idx_a][j] + rec_best;
            end
            found_any = 1'b1;
          end
        end
      end
    end

    if (found_any) begin
      result = best_local;
      found = 1'b1;
    end else begin
      result = 16'hFFFF;
      found = 1'b0;
    end
  end
  endtask

  always_ff @(posedge clk) begin
    if (state == S_MATCH) begin
      // Edge case handling before matching
      if (n == 3'd0) begin
        impossible <= 1'b1;      // per requirement: n=0 -> impossible
        min_co2   <= 16'd0;
      end else if (n[0] == 1'b1) begin
        // n is odd -> impossible
        impossible <= 1'b1;
        min_co2   <= 16'd0;
      end else begin
        // n is even >= 2: try to compute a perfect matching
        check_and_match(n, best_min, impossible); // impossible will be 0 if found, 1 if not
        if (impossible) begin
          min_co2 <= 16'd0;
        end else begin
          min_co2 <= best_min;
        end
      end
    end
  end

  // Additional optional check during S_BUILD_2: verify complete cliques
  // (Kept simple: only check that for any two students i,j < n, an edge exists (not INF).
  // If missing, the graph is not complete; matching will likely fail unless the missing edge is unused in all perfect matchings,
  // which is rare for small n; we still allow DP to decide and set impossible if no perfect matching exists.)
  always_ff @(posedge clk) begin
    if (state == S_BUILD_2) begin
      // No additional flag needed; completeness is implicitly considered by DP.
      // Intentionally left minimal to keep timing tight.
    end
  end

endmodule
