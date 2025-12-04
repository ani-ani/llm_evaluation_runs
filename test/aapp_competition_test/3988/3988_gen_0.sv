module graph_reachability_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] start_node,
  input [2:0] graph_nodes [0:15][0:2], // [t,u,v]
  input [3:0] edge_count,
  output reg [3:0] max_reachable,
  output reg [3:0] min_reachable,
  output reg [15:0] max_orient,
  output reg [15:0] min_orient,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    S_RESET       = 2'b00,
    S_PROCESS_MAX = 2'b01,
    S_PROCESS_MIN = 2'b10,
    S_DONE        = 2'b11
  } state_t;

  state_t state, next_state;

  // Latched inputs
  reg [2:0] start_node_q;
  reg [2:0] edge_t_q    [0:15];
  reg [2:0] edge_u_q    [0:15];
  reg [2:0] edge_v_q    [0:15];
  reg [3:0] edge_count_q;

  // BFS related
  reg [7:0] visited;
  reg [2:0] queue      [0:7];
  reg [2:0] q_head;
  reg [2:0] q_tail;
  reg [3:0] reachable_cnt;

  // Orientation registers (being constructed)
  reg [15:0] orient_cur; // current plan under construction

  // Edge and node iteration indices
  reg [4:0] edge_idx;    // up to 16

  // Helper wires for edge type
  wire is_directed  = (edge_t_q[edge_idx] == 3'd1);
  wire is_undirected= (edge_t_q[edge_idx] == 3'd2);

  // Functions
  function automatic [7:0] set_bit;
    input [7:0] vec;
    input [2:0] idx;
    reg   [7:0] tmp;
  begin
    tmp      = vec;
    tmp[idx] = 1'b1;
    set_bit  = tmp;
  end
  endfunction

  function automatic bit get_bit;
    input [7:0] vec;
    input [2:0] idx;
  begin
    get_bit = vec[idx];
  end
  endfunction

  // BFS queue empty check
  wire queue_empty = (q_head == q_tail);

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_RESET: begin
        if (start)
          next_state = S_PROCESS_MAX;
      end
      S_PROCESS_MAX: begin
        // Transition when BFS for max finished
        if (queue_empty && (edge_idx == edge_count_q))
          next_state = S_PROCESS_MIN;
      end
      S_PROCESS_MIN: begin
        // Transition when BFS for min finished
        if (queue_empty && (edge_idx == edge_count_q))
          next_state = S_DONE;
      end
      S_DONE: begin
        // After one cycle done pulse, wait for next start
        if (start)
          next_state = S_PROCESS_MAX;
        else if (!rst_n)
          next_state = S_RESET;
        else
          next_state = S_DONE;
      end
      default: next_state = S_RESET;
    endcase
  end

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_RESET;
      start_node_q   <= 3'd0;
      edge_count_q   <= 4'd0;
      for (i = 0; i < 16; i = i + 1) begin
        edge_t_q[i]  <= 3'd0;
        edge_u_q[i]  <= 3'd0;
        edge_v_q[i]  <= 3'd0;
      end
      max_reachable  <= 4'd0;
      min_reachable  <= 4'd0;
      max_orient     <= 16'd0;
      min_orient     <= 16'd0;
      done           <= 1'b0;
      visited        <= 8'd0;
      q_head         <= 3'd0;
      q_tail         <= 3'd0;
      reachable_cnt  <= 4'd0;
      orient_cur     <= 16'd0;
      edge_idx       <= 5'd0;
    end else begin
      state <= next_state;
      done  <= 1'b0; // default; asserted only in S_DONE

      case (state)
        S_RESET: begin
          // Capture inputs when start asserted
          if (start) begin
            start_node_q <= start_node;
            edge_count_q <= edge_count;
            for (i = 0; i < 16; i = i + 1) begin
              edge_t_q[i] <= graph_nodes[i][0];
              edge_u_q[i] <= graph_nodes[i][1];
              edge_v_q[i] <= graph_nodes[i][2];
            end

            // Initialize for PROCESS_MAX BFS
            visited       <= 8'd0;
            visited[start_node] <= 1'b1;
            queue[0]      <= start_node;
            q_head        <= 3'd0;
            q_tail        <= 3'd1;
            reachable_cnt <= 4'd1; // count start node
            orient_cur    <= 16'd0;
            edge_idx      <= 5'd0;
          end else begin
            // Keep outputs cleared while idle
            max_reachable <= 4'd0;
            min_reachable <= 4'd0;
            max_orient    <= 16'd0;
            min_orient    <= 16'd0;
            visited       <= 8'd0;
            q_head        <= 3'd0;
            q_tail        <= 3'd0;
            reachable_cnt <= 4'd0;
            orient_cur    <= 16'd0;
            edge_idx      <= 5'd0;
          end
        end

        S_PROCESS_MAX: begin
          // BFS for maximizing reachability

          // If queue not empty: expand one node this cycle
          if (!queue_empty) begin
            reg [2:0] cur_node;
            cur_node = queue[q_head];
            q_head   <= q_head + 3'd1;

            // Scan all edges over multiple cycles: one edge per cycle
            edge_idx <= 5'd0;
          end else begin
            // queue_empty: continue scanning remaining edges if any pending
            if (edge_idx < edge_count_q) begin
              // Edge scanning / orientation decision for this edge index
              reg [2:0] t_local, u_local, v_local;
              reg       bit_set;
              t_local = edge_t_q[edge_idx];
              u_local = edge_u_q[edge_idx];
              v_local = edge_v_q[edge_idx];
              bit_set = orient_cur[edge_idx];

              // Decide orientation following max policy only if undirected
              if (t_local == 3'd1) begin
                // Directed: assume graph_nodes direction u->v
                // If from-node visited and to-node not visited, add
                if (get_bit(visited,u_local) && !get_bit(visited,v_local)) begin
                  visited           <= set_bit(visited, v_local);
                  queue[q_tail]    <= v_local;
                  q_tail           <= q_tail + 3'd1;
                  reachable_cnt    <= reachable_cnt + 4'd1;
                end
                // Orientation bit for directed edges fixed as '+' (u->v)
                orient_cur[edge_idx] <= 1'b1;
              end else if (t_local == 3'd2) begin
                // Undirected: choose orientation to improve reachability
                // Prefer orientation from visited -> unvisited; if both or none qualify,
                // fall back to '+' to keep deterministic.
                if (get_bit(visited,u_local) && !get_bit(visited,v_local)) begin
                  // u -> v
                  orient_cur[edge_idx] <= 1'b1;
                  visited              <= set_bit(visited, v_local);
                  queue[q_tail]       <= v_local;
                  q_tail              <= q_tail + 3'd1;
                  reachable_cnt       <= reachable_cnt + 4'd1;
                end else if (get_bit(visited,v_local) && !get_bit(visited,u_local)) begin
                  // v -> u
                  orient_cur[edge_idx] <= 1'b0;
                  visited              <= set_bit(visited, u_local);
                  queue[q_tail]       <= u_local;
                  q_tail              <= q_tail + 3'd1;
                  reachable_cnt       <= reachable_cnt + 4'd1;
                end else begin
                  // No improvement; default to '+' (u->v)
                  orient_cur[edge_idx] <= 1'b1;
                end
              end else begin
                // t==0 or other: ignore; orientation 0
                orient_cur[edge_idx] <= 1'b0;
              end

              edge_idx <= edge_idx + 5'd1;
            end else begin
              // All edges processed and queue_empty; finish MAX plan
              max_reachable <= reachable_cnt;
              max_orient    <= orient_cur;

              // Prepare for MIN: reset BFS, invert undirected orientations
              visited        <= 8'd0;
              visited[start_node_q] <= 1'b1;
              queue[0]       <= start_node_q;
              q_head         <= 3'd0;
              q_tail         <= 3'd1;
              reachable_cnt  <= 4'd1;
              edge_idx       <= 5'd0;

              // Initialize orient_cur for MIN by flipping undirected bits
              for (i = 0; i < 16; i = i + 1) begin
                if (edge_t_q[i] == 3'd2)
                  orient_cur[i] <= ~max_orient[i];
                else if (edge_t_q[i] == 3'd1)
                  orient_cur[i] <= 1'b1; // directed fixed
                else
                  orient_cur[i] <= 1'b0;
              end
            end
          end
        end

        S_PROCESS_MIN: begin
          // BFS for minimizing reachability given fixed orientations:
          // - directed: u->v, bit=1
          // - undirected: orientation is complement of max_orient

          if (!queue_empty) begin
            reg [2:0] cur_node2;
            cur_node2 = queue[q_head];
            q_head    <= q_head + 3'd1;
            edge_idx  <= 5'd0;
          end else begin
            if (edge_idx < edge_count_q) begin
              // Traverse edges as per orient_cur
              reg [2:0] t_local2, u_local2, v_local2;
              reg       o_bit;
              t_local2 = edge_t_q[edge_idx];
              u_local2 = edge_u_q[edge_idx];
              v_local2 = edge_v_q[edge_idx];
              o_bit    = orient_cur[edge_idx];

              if (t_local2 == 3'd1) begin
                // Directed u->v
                if (get_bit(visited,u_local2) && !get_bit(visited,v_local2)) begin
                  visited           <= set_bit(visited, v_local2);
                  queue[q_tail]    <= v_local2;
                  q_tail           <= q_tail + 3'd1;
                  reachable_cnt    <= reachable_cnt + 4'd1;
                end
              end else if (t_local2 == 3'd2) begin
                // Undirected: single directed orientation defined by o_bit
                if (o_bit) begin
                  // u->v
                  if (get_bit(visited,u_local2) && !get_bit(visited,v_local2)) begin
                    visited        <= set_bit(visited, v_local2);
                    queue[q_tail] <= v_local2;
                    q_tail        <= q_tail + 3'd1;
                    reachable_cnt <= reachable_cnt + 4'd1;
                  end
                end else begin
                  // v->u
                  if (get_bit(visited,v_local2) && !get_bit(visited,u_local2)) begin
                    visited        <= set_bit(visited, u_local2);
                    queue[q_tail] <= u_local2;
                    q_tail        <= q_tail + 3'd1;
                    reachable_cnt <= reachable_cnt + 4'd1;
                  end
                end
              end

              edge_idx <= edge_idx + 5'd1;
            end else begin
              // All edges processed and queue_empty: finalize MIN
              min_reachable <= reachable_cnt;
              min_orient    <= orient_cur;
            end
          end
        end

        S_DONE: begin
          // Signal completion for one cycle
          done <= 1'b1;

          // If new start occurs, reinitialize for next MAX computation
          if (start) begin
            start_node_q <= start_node;
            edge_count_q <= edge_count;
            for (i = 0; i < 16; i = i + 1) begin
              edge_t_q[i] <= graph_nodes[i][0];
              edge_u_q[i] <= graph_nodes[i][1];
              edge_v_q[i] <= graph_nodes[i][2];
            end
            visited        <= 8'd0;
            visited[start_node] <= 1'b1;
            queue[0]       <= start_node;
            q_head         <= 3'd0;
            q_tail         <= 3'd1;
            reachable_cnt  <= 4'd1;
            orient_cur     <= 16'd0;
            edge_idx       <= 5'd0;
          end
        end

        default: ;
      endcase
    end
  end

endmodule