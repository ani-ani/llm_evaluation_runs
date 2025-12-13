module magic_color_counter(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] node_id,
  input  [1:0] cmd_data,
  input  [2:0] parents [1:7],
  input  [1:0] init_colors [0:7],
  output reg [2:0] magic_count,
  output reg       done
);

  // Internal storage
  reg [1:0] colors [0:7];              // current colors for nodes 0..7 (representing 1..8)

  // Child adjacency: each node (0..7) up to 3 children of 3 bits each
  reg [2:0] child0 [0:7];
  reg [2:0] child1 [0:7];
  reg [2:0] child2 [0:7];
  reg [1:0] child_cnt [0:7];           // number of valid children (0..3)

  // BFS traversal state
  reg [2:0] queue [0:7];               // up to 8 nodes
  reg [2:0] head;
  reg [2:0] tail;

  // State machine
  typedef enum logic [1:0] {
    S_IDLE   = 2'b00,
    S_PREP   = 2'b01,
    S_TRAVERSE = 2'b10,
    S_DONE   = 2'b11
  } state_t;

  state_t state, next_state;

  reg [2:0] root_node;                 // latched node_id for query
  reg       is_query;                  // latched command type

  // Color count parity (only need parity for magic criteria)
  reg parity0, parity1, parity2, parity3;  // 1 if odd count for given color

  // Latched command inputs for operation in pipeline
  reg       start_d;

  integer i;

  // Synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize colors from init_colors
      for (i = 0; i < 8; i = i + 1) begin
        colors[i] <= init_colors[i];
      end

      // Clear child structures
      for (i = 0; i < 8; i = i + 1) begin
        child0[i]    <= 3'd0;
        child1[i]    <= 3'd0;
        child2[i]    <= 3'd0;
        child_cnt[i] <= 2'd0;
      end

      // Build child lists from parents mapping for nodes 1..7 (representing 2..8)
      // Node index mapping: node_id(1..8) -> index(0..7) = node_id-1
      for (i = 1; i <= 7; i = i + 1) begin
        // child node index
        // i corresponds to node (i+1)
        // parents[i] is 3-bit parent node_id (1..8)
        // parent index = parents[i] - 1
        if (parents[i] != 3'd0) begin
          // Valid parent assumed in 1..8
          case (child_cnt[parents[i] - 1])
            2'd0: begin
              child0[parents[i] - 1]    <= i[2:0];
              child_cnt[parents[i] - 1] <= 2'd1;
            end
            2'd1: begin
              child1[parents[i] - 1]    <= i[2:0];
              child_cnt[parents[i] - 1] <= 2'd2;
            end
            2'd2: begin
              child2[parents[i] - 1]    <= i[2:0];
              child_cnt[parents[i] - 1] <= 2'd3;
            end
            default: begin
              // Ignore extra children beyond 3
              child_cnt[parents[i] - 1] <= child_cnt[parents[i] - 1];
            end
          endcase
        end
      end

      state        <= S_IDLE;
      done         <= 1'b0;
      magic_count  <= 3'd0;
      root_node    <= 3'd0;
      is_query     <= 1'b0;
      start_d      <= 1'b0;

      parity0      <= 1'b0;
      parity1      <= 1'b0;
      parity2      <= 1'b0;
      parity3      <= 1'b0;

      head         <= 3'd0;
      tail         <= 3'd0;

    end else begin
      // Normal operation
      start_d <= start;

      state   <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start && !start_d) begin
            // Latch command type and parameters
            is_query  <= (cmd_data == 2'b00);
            root_node <= node_id;

            if (cmd_data != 2'b00) begin
              // Color update: map cmd_data directly (as specified: others = color 0-3)
              // node_id in 1..8, index = node_id-1
              colors[node_id - 1] <= cmd_data - 2'b01;
            end

            // Prepare traversal only for queries
            if (cmd_data == 2'b00) begin
              // Initialize BFS queue with root
              head        <= 3'd0;
              tail        <= 3'd1;
              queue[0]    <= node_id - 1; // store index

              // Reset parities
              parity0     <= 1'b0;
              parity1     <= 1'b0;
              parity2     <= 1'b0;
              parity3     <= 1'b0;
            end
          end
        end

        S_PREP: begin
          // Not used in this implementation (kept for extensibility)
        end

        S_TRAVERSE: begin
          done <= 1'b0;
          if (head < tail) begin
            // Dequeue one node per cycle
            reg [2:0] cur_idx;
            reg [1:0] col;
            cur_idx = queue[head];

            // Update color parity for this node
            col = colors[cur_idx];
            case (col)
              2'd0: parity0 <= ~parity0;
              2'd1: parity1 <= ~parity1;
              2'd2: parity2 <= ~parity2;
              2'd3: parity3 <= ~parity3;
            endcase

            // Enqueue children of cur_idx
            case (child_cnt[cur_idx])
              2'd0: begin
                // no children
              end
              2'd1: begin
                queue[tail] <= child0[cur_idx];
                tail        <= tail + 3'd1;
              end
              2'd2: begin
                queue[tail]     <= child0[cur_idx];
                queue[tail + 1] <= child1[cur_idx];
                tail            <= tail + 3'd2;
              end
              2'd3: begin
                queue[tail]     <= child0[cur_idx];
                queue[tail + 1] <= child1[cur_idx];
                queue[tail + 2] <= child2[cur_idx];
                tail            <= tail + 3'd3;
              end
              default: begin
              end
            endcase

            head <= head + 3'd1;
          end
        end

        S_DONE: begin
          // Hold outputs until next start or reset
          done <= 1'b1;
        end

        default: begin
        end
      endcase

      // When traversal ends, compute magic_count (combinational-style but registered here)
      if (state == S_TRAVERSE && head >= tail) begin
        // All nodes processed, compute count of colors with odd parity
        magic_count <= (parity0 ? 3'd1 : 3'd0) +
                       (parity1 ? 3'd1 : 3'd0) +
                       (parity2 ? 3'd1 : 3'd0) +
                       (parity3 ? 3'd1 : 3'd0);
      end
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start && !start_d) begin
          if (cmd_data == 2'b00) begin
            // Query: move to traversal
            next_state = S_TRAVERSE;
          end else begin
            // Update: single cycle, go directly to DONE
            next_state = S_DONE;
          end
        end
      end

      S_TRAVERSE: begin
        if (head >= tail) begin
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        // Wait for next start pulse to return to IDLE
        if (start && !start_d) begin
          next_state = S_IDLE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule