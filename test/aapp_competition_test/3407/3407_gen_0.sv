module tree_coordinate_placement(
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [7:0][7:0] adj_matrix,
  output reg [15:0] x_coords [0:7],
  output reg [15:0] y_coords [0:7],
  output reg done
);

  // Direction vectors for 8 directions (45-degree increments), approximated in Q8.8
  // Order: 0:0deg,1:45deg,2:90deg,3:135deg,4:180deg,5:225deg,6:270deg,7:315deg
  // cos/sin approximations scaled by 256 and rounded
  localparam signed [15:0] DX_LUT [0:7] = '{
    16'sd256,  // 1.000 * 256
    16'sd181,  // 0.707 * 256
    16'sd0,    // 0
    -16'sd181, // -0.707 * 256
    -16'sd256, // -1.000 * 256
    -16'sd181, // -0.707 * 256
    16'sd0,    // 0
    16'sd181   // 0.707 * 256
  };

  localparam signed [15:0] DY_LUT [0:7] = '{
    16'sd0,    // 0
    16'sd181,  // 0.707 * 256
    16'sd256,  // 1.000 * 256
    16'sd181,  // 0.707 * 256
    16'sd0,    // 0
    -16'sd181, // -0.707 * 256
    -16'sd256, // -1.000 * 256
    -16'sd181  // -0.707 * 256
  };

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_SETUP  = 3'd2,
    S_PLACE  = 3'd3,
    S_DONE   = 3'd4
  } state_t;

  state_t state, next_state;

  // BFS/placement related registers
  reg [2:0] cur_node;                // current parent node index
  reg [2:0] scan_child;              // scanning child index
  reg [2:0] dir_index;               // direction index for child placement

  reg visited [0:7];                 // visited flags
  reg [2:0] parent [0:7];            // parent index (unused in placement but kept for completeness)

  // queue for BFS (size 8)
  reg [2:0] q_mem [0:7];
  reg [2:0] q_head;
  reg [2:0] q_tail;
  reg [3:0] q_count;                // up to 8

  // helper wires
  wire queue_not_empty = (q_count != 4'd0);
  wire queue_not_full  = (q_count != 4'd8);

  // sequential logic for FSM and datapath
  integer i;

  // pop current node when needed
  reg pop_cur_node;
  // push new child
  reg        push_en;
  reg [2:0]  push_val;

  // adjacency bit for current parent/child
  wire adj_bit = adj_matrix[cur_node][scan_child];

  // next-state logic (combinational)
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_SETUP;
      end
      S_SETUP: begin
        next_state = S_PLACE;
      end
      S_PLACE: begin
        if (!queue_not_empty)
          next_state = S_DONE;
      end
      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // main sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      // reset coordinates and control
      for (i = 0; i < 8; i = i + 1) begin
        x_coords[i] <= 16'sd0;
        y_coords[i] <= 16'sd0;
        visited[i]  <= 1'b0;
        parent[i]   <= 3'd0;
        q_mem[i]    <= 3'd0;
      end
      q_head   <= 3'd0;
      q_tail   <= 3'd0;
      q_count  <= 4'd0;
      cur_node <= 3'd0;
      scan_child <= 3'd0;
      dir_index  <= 3'd0;
      pop_cur_node <= 1'b0;
      push_en     <= 1'b0;
      push_val    <= 3'd0;
    end else begin
      state <= next_state;

      // default control signal values
      pop_cur_node <= 1'b0;
      push_en      <= 1'b0;
      push_val     <= 3'd0;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // nothing else here; S_INIT will handle
          end
        end

        S_INIT: begin
          // Clear all
          for (i = 0; i < 8; i = i + 1) begin
            x_coords[i] <= 16'sd0;
            y_coords[i] <= 16'sd0;
            visited[i]  <= 1'b0;
            parent[i]   <= 3'd0;
            q_mem[i]    <= 3'd0;
          end
          q_head   <= 3'd0;
          q_tail   <= 3'd0;
          q_count  <= 4'd0;
          cur_node <= 3'd0;
          scan_child <= 3'd0;
          dir_index  <= 3'd0;
          done <= 1'b0;
        end

        S_SETUP: begin
          // Initialize root node 0 at (0,0)
          x_coords[3'd0] <= 16'sd0;
          y_coords[3'd0] <= 16'sd0;
          visited[3'd0]  <= 1'b1;
          parent[3'd0]   <= 3'd0;

          // enqueue root if at least 1 node
          if (node_count != 3'd0) begin
            q_mem[3'd0] <= 3'd0;
            q_head      <= 3'd0;
            q_tail      <= 3'd1;
            q_count     <= 4'd1;
          end else begin
            q_head      <= 3'd0;
            q_tail      <= 3'd0;
            q_count     <= 4'd0;
          end

          cur_node   <= 3'd0;
          scan_child <= 3'd0;
          dir_index  <= 3'd0;
        end

        S_PLACE: begin
          // BFS-style iterative placement
          if (!queue_not_empty) begin
            // next_state will go to DONE
          end else begin
            // if starting scan for a new parent node (dir_index==0 and scan_child==0)
            if ((scan_child == 3'd0) && (dir_index == 3'd0)) begin
              // Pop next node from queue
              cur_node <= q_mem[q_head];
              q_head   <= q_head + 3'd1;
              q_count  <= q_count - 4'd1;
            end

            // Process current (cur_node) children one per cycle
            if (scan_child < node_count) begin
              if (adj_bit && !visited[scan_child]) begin
                // Assign direction index for this new child then increment for next
                // Ensure wrap-around over 8 directions
                // Place child
                // child_x = parent_x + DX_LUT[dir_index]
                // child_y = parent_y + DY_LUT[dir_index]
                x_coords[scan_child] <= x_coords[cur_node] + DX_LUT[dir_index];
                y_coords[scan_child] <= y_coords[cur_node] + DY_LUT[dir_index];
                visited[scan_child]  <= 1'b1;
                parent[scan_child]   <= cur_node;

                // Enqueue child if queue not full
                if (queue_not_full) begin
                  q_mem[q_tail] <= scan_child;
                  q_tail        <= q_tail + 3'd1;
                  q_count       <= q_count + 4'd1;
                end

                // advance direction (mod 8)
                dir_index <= (dir_index == 3'd7) ? 3'd0 : (dir_index + 3'd1);
              end

              // move to next potential child index
              scan_child <= scan_child + 3'd1;
            end else begin
              // Finished scanning all possible children for this parent
              // Prepare for next node from queue if any
              scan_child <= 3'd0;
              dir_index  <= 3'd0;

              if (!queue_not_empty) begin
                // nothing, S_DONE will be next
              end else begin
                // Next cycle will pop new parent (handled at top of this block)
              end
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // hold coordinates stable until next start (state goes to IDLE when start deasserted)
        end

        default: begin
          // safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule