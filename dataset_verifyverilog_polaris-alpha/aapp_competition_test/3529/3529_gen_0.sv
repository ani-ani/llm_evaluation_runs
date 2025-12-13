module spanning_tree_k_blue(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  input  [3:0] m,
  input  [2:0] k,
  input  [15:0][7:0] edges,
  output reg result,
  output reg done
);

  // Internal signals
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_RUN   = 2'b01,
    S_DONE  = 2'b10
  } state_t;

  state_t state, state_next;

  reg [5:0] cycle_cnt;       // up to at least 31
  reg [3:0] edge_idx;        // index 0..15

  // Parsed edge fields for current edge
  reg [2:0] e_u;
  reg [2:0] e_v;
  reg       e_blue;          // 1 if blue, 0 if red

  // Union-Find for min_blue (favor red edges => prefer color=0)
  reg [2:0] parent_min [0:7];
  reg [2:0] parent_min_next [0:7];

  // Union-Find for max_blue (favor blue edges => prefer color=1)
  reg [2:0] parent_max [0:7];
  reg [2:0] parent_max_next [0:7];

  // Roots for current edge
  reg [2:0] root_min_u, root_min_v;
  reg [2:0] root_max_u, root_max_v;

  // Blue edge counters
  reg [2:0] min_blue_cnt;
  reg [2:0] max_blue_cnt;

  // Combinational wires
  wire [7:0] cur_edge = edges[edge_idx];

  // Simple one-level find (no path compression, UF depth small for <=8 nodes)
  function automatic [2:0] find_root_min(input [2:0] x);
    reg [2:0] r;
    begin
      r = x;
      // bounded iterations (log2(8)<=3) unrolled for safety
      if (parent_min[r] != r) r = parent_min[r];
      if (parent_min[r] != r) r = parent_min[r];
      if (parent_min[r] != r) r = parent_min[r];
      find_root_min = r;
    end
  endfunction

  function automatic [2:0] find_root_max(input [2:0] x);
    reg [2:0] r;
    begin
      r = x;
      if (parent_max[r] != r) r = parent_max[r];
      if (parent_max[r] != r) r = parent_max[r];
      if (parent_max[r] != r) r = parent_max[r];
      find_root_max = r;
    end
  endfunction

  // Next-state and UF update logic
  integer i;

  always @(*) begin
    // Defaults
    state_next    = state;

    // By default, hold parents
    for (i = 0; i < 8; i = i + 1) begin
      parent_min_next[i] = parent_min[i];
      parent_max_next[i] = parent_max[i];
    end

    // Default parsed edge
    e_u    = cur_edge[2:0];
    e_v    = cur_edge[5:3];
    e_blue = cur_edge[7];

    case (state)
      S_IDLE: begin
        if (start) begin
          // Initialize UF parents to identity
          for (i = 0; i < 8; i = i + 1) begin
            parent_min_next[i] = i[2:0];
            parent_max_next[i] = i[2:0];
          end
          state_next = S_RUN;
        end
      end

      S_RUN: begin
        // Process edge only if within m and nodes < n
        if (edge_idx < m && e_u < n && e_v < n) begin
          // Compute roots
          root_min_u = find_root_min(e_u);
          root_min_v = find_root_min(e_v);
          root_max_u = find_root_max(e_u);
          root_max_v = find_root_max(e_v);

          // For min_blue: favor red (e_blue==0)
          if (root_min_u != root_min_v) begin
            if (e_blue == 1'b0) begin
              // take all red edges in spanning tree when possible
              parent_min_next[root_min_v] = root_min_u;
            end else begin
              // for blue, only use if needed to connect components
              parent_min_next[root_min_v] = root_min_u;
            end
          end

          // For max_blue: favor blue (e_blue==1)
          if (root_max_u != root_max_v) begin
            if (e_blue == 1'b1) begin
              parent_max_next[root_max_v] = root_max_u;
            end else begin
              parent_max_next[root_max_v] = root_max_u;
            end
          end
        end

        // Transition to DONE at cycle 31 (32 cycles total: 0..31)
        if (cycle_cnt == 6'd31) begin
          state_next = S_DONE;
        end
      end

      S_DONE: begin
        // Stay in DONE until next start or reset
        if (start) begin
          // Re-initialize on new start
          for (i = 0; i < 8; i = i + 1) begin
            parent_min_next[i] = i[2:0];
            parent_max_next[i] = i[2:0];
          end
          state_next = S_RUN;
        end
      end

      default: begin
        state_next = S_IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      cycle_cnt     <= 6'd0;
      edge_idx      <= 4'd0;
      min_blue_cnt  <= 3'd0;
      max_blue_cnt  <= 3'd0;
      result        <= 1'b0;
      done          <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        parent_min[i] <= i[2:0];
        parent_max[i] <= i[2:0];
      end
    end else begin
      state <= state_next;

      case (state)
        S_IDLE: begin
          done         <= done; // remains until reset or new start
          result       <= result;
          cycle_cnt    <= 6'd0;
          edge_idx     <= 4'd0;
          min_blue_cnt <= 3'd0;
          max_blue_cnt <= 3'd0;
          for (i = 0; i < 8; i = i + 1) begin
            parent_min[i] <= parent_min_next[i];
            parent_max[i] <= parent_max_next[i];
          end
          if (start) begin
            done   <= 1'b0;
            result <= 1'b0;
          end
        end

        S_RUN: begin
          // Advance cycle counter and edge index
          cycle_cnt <= cycle_cnt + 6'd1;
          if (edge_idx < 4'd15)
            edge_idx <= edge_idx + 4'd1;
          else
            edge_idx <= edge_idx;

          // Apply parent updates
          for (i = 0; i < 8; i = i + 1) begin
            parent_min[i] <= parent_min_next[i];
            parent_max[i] <= parent_max_next[i];
          end

          // Update blue counts based on whether chosen for UF
          if (edge_idx < m && e_u < n && e_v < n) begin
            // Recompute roots using old parents (already captured by functions in comb logic)
            root_min_u = find_root_min(e_u);
            root_min_v = find_root_min(e_v);
            root_max_u = find_root_max(e_u);
            root_max_v = find_root_max(e_v);

            if (root_min_u != root_min_v && e_blue == 1'b1)
              min_blue_cnt <= min_blue_cnt + 3'd1;

            if (root_max_u != root_max_v && e_blue == 1'b1)
              max_blue_cnt <= max_blue_cnt + 3'd1;
          end
        end

        S_DONE: begin
          // Latch result once at entry to DONE
          done   <= 1'b1;
          result <= ((min_blue_cnt <= k) && (k <= max_blue_cnt)) ? 1'b1 : 1'b0;

          // Remain stable; allow restart on start (handled by next-state logic)
          cycle_cnt <= (start) ? 6'd0 : cycle_cnt;
          edge_idx  <= (start) ? 4'd0 : edge_idx;
          if (start) begin
            done         <= 1'b0;
            result       <= 1'b0;
            min_blue_cnt <= 3'd0;
            max_blue_cnt <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
              parent_min[i] <= parent_min_next[i];
              parent_max[i] <= parent_max_next[i];
            end
          end
        end

        default: begin
          // Safety fallback
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule