module max_tree_group(
  input clk,
  input rst_n,
  input start,
  input [19:0] h_matrix [0:15],
  input [19:0] v_matrix [0:15],
  output reg [4:0] max_group_size,
  output reg done
);
  // Parameters
  parameter N = 16; // 4x4
  parameter IDLE = 2'b00;
  parameter ADJ = 2'b01;
  parameter BFS = 2'b10;
  parameter DONE = 2'b11;

  // State
  reg [1:0] state, next_state;
  reg [5:0] cycle_cnt; // up to 63 (enough for ADJ precompute + BFS)

  // Adjacency precompute (50 cycles for 16x16 pair checks)
  reg [15:0] adj_r [0:15]; // 16x16 adjacency matrix (symmetric)
  reg [4:0] i_adj, j_adj;  // pair indexer (0..15), (0..15)
  reg [5:0] n_adj_left;    // remaining pairs in this row
  wire pair_done = (j_adj == 5'd15);
  wire [3:0] i_flat = i_adj;
  wire [3:0] j_flat = j_adj;
  wire [19:0] hi = h_matrix[i_flat];
  wire [19:0] hj = h_matrix[j_flat];
  wire [19:0] vi = v_matrix[i_flat];
  wire [19:0] vj = v_matrix[j_flat];
  wire [20:0] diff_h = $signed(21'(hj) - $signed(21'(hi)));
  wire [20:0] diff_v = $signed(21'(vi) - $signed(21'(vj)));
  wire [20:0] neg_diff_h = -diff_h;
  wire [20:0] neg_diff_v = -diff_diff_v;
  wire [20:0] t_num = (diff_v[20] ? neg_diff_h : diff_h);
  wire t_nonzero = (diff_h != 21'd0);
  wire [20:0] t_den = (diff_v != 21'd0) ? diff_v : 21'd1;
  wire [20:0] t_num_pos = (t_num[20] ? 21'd0 : t_num);
  wire can_equal;
  assign can_equal = (vi == vj) ? (hi == hj) :
                    ((diff_v != 21'd0) && (diff_h != 21'd0) &&
                     ((diff_v[20] && diff_h[20]) || (!diff_v[20] && !diff_h[20])) &&
                     (t_num_pos < t_den));

  // BFS structures
  reg [3:0] bfs_start_node; // current component root
  reg [3:0] bfs_head, bfs_tail; // queue pointers
  reg [3:0] queue [0:15]; // BFS queue
  reg [15:0] visited; // visited nodes bitvector
  reg [4:0] bfs_size; // size of current component (0..16)
  reg [4:0] max_size; // max component size found so far (0..16)
  reg bfs_running;

  // Helper: queue empty flag
  wire queue_empty = (bfs_head == bfs_tail);

  // Update adjacency in ADJ state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      adj_r[0] <= 16'd0;
      adj_r[1] <= 16'd0;
      adj_r[2] <= 16'd0;
      adj_r[3] <= 16'd0;
      adj_r[4] <= 16'd0;
      adj_r[5] <= 16'd0;
      adj_r[6] <= 16'd0;
      adj_r[7] <= 16'd0;
      adj_r[8] <= 16'd0;
      adj_r[9] <= 16'd0;
      adj_r[10] <= 16'd0;
      adj_r[11] <= 16'd0;
      adj_r[12] <= 16'd0;
      adj_r[13] <= 16'd0;
      adj_r[14] <= 16'd0;
      adj_r[15] <= 16'd0;
      i_adj <= 5'd0;
      j_adj <= 5'd0;
      n_adj_left <= 6'd0;
    end else if (state == ADJ) begin
      if (i_adj < 5'd16) begin
        if (j_adj == 5'd0) n_adj_left <= 6'd16;
        if (n_adj_left > 6'd0) begin
          if (i_adj != j_adj) begin
            if (can_equal) begin
              if (i_adj < j_adj) begin
                adj_r[i_adj][j_adj] <= 1'b1;
                adj_r[j_adj][i_adj] <= 1'b1;
              end else begin
                // already written when i<j; keep symmetry
              end
            end
          end
          j_adj <= j_adj + 1'b1;
          n_adj_left <= n_adj_left - 1'b1;
        end
        if (pair_done) begin
          i_adj <= i_adj + 1'b1;
          j_adj <= 5'd0;
        end
      end
    end else begin
      // latch last i/j only to avoid unintended latches
      i_adj <= i_adj;
      j_adj <= j_adj;
      n_adj_left <= n_adj_left;
    end
  end

  // BFS sequential logic
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bfs_start_node <= 4'd0;
      bfs_head <= 4'd0;
      bfs_tail <= 4'd0;
      visited <= 16'd0;
      bfs_size <= 5'd0;
      max_size <= 5'd0;
      bfs_running <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          bfs_start_node <= 4'd0;
          bfs_head <= 4'd0;
          bfs_tail <= 4'd0;
          visited <= 16'd0;
          bfs_size <= 5'd0;
          max_size <= 5'd0;
          bfs_running <= 1'b0;
        end

        ADJ: begin
          // hold state
          bfs_start_node <= bfs_start_node;
          bfs_head <= bfs_head;
          bfs_tail <= bfs_tail;
          visited <= visited;
          bfs_size <= bfs_size;
          max_size <= max_size;
          bfs_running <= bfs_running;
        end

        BFS: begin
          if (!bfs_running) begin
            // start a new component
            bfs_head <= 4'd0;
            bfs_tail <= 4'd0;
            visited <= visited | (1 << bfs_start_node);
            queue[0] <= bfs_start_node;
            bfs_tail <= bfs_tail + 1'b1;
            bfs_size <= 5'd1;
            bfs_running <= 1'b1;
          end else begin
            if (!queue_empty) begin
              // process current head
              bfs_head <= bfs_head + 1'b1;
              // scan neighbors and enqueue unvisited ones
              for (k = 0; k < N; k = k + 1) begin
                if (adj_r[queue[bfs_head]][k] && !visited[k]) begin
                  visited[k] <= 1'b1;
                  queue[bfs_tail] <= k;
                  bfs_tail <= bfs_tail + 1'b1;
                  bfs_size <= bfs_size + 1'b1; // discovered new node
                end
              end
            end else begin
              // component finished
              if (bfs_size > max_size) begin
                max_size <= bfs_size;
              end
              if (bfs_start_node < 4'd15) begin
                bfs_start_node <= bfs_start_node + 1'b1;
                bfs_head <= 4'd0;
                bfs_tail <= 4'd0;
                bfs_size <= 5'd0;
                bfs_running <= 1'b0; // start next component next cycle
              end else begin
                // all components processed; stay here until DONE
                bfs_running <= 1'b0;
              end
            end
          end
        end

        DONE: begin
          // hold final values
          bfs_start_node <= bfs_start_node;
          bfs_head <= bfs_head;
          bfs_tail <= bfs_tail;
          visited <= visited;
          bfs_size <= bfs_size;
          max_size <= max_size;
          bfs_running <= bfs_running;
        end
      endcase
    end
  end

  // FSM: combinational next state logic + cycle counter
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = ADJ;
        end
      end
      ADJ: begin
        if (i_adj >= 5'd16 && j_adj == 5'd0 && n_adj_left == 6'd0) begin
          next_state = BFS;
        end
      end
      BFS: begin
        if (!bfs_running && bfs_start_node >= 4'd15) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // FSM: state and cycle counter update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_cnt <= 6'd0;
    end else begin
      state <= next_state;
      cycle_cnt <= cycle_cnt + 1'b1;
    end
  end

  // Outputs
  always @(*) begin
    done = (state == DONE);
    max_group_size = max_size;
  end
endmodule
