module longest_menu_path(
  input clk, // System clock
  input rst_n, // Active-low reset
  input start, // Start computation (pulse high) when inputs are ready
  input [3:0] n, // Number of dishes (1-8) (0-based input: 0=1 dish, 7=8 dishes)
  input [63:0] adjacency, // Adjacency matrix (flattened 8x8) [i][j] = dish i+1 to j+1 edge
  output reg [3:0] max_path_length, // Maximum found path length (0-8)
  output reg done // High when computation complete
);

  // FSM state encoding
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_PUSH      = 3'd2,
    S_ADVANCE   = 3'd3,
    S_POP       = 3'd4,
    S_TERMINATE = 3'd5
  } state_t;
  state_t state, next_state;

  // Internal control and stacks
  reg [2:0] start_node_r;
  reg [2:0] cur_node;
  reg [7:0] cur_mask;
  reg [3:0] cur_len;
  reg [2:0] cur_nbr;
  reg [2:0] next_nbr;
  reg [2:0] stack_ptr;        // 0..8 valid entries
  reg [7:0] stack_mask [0:7]; // visited mask stack
  reg [2:0] stack_node [0:7]; // current node stack
  reg [2:0] stack_nbr [0:7];  // next neighbor to try stack
  reg [3:0] stack_len [0:7];  // path length at each frame

  // For popping update: length after backtrack
  reg [3:0] len_after_pop;
  reg       pop_happened;

  // Compute block: combinatorial logic for transitions
  always @(*) begin
    // Defaults to avoid latches
    next_state      = state;
    max_path_length = max_path_length;
    done            = 1'b0;

    // If start is high at term, finish immediately
    if (state == S_TERMINATE) begin
      next_state = S_IDLE;
      done       = 1'b1;
      max_path_length = max_path_length; // hold final result
    end

    unique case (state)
      S_IDLE: begin
        done = 1'b1; // ready to accept a new start
        if (start) next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_PUSH; // push start node this cycle
      end

      S_PUSH: begin
        // After pushing, decide what to do next
        if (stack_ptr == 0) begin
          // stack underflow shouldn't happen; treat as no expansion
          next_state = S_TERMINATE;
        end else if (next_nbr < n) begin
          next_state = S_ADVANCE; // we have a valid next neighbor to explore
        end else begin
          next_state = S_POP;     // dead end at this node, backtrack
        end
      end

      S_ADVANCE: begin
        // We will push the neighbor found in S_PUSH
        // After push, continue exploring new head
        if (stack_ptr == 0) begin
          // Shouldn't occur; guard
          next_state = S_TERMINATE;
        end else if (next_nbr < n) begin
          next_state = S_PUSH; // push new head (there is a valid neighbor)
        end else begin
          next_state = S_POP;  // no neighbors; dead end
        end
      end

      S_POP: begin
        // After popping, either backtrack to previous frame or finish
        if (stack_ptr == 0) begin
          next_state = S_TERMINATE; // fully popped -> done
        end else begin
          // Check if the frame at top has a next neighbor
          if (stack_nbr[stack_ptr-1] < n) begin
            next_state = S_PUSH; // resume exploring from the previous frame
          end else begin
            next_state = S_POP;  // keep popping if no neighbors left
          end
        end
      end

      S_TERMINATE: begin
        next_state = S_IDLE;
        done       = 1'b1;
      end
    endcase
  end

  // State update and datapath
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      // Reset datapath
      state         <= S_IDLE;
      max_path_length <= 4'd0;
      start_node_r  <= 3'd0;
      cur_node      <= 3'd0;
      cur_mask      <= 8'd0;
      cur_len       <= 4'd0;
      cur_nbr       <= 3'd0;
      next_nbr      <= 3'd0;
      stack_ptr     <= 3'd0;
      len_after_pop <= 4'd0;
      pop_happened  <= 1'b0;
      // Clear stacks
      for (int i = 0; i < 8; i++) begin
        stack_mask[i] <= 8'd0;
        stack_node[i] <= 3'd0;
        stack_nbr[i]  <= 3'd0;
        stack_len[i]  <= 4'd0;
      end
      done          <= 1'b0;
    end else begin
      // State machine and datapath
      state <= next_state;
      // Defaults
      pop_happened <= 1'b0;

      unique case (next_state)
        S_IDLE: begin
          // idle; nothing to do, wait for start
        end

        S_INIT: begin
          // Sample start node from input
          start_node_r <= n[2:0];        // 0..7 (n is 0..7 to mean 1..8 nodes)
          cur_node     <= n[2:0];        // use as current node too
          cur_mask     <= 8'd0;
          cur_len      <= 4'd0;
          cur_nbr      <= 3'd0;
          next_nbr     <= 3'd0;
          stack_ptr    <= 3'd0;
          // Determine first neighbor of the start node to try
          if (n == 4'd0) begin
            // Single node graph: no neighbors
            next_nbr <= 3'd0; // will be invalid (< n)
          end else begin
            // Find first j (0..n-1) where edge exists and j < n
            for (int j = 0; j < 8; j++) begin
              if (j < n[2:0]) begin
                if (adjacency[n[2:0]*8 + j]) begin
                  next_nbr <= j[2:0];
                  break;
                end else begin
                  next_nbr <= 3'd0; // default until found
                end
              end
            end
          end
        end

        S_PUSH: begin
          // We are pushing either:
          // - The start node (cur_len=1, cur_mask with start bit set) OR
          // - A neighbor node (len after pop + 1)
          if (stack_ptr == 3'd0) begin
            // First push: use start node from INIT; its first neighbor is in next_nbr
            cur_node <= start_node_r;
            cur_mask <= (1 << start_node_r);
            cur_len  <= 4'd1;
          end else begin
            // We are pushing a neighbor; cur_len = len_after_pop + 1
            cur_node <= next_nbr;
            cur_mask <= (1 << next_nbr);
            cur_len  <= len_after_pop + 1;
          end

          // Write frame to stack
          if (stack_ptr < 3'd8) begin
            stack_node[stack_ptr] <= cur_node;
            stack_mask[stack_ptr] <= cur_mask;
            stack_len[stack_ptr]  <= cur_len;
            stack_nbr[stack_ptr]  <= next_nbr; // neighbor to try from this node
            stack_ptr             <= stack_ptr + 1;
          end
        end

        S_ADVANCE: begin
          // The frame at top already has next_nbr that was valid.
          // Prepare the neighbor's own next neighbor candidate for the next push.
          cur_nbr <= next_nbr; // just for clarity (not used combinatorially)
          if (next_nbr + 1 < n) begin
            // Find the next valid neighbor j' > next_nbr
            for (int j = 0; j < 8; j++) begin
              if ((j > next_nbr) && (j < n[2:0])) begin
                if (adjacency[next_nbr*8 + j]) begin
                  next_nbr <= j[2:0];
                  break;
                end else begin
                  next_nbr <= 3'd0; // default until found
                end
              end
            end
          end else begin
            // No neighbor beyond next_nbr within range
            next_nbr <= 3'd0; // invalid
          end
        end

        S_POP: begin
          if (stack_ptr > 3'd0) begin
            // Pop top frame
            stack_ptr <= stack_ptr - 1;
            // Update max_path_length on backtrack
            if (stack_len[stack_ptr-1] > max_path_length) begin
              max_path_length <= stack_len[stack_ptr-1];
            end
            // Length after popping to this frame is its stored length
            len_after_pop <= stack_len[stack_ptr-1];
            pop_happened  <= 1'b1;
            // Prepare the previous frame's next neighbor to try
            if (stack_nbr[stack_ptr-1] + 1 < n) begin
              for (int j = 0; j < 8; j++) begin
                if ((j > stack_nbr[stack_ptr-1]) && (j < n[2:0])) begin
                  if (adjacency[stack_node[stack_ptr-1]*8 + j]) begin
                    next_nbr <= j[2:0];
                    break;
                  end else begin
                    next_nbr <= 3'd0;
                  end
                end
              end
            end else begin
              next_nbr <= 3'd0; // mark invalid to keep popping
            end
          end else begin
            // stack underflow: finished
            next_nbr <= 3'd0;
          end
        end

        S_TERMINATE: begin
          // Hold outputs; next_state will return to IDLE
          done <= 1'b1;
        end

        default: begin
          // Should never get here
        end
      endcase
    end
  end

endmodule
