module longest_menu_path(
  input clk, // System clock
  input rst_n, // Active-low reset
  input start, // Start computation (pulse high) when inputs are ready
  input [3:0] n, // Number of dishes (1-8) (0-based input: 0=1 dish, 7=8 dishes)
  input [63:0] adjacency, // Adjacency matrix (flattened 8x8)
  output reg [3:0] max_path_length, // Maximum found path length (0-8)
  output reg done // High when computation complete
);

  // Interpret n as node_count = n + 1 (1..8)
  reg [3:0] node_count;

  // FSM states
  localparam S_IDLE       = 3'd0;
  localparam S_INIT_START = 3'd1;
  localparam S_POP        = 3'd2;
  localparam S_EXPAND     = 3'd3;
  localparam S_DONE       = 3'd4;

  reg [2:0] state, next_state;

  // BFS with backtracking implemented using path stack entries
  // Each entry: {visited[7:0], last_node[2:0], path_len[3:0]}
  // Total bits per entry = 8 + 3 + 4 = 15 bits
  localparam ENTRY_W = 15;
  reg [ENTRY_W-1:0] stack [0:255];
  reg [7:0] stack_ptr; // number of valid entries (top at stack_ptr-1)

  // Current entry fields
  reg [7:0] cur_visited;
  reg [2:0] cur_node;
  reg [3:0] cur_len;

  // Neighbor iteration
  reg [2:0] neighbor_idx;

  // Helper wires
  wire [7:0] valid_nodes_mask;
  assign valid_nodes_mask = (node_count == 0) ? 8'b0 : ((8'h1 << node_count) - 1'b1);

  // Compute node_count (clamped to 8)
  always @(*) begin
    if (n[3] == 1'b1)
      node_count = 4'd8; // if n>=8, clamp to 8
    else
      node_count = n + 4'd1; // 0->1, ..., 7->8
  end

  // Extract adjacency bit: edge from i to j
  function automatic bit get_edge(
    input [63:0] adj,
    input [2:0] from,
    input [2:0] to
  );
    get_edge = adj[{from,3'b000} + to]; // from*8 + to
  endfunction

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_IDLE;
      max_path_length <= 4'd0;
      done            <= 1'b0;
      stack_ptr       <= 8'd0;
      neighbor_idx    <= 3'd0;
      cur_visited     <= 8'd0;
      cur_node        <= 3'd0;
      cur_len         <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize stack with all starting nodes 0..node_count-1
            stack_ptr       <= 8'd0;
            max_path_length <= 4'd0;
            if (node_count != 0) begin
              // Push each node as starting path
              // One node pushed per clock handled in S_INIT_START
            end
          end
        end

        S_INIT_START: begin
          // In this state we push all initial single-node paths
          // Use stack_ptr as index and neighbor_idx as node iterator
          if (neighbor_idx < node_count) begin
            // Prepare visited mask
            stack[stack_ptr] <= { (8'b1 << neighbor_idx), neighbor_idx[2:0], 4'd1 };
            stack_ptr        <= stack_ptr + 8'd1;
            neighbor_idx     <= neighbor_idx + 3'd1;
          end
        end

        S_POP: begin
          if (stack_ptr != 0) begin
            // Pop top entry
            stack_ptr   <= stack_ptr - 8'd1;
            {cur_visited, cur_node, cur_len} <= stack[stack_ptr - 8'd1];
            neighbor_idx <= 3'd0;
            // Update max_path_length
            if (cur_len > max_path_length)
              max_path_length <= cur_len;
          end
        end

        S_EXPAND: begin
          if (stack_ptr == 0) begin
            // No more entries to expand
          end else begin
            // Iterate neighbors; one neighbor per cycle
            if (neighbor_idx < node_count) begin
              if (get_edge(adjacency, cur_node, neighbor_idx) &&
                  !cur_visited[neighbor_idx]) begin
                // Create new path entry
                stack[stack_ptr] <= { (cur_visited | (8'b1 << neighbor_idx)),
                                      neighbor_idx[2:0],
                                      cur_len + 4'd1 };
                stack_ptr <= stack_ptr + 8'd1;
              end
              neighbor_idx <= neighbor_idx + 3'd1;
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // FSM next-state logic
  always @(*) begin
    next_state   = state;
    case (state)
      S_IDLE: begin
        if (start && (node_count != 0)) begin
          next_state = S_INIT_START;
        end else if (start && (node_count == 0)) begin
          next_state = S_DONE;
        end
      end

      S_INIT_START: begin
        if (neighbor_idx >= node_count) begin
          // Finished pushing initial nodes
          if (stack_ptr == 0)
            next_state = S_DONE;
          else
            next_state = S_POP;
        end
      end

      S_POP: begin
        if (stack_ptr == 0) begin
          next_state = S_DONE;
        end else begin
          next_state = S_EXPAND;
        end
      end

      S_EXPAND: begin
        if (stack_ptr == 0) begin
          // No more paths pending
          next_state = S_DONE;
        end else if (neighbor_idx >= node_count) begin
          // Done expanding current path, pop next
          next_state = S_POP;
        end
      end

      S_DONE: begin
        if (!start) begin
          // Wait for start to deassert before going idle
          next_state = S_IDLE;
        end
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule