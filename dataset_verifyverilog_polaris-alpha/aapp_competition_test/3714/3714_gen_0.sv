module crush_joongoon(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] crunch_arr [0:7],
  output reg [15:0] t,
  output reg done
);

  // FSM states
  typedef enum logic [3:0] {
    S_IDLE      = 4'd0,
    S_INIT      = 4'd1,
    S_NEXT_NODE = 4'd2,
    S_DFS_INIT  = 4'd3,
    S_DFS_STEP  = 4'd4,
    S_DFS_BACK  = 4'd5,
    S_GCD       = 4'd6,
    S_LCM       = 4'd7,
    S_DONE      = 4'd8,
    S_ERROR     = 4'd9
  } state_t;

  state_t state, next_state;

  // Visited array to ensure each node's cycle processed once
  reg visited [0:7];

  // DFS stack for path tracking (max depth 8)
  reg [2:0] stack_nodes [0:7];
  reg [2:0] stack_index [0:7];  // first index where this node appeared in stack
  reg [3:0] sp;                 // stack pointer (depth)

  // Per-node and global variables
  reg [2:0] current_node;
  reg [2:0] start_node;
  reg [3:0] cycle_len;          // up to 8
  reg [3:0] adj_cycle_len;      // adjusted cycle length (odd: L, even: L/2)

  // LCM/GCD calculations
  reg [15:0] lcm_acc;           // accumulated LCM
  reg [15:0] gcd_a, gcd_b;
  reg [15:0] gcd_res;

  // Control
  reg [6:0] cycle_cnt;          // to enforce 100-cycle max if desired (not strictly needed for functionality)
  reg start_d;

  // Helper: find node index in stack
  function automatic [3:0] find_in_stack(input [2:0] node, input [3:0] depth);
    integer i;
    begin
      find_in_stack = 4'hF; // 0xF means not found
      for (i = 0; i < 8; i = i + 1) begin
        if (i < depth) begin
          if (stack_nodes[i] == node && find_in_stack == 4'hF) begin
            find_in_stack = i[3:0];
          end
        end
      end
    end
  endfunction

  // Sequential GCD (Euclidean) - executes in S_GCD state over multiple cycles
  // When gcd_b becomes 0, gcd_res holds GCD.

  // Next state logic (combinational)
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start && !start_d) next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_NEXT_NODE;
      end

      S_NEXT_NODE: begin
        if (t == 16'hFFFF) begin
          next_state = S_ERROR;
        end else if (current_node == 3'd7 && visited[7]) begin
          // All nodes processed
          next_state = S_DONE;
        end else if (visited[current_node]) begin
          // Move to next node
          next_state = S_NEXT_NODE;
        end else begin
          // Start DFS from this unvisited node
          next_state = S_DFS_INIT;
        end
      end

      S_DFS_INIT: begin
        next_state = S_DFS_STEP;
      end

      S_DFS_STEP: begin
        if (t == 16'hFFFF) begin
          next_state = S_ERROR;
        end else if (sp == 0) begin
          // No cycle found for this start_node: invalid mapping
          next_state = S_ERROR;
        end else begin
          // We'll detect conditions via registered flags handled in seq block
          // Default stay; transitions decided by flags set in seq always block.
          next_state = state; // updated below via specific flags
        end
      end

      S_DFS_BACK: begin
        // After resolving one cycle, go pick next node
        next_state = S_NEXT_NODE;
      end

      S_GCD: begin
        if (gcd_b == 16'd0) begin
          next_state = S_LCM;
        end else begin
          next_state = S_GCD;
        end
      end

      S_LCM: begin
        next_state = S_DFS_BACK;
      end

      S_DONE: begin
        // Wait for next start
        if (start && !start_d) next_state = S_INIT;
      end

      S_ERROR: begin
        // Output error; wait for next start
        if (start && !start_d) next_state = S_INIT;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Flags for transitions inside DFS (must be regs updated in seq block)
  reg dfs_found_cycle;
  reg dfs_invalid_edge;

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      start_d   <= 1'b0;
      t         <= 16'd0;
      done      <= 1'b0;
      lcm_acc   <= 16'd1;
      cycle_cnt <= 7'd0;
      current_node <= 3'd0;
      start_node   <= 3'd0;
      sp        <= 4'd0;
      dfs_found_cycle  <= 1'b0;
      dfs_invalid_edge <= 1'b0;
      gcd_a <= 16'd0;
      gcd_b <= 16'd0;
      gcd_res <= 16'd0;
      for (i = 0; i < 8; i = i + 1) begin
        visited[i] <= 1'b0;
        stack_nodes[i] <= 3'd0;
        stack_index[i] <= 3'd0;
      end
    end else begin
      state   <= next_state;
      start_d <= start;

      // Optional cycle count (not used to force stop but available)
      if (state != S_IDLE && state != S_DONE && state != S_ERROR)
        cycle_cnt <= cycle_cnt + 7'd1;
      else
        cycle_cnt <= 7'd0;

      case (state)
        S_IDLE: begin
          done      <= 1'b0;
          t         <= 16'd0;
          lcm_acc   <= 16'd1;
          dfs_found_cycle  <= 1'b0;
          dfs_invalid_edge <= 1'b0;
          for (i = 0; i < 8; i = i + 1) begin
            visited[i] <= 1'b0;
          end
          current_node <= 3'd0;
          sp <= 4'd0;
        end

        S_INIT: begin
          done      <= 1'b0;
          t         <= 16'd0;
          lcm_acc   <= 16'd1;
          dfs_found_cycle  <= 1'b0;
          dfs_invalid_edge <= 1'b0;
          for (i = 0; i < 8; i = i + 1) begin
            visited[i] <= 1'b0;
          end
          current_node <= 3'd0;
          sp <= 4'd0;
        end

        S_NEXT_NODE: begin
          dfs_found_cycle  <= 1'b0;
          dfs_invalid_edge <= 1'b0;
          // If current node visited, move to next
          if (visited[current_node]) begin
            if (current_node < 3'd7)
              current_node <= current_node + 3'd1;
          end else begin
            // Prepare to start DFS from this node
            start_node <= current_node;
          end
        end

        S_DFS_INIT: begin
          // Initialize stack with start_node
          sp <= 4'd1;
          stack_nodes[0] <= start_node;
          stack_index[0] <= 4'd0;
          dfs_found_cycle  <= 1'b0;
          dfs_invalid_edge <= 1'b0;
        end

        S_DFS_STEP: begin
          // Perform one step of DFS-like traversal following functional graph edges
          dfs_found_cycle  <= 1'b0;
          dfs_invalid_edge <= 1'b0;

          if (sp == 0) begin
            // No nodes: invalid mapping (no cycle)
            dfs_invalid_edge <= 1'b1;
            t <= 16'hFFFF;
          end else begin
            // Current node is top of stack
            current_node <= stack_nodes[sp-1];
            // Compute next node from crunch_arr
            // crunch_arr is total mapping [0..7] so always in range 0..7
            // but we still implement check logic pattern if needed
            begin
              reg [2:0] next_node;
              reg [3:0] pos;
              next_node = crunch_arr[stack_nodes[sp-1]];

              // Check if next_node appears in current stack: cycle detection
              pos = find_in_stack(next_node, sp);

              if (pos != 4'hF) begin
                // Cycle found from pos to sp-1
                cycle_len = sp - pos;
                // Mark all nodes in cycle as visited
                for (i = 0; i < 8; i = i + 1) begin
                  if (i >= pos && i < sp)
                    visited[stack_nodes[i]] <= 1'b1;
                end

                // Adjust cycle length
                if (cycle_len[0] == 1'b1) begin
                  // odd
                  adj_cycle_len = cycle_len;
                end else begin
                  // even
                  adj_cycle_len = cycle_len >> 1;
                end

                // Start GCD for LCM update: gcd(lcm_acc, adj_cycle_len)
                if (adj_cycle_len == 0) begin
                  // Degenerate, treat as error
                  t <= 16'hFFFF;
                  dfs_invalid_edge <= 1'b1;
                end else if (lcm_acc == 16'hFFFF) begin
                  // Already error state
                  dfs_invalid_edge <= 1'b1;
                end else begin
                  gcd_a <= lcm_acc;
                  gcd_b <= adj_cycle_len;
                  gcd_res <= 16'd0;
                  dfs_found_cycle <= 1'b1;
                end
              end else begin
                // No cycle yet; push next_node and continue
                if (sp < 4'd8) begin
                  stack_nodes[sp] <= next_node;
                  stack_index[sp] <= sp;
                  sp <= sp + 4'd1;
                end else begin
                  // Stack overflow -> invalid
                  t <= 16'hFFFF;
                  dfs_invalid_edge <= 1'b1;
                end
              end
            end
          end

          // State transitions based on flags
          if (dfs_invalid_edge) begin
            // Move to error state directly
            state <= S_ERROR;
          end else if (dfs_found_cycle) begin
            // Begin GCD computation
            state <= S_GCD;
          end
        end

        S_GCD: begin
          // Iterative Euclidean algorithm
          if (gcd_b != 16'd0) begin
            reg [15:0] tmp;
            tmp   = gcd_a % gcd_b;
            gcd_a <= gcd_b;
            gcd_b <= tmp;
          end else begin
            // Done, gcd_a is GCD
            gcd_res <= gcd_a;
          end
        end

        S_LCM: begin
          // lcm = (lcm_acc / gcd_res) * adj_cycle_len
          if (t != 16'hFFFF) begin
            if (gcd_res == 16'd0) begin
              // Invalid
              t       <= 16'hFFFF;
              lcm_acc <= 16'hFFFF;
            end else begin
              reg [31:0] tmp_mult;
              reg [31:0] tmp_lcm;
              reg [15:0] div_val;

              // div_val = lcm_acc / gcd_res
              div_val = (gcd_res != 0) ? (lcm_acc / gcd_res) : 16'hFFFF;
              tmp_mult = div_val * adj_cycle_len;

              if (tmp_mult > 32'hFFFF) begin
                // Overflow, saturate to error
                t       <= 16'hFFFF;
                lcm_acc <= 16'hFFFF;
              end else begin
                tmp_lcm = tmp_mult;
                if (tmp_lcm == 0) begin
                  // Zero LCM not expected; treat as error
                  t       <= 16'hFFFF;
                  lcm_acc <= 16'hFFFF;
                end else begin
                  lcm_acc <= tmp_lcm[15:0];
                  t       <= tmp_lcm[15:0];
                end
              end
            end
          end

          // After updating LCM, pop stack completely for this component
          sp <= 4'd0;

          // Mark all remaining nodes in this connected component as visited
          // (since it's a functional graph, all paths eventually lead to a cycle we've just processed)
          // To keep it simple, we only mark nodes already on stack as visited (sp already 0 now).
          // Remaining nodes will be individually started later if unvisited.
        end

        S_DFS_BACK: begin
          // Advance current_node to next index
          if (current_node < 3'd7)
            current_node <= current_node + 3'd1;
        end

        S_DONE: begin
          done <= 1'b1;
          // t already holds final LCM (or 0xFFFF if error)
        end

        S_ERROR: begin
          t    <= 16'hFFFF;
          done <= 1'b1;
          lcm_acc <= 16'hFFFF;
        end

        default: ;
      endcase
    end
  end

endmodule