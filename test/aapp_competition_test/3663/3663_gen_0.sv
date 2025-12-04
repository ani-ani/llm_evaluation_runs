module army_move_calculator(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_nations,
  input [3:0] parent_node [0:7],
  input [15:0] move_costs [0:7],
  input [15:0] init_armies [0:7],
  input [15:0] req_armies [0:7],
  output reg [31:0] total_cost,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE         = 2'b00,
    PROCESS_BFS  = 2'b01,
    CALCULATE    = 2'b10,
    DONE_STATE   = 2'b11
  } state_t;

  state_t state, next_state;

  // BFS / processing order buffers
  reg [3:0] process_order [0:7];
  reg [3:0] queue       [0:7];
  reg [2:0] q_head;
  reg [2:0] q_tail;
  reg [3:0] order_count;
  reg [3:0] bfs_idx;
  reg [3:0] child_idx;

  // Node degree information for root detection
  reg [3:0] parent_count [0:7];
  reg [3:0] i_idx;

  // Calculation phase
  reg [3:0] calc_idx;        // index into process_order for processing
  reg [15:0] armies_at_node [0:7];

  // Counters for fixed latency handling
  reg [4:0] cycle_cnt;

  integer i;

  // Combinational next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESS_BFS;
      end
      PROCESS_BFS: begin
        // transition to CALCULATE when BFS order ready
        if (order_count == num_nations && num_nations != 0)
          next_state = CALCULATE;
        else if (num_nations == 0)
          next_state = DONE_STATE;
      end
      CALCULATE: begin
        // After 16 cycles from start, go to DONE
        if (cycle_cnt == 5'd15)
          next_state = DONE_STATE;
      end
      DONE_STATE: begin
        // Wait one cycle and return to IDLE (can be extended as needed)
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential state and control registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      total_cost  <= 32'd0;
      done        <= 1'b0;
      q_head      <= 3'd0;
      q_tail      <= 3'd0;
      order_count <= 4'd0;
      bfs_idx     <= 4'd0;
      child_idx   <= 4'd0;
      i_idx       <= 4'd0;
      calc_idx    <= 4'd0;
      cycle_cnt   <= 5'd0;
      for (i = 0; i < 8; i = i + 1) begin
        process_order[i] <= 4'd0;
        queue[i]         <= 4'd0;
        parent_count[i]  <= 4'd0;
        armies_at_node[i]<= 16'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          total_cost  <= 32'd0;
          cycle_cnt   <= 5'd0;
          order_count <= 4'd0;
          q_head      <= 3'd0;
          q_tail      <= 3'd0;
          bfs_idx     <= 4'd0;
          child_idx   <= 4'd0;
          i_idx       <= 4'd0;

          // Clear parent_count
          for (i = 0; i < 8; i = i + 1) begin
            parent_count[i] <= 4'd0;
          end

          // Initialize armies for potential use (will be finalized in CALCULATE)
          for (i = 0; i < 8; i = i + 1) begin
            armies_at_node[i] <= 16'd0;
          end
        end

        PROCESS_BFS: begin
          // Step 1: Build parent_count for nodes 0..num_nations-1
          if (i_idx < num_nations) begin
            // Count parent references for root detection
            if (parent_node[i_idx] < num_nations)
              parent_count[parent_node[i_idx]] <= parent_count[parent_node[i_idx]] + 4'd1;
            i_idx <= i_idx + 4'd1;
          end else if (q_tail == 0 && q_head == 0 && order_count == 0) begin
            // Step 2: Initialize queue with root(s): nodes with parent_count==0
            // Do this in one pass sequentially
            if (bfs_idx < num_nations) begin
              if (parent_count[bfs_idx] == 4'd0) begin
                queue[q_tail] <= bfs_idx[3:0];
                q_tail <= q_tail + 3'd1;
              end
              bfs_idx <= bfs_idx + 4'd1;
            end else begin
              // After enqueueing roots, initialize BFS indices for expansion
              bfs_idx   <= 4'd0;
              child_idx <= 4'd0;
            end
          end else begin
            // Step 3: BFS-like generation of order (root to leaves)
            if (q_head != q_tail && order_count < num_nations) begin
              // Current node from queue
              reg [3:0] curr;
              curr = queue[q_head];

              // Append to process_order (we will reverse later using calc_idx traversal)
              process_order[order_count] <= curr;
              order_count <= order_count + 4'd1;

              q_head <= q_head + 3'd1;

              // Enqueue children of curr (sequential scan over all possible nodes)
              if (child_idx < num_nations) begin
                if (parent_node[child_idx] == curr) begin
                  queue[q_tail] <= child_idx[3:0];
                  q_tail <= q_tail + 3'd1;
                end
                child_idx <= child_idx + 4'd1;
              end else begin
                // Reset child_idx for next parent
                child_idx <= 4'd0;
              end
            end
          end
        end

        CALCULATE: begin
          cycle_cnt <= cycle_cnt + 5'd1;

          // On entry to CALCULATE (cycle_cnt==0) initialize army states
          if (cycle_cnt == 5'd0) begin
            for (i = 0; i < 8; i = i + 1) begin
              if (i < num_nations)
                armies_at_node[i] <= init_armies[i];
              else
                armies_at_node[i] <= 16'd0;
            end
            calc_idx   <= (num_nations == 0) ? 4'd0 : (num_nations - 1'b1);
            total_cost <= 32'd0;
          end else begin
            // Process one node per cycle in reverse BFS order (leaf to root)
            if (num_nations != 0 && calc_idx < num_nations) begin
              reg [3:0] node;
              reg [3:0] p;
              reg [15:0] need;
              reg signed [16:0] diff;
              reg [15:0] abs_diff;
              reg [31:0] edge_cost;

              node = process_order[calc_idx];
              p    = parent_node[node];
              need = req_armies[node];

              diff = $signed({1'b0,armies_at_node[node]}) - $signed({1'b0,need});
              if (diff[16] == 1'b1)
                abs_diff = (~diff[15:0]) + 16'd1;  // two's complement absolute
              else
                abs_diff = diff[15:0];

              edge_cost = 32'd0;
              if (p < num_nations) begin
                edge_cost = abs_diff * move_costs[node];
                // Transfer surplus/deficit to parent
                if (diff > 0)
                  armies_at_node[p] <= armies_at_node[p] + diff[15:0];
                else if (diff < 0)
                  armies_at_node[p] <= armies_at_node[p] - abs_diff;
              end

              total_cost <= total_cost + edge_cost;

              if (calc_idx != 0)
                calc_idx <= calc_idx - 4'd1;
            end
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
          // Hold total_cost stable; return to IDLE when start is deasserted via next_state logic
        end

        default: begin
          // Should not occur, safe reset behavior
          state      <= IDLE;
          done       <= 1'b0;
          total_cost <= 32'd0;
        end
      endcase
    end
  end

endmodule