module good_node_finder(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start computation
  input [2:0] edge_count, // number of edges (n-1, 0-7)
  input [2:0] node_a [0:7], // parent nodes (1-8)
  input [2:0] node_b [0:7], // child nodes (1-8)
  input [2:0] color  [0:7], // edge colors
  output reg [7:0] good_nodes, // bitmask of good nodes (bit0=node1, ... bit7=node8)
  output reg done // high when computation complete
);

  // State encoding
  localparam [1:0]
    S_IDLE      = 2'b00,
    S_CHECK_NODE= 2'b01,
    S_TRAVERSE  = 2'b10,
    S_DONE      = 2'b11;

  reg [1:0] state, next_state;

  // Current node index being evaluated (0..7 corresponds to node 1..8)
  reg [2:0] cur_node_idx;      // node id = cur_node_idx + 1

  // Flag indicating current node is still considered good
  reg       cur_node_good;

  // DFS stack depth (0..7)
  reg [2:0] sp;                // number of active entries

  // Stack entry fields
  reg [2:0] stack_node   [0:7]; // current node id at this depth (1..8)
  reg [2:0] stack_pcolor [0:7]; // parent color used to reach this node
  reg [2:0] stack_next_e [0:7]; // next edge index to examine for this node

  // Edge iteration during TRAVERSE
  reg [2:0] e_idx;           // current edge index (0..7)
  reg       found_child;     // indicates a non-leaf child found in scan

  // Latched start to detect rising edge (optional robustness)
  reg start_d;

  integer i;

  // Sequential logic: state, outputs, and control registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      good_nodes   <= 8'b0;
      done         <= 1'b0;
      cur_node_idx <= 3'd0;
      cur_node_good<= 1'b0;
      sp           <= 3'd0;
      e_idx        <= 3'd0;
      found_child  <= 1'b0;
      start_d      <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        stack_node[i]   <= 3'd0;
        stack_pcolor[i] <= 3'd0;
        stack_next_e[i] <= 3'd0;
      end
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start && !start_d) begin
            // Initialize for first node (node 1)
            good_nodes    <= 8'b0;
            cur_node_idx  <= 3'd0; // node1
            cur_node_good <= 1'b1;
            // Initialize root stack frame for this node
            sp                <= 3'd1;
            stack_node[0]     <= 3'd1;      // node id = 1
            stack_pcolor[0]   <= 3'b111;    // sentinel color (no match with 0-7)
            stack_next_e[0]   <= 3'd0;
            e_idx             <= 3'd0;
            found_child       <= 1'b0;
          end
        end

        S_CHECK_NODE: begin
          // Initialize DFS for new node when entering from next_state logic
          // All necessary signals are assigned in next_state decision block
        end

        S_TRAVERSE: begin
          // Depth-first traversal driven by one edge-scan step per cycle

          if (cur_node_good && (sp != 3'd0)) begin
            // Get current frame index
            reg [2:0] idx;
            reg [2:0] cur_n;
            reg [2:0] pcol;
            reg [2:0] ne;

            idx  = sp - 1'b1;
            cur_n= stack_node[idx];
            pcol = stack_pcolor[idx];
            ne   = stack_next_e[idx];

            // Start scanning edges from 'ne'
            e_idx       <= ne;
            found_child <= 1'b0;

            // Scan exactly one edge per cycle; if no edge used and all done, pop
            if (ne < edge_count) begin
              // Check if this edge is outgoing from cur_n and valid color
              if (node_a[ne] == cur_n) begin
                // Consecutive color check
                if (color[ne] == pcol) begin
                  // Violation: mark node bad and clear stack
                  cur_node_good <= 1'b0;
                  sp            <= 3'd0;
                end else begin
                  // Use this edge to go deeper
                  found_child         <= 1'b1;
                  // Update next edge for this frame
                  stack_next_e[idx]   <= ne + 1'b1;
                  // Push child frame
                  stack_node[sp]      <= node_b[ne];
                  stack_pcolor[sp]    <= color[ne];
                  stack_next_e[sp]    <= 3'd0;
                  sp                  <= sp + 1'b1;
                end
              end else begin
                // Not matching edge; advance scan index in next cycle
                stack_next_e[idx] <= ne + 1'b1;
              end
            end else begin
              // Completed scanning all edges for this node and no child taken this cycle
              // Pop this frame
              sp <= idx;
            end
          end

          // When cur_node_good becomes 0, stack is cleared; next_state logic will advance
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
          state <= S_IDLE;
        end
      endcase

      // When finishing traversal for a node (stack empty or bad), set good_nodes bit
      if (state == S_TRAVERSE) begin
        if (sp == 3'd0) begin
          if (cur_node_good) begin
            // Set corresponding bit for this good node
            // cur_node_idx in 0..7 maps to bit position
            good_nodes[cur_node_idx] <= 1'b1;
          end
        end
      end

      // On transition handled in next_state, initialize next node DFS context
      if (state == S_TRAVERSE && next_state == S_CHECK_NODE) begin
        // Move to next node index
        cur_node_idx  <= cur_node_idx + 1'b1;
        cur_node_good <= 1'b1;
        // Initialize stack with new root node
        sp                <= 3'd1;
        stack_node[0]     <= (cur_node_idx + 1'b1) + 3'd1; // (prev idx +1) +1 -> new node id
        stack_pcolor[0]   <= 3'b111; // sentinel
        stack_next_e[0]   <= 3'd0;
        e_idx             <= 3'd0;
        found_child       <= 1'b0;
      end

      if (state == S_IDLE && next_state == S_CHECK_NODE) begin
        // From IDLE to first CHECK_NODE: already initialized in IDLE when start
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start && !start_d)
          next_state = S_CHECK_NODE;
      end

      S_CHECK_NODE: begin
        // Immediately go to TRAVERSE to process current node
        next_state = S_TRAVERSE;
      end

      S_TRAVERSE: begin
        if (!cur_node_good) begin
          // Node failed; if more nodes to check, go to CHECK_NODE, else DONE
          if (cur_node_idx == 3'd7)
            next_state = S_DONE;
          else
            next_state = S_CHECK_NODE;
        end else if (sp == 3'd0) begin
          // Traversal complete successfully for this node
          if (cur_node_idx == 3'd7)
            next_state = S_DONE;
          else
            next_state = S_CHECK_NODE;
        end else begin
          // Still traversing
          next_state = S_TRAVERSE;
        end
      end

      S_DONE: begin
        // Stay in DONE until reset or a new start pulse (optional)
        if (start && !start_d)
          next_state = S_CHECK_NODE;
        else
          next_state = S_DONE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule