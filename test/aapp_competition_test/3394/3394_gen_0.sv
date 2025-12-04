module pizza_delivery_optimizer(
  input clk,                   // Clock signal
  input rst_n,                 // Active-low reset
  input start,                 // Start computation
  input [1:0] node_count,      // Number of nodes (2-4)
  input [2:0] edge_count,      // Number of edges (1-4)
  input [3:0][1:0] edge_src,   // Source nodes (4 edges max)
  input [3:0][1:0] edge_dest,  // Destination nodes (4 edges max)
  input [3:0][7:0] edge_weight,// Edge weights (0-255)
  input [1:0] order_count,     // Number of orders (1-3)
  input [2:0][7:0] order_spawn,// Order placement time (3 orders max)
  input [2:0][1:0] order_loc,  // Order locations (3 orders max)
  input [2:0][7:0] order_ready,// Order ready time (3 orders max)
  output reg [7:0] max_wait,   // Maximum wait time
  output reg done              // Computation complete
);

  // Constants
  localparam INF = 8'hFF; // Represent "infinite" distance (>= any valid path sum within constraints)

  // FSM states
  localparam [2:0]
    IDLE           = 3'd0,
    LOAD_DATA      = 3'd1,
    COMPUTE_GRAPH  = 3'd2,
    PROCESS_ORDERS = 3'd3,
    DONE           = 3'd4;

  reg [2:0] state, next_state;

  // Distance matrix for 4-node graph
  reg [7:0] dist [0:3][0:3];

  // Loop indices and control for Floyd-Warshall
  reg [1:0] fw_k;
  reg [1:0] fw_i;
  reg [1:0] fw_j;

  // Edge loading index
  reg [2:0] edge_idx;

  // Order processing
  reg [1:0] order_idx;        // index of current order (0..2)

  // Internal working registers
  reg [7:0] cur_time;
  reg [1:0] cur_loc;          // current node location
  reg [7:0] wait_time;
  reg [7:0] d_ik, d_kj, d_ij, new_d;
  reg [7:0] spawn_t, ready_t;
  reg [1:0] loc_t;
  reg [1:0] n_nodes;
  reg [1:0] n_orders;
  reg [2:0] n_edges;

  // Combinational wires for conditions
  wire last_edge      = (edge_idx == n_edges);
  wire fw_done        = (fw_k == n_nodes) && (fw_i == 2'd0) && (fw_j == 2'd0);
  wire orders_done    = (order_idx == n_orders);

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD_DATA;
      end
      LOAD_DATA: begin
        if (last_edge) next_state = COMPUTE_GRAPH;
      end
      COMPUTE_GRAPH: begin
        if (fw_done) next_state = PROCESS_ORDERS;
      end
      PROCESS_ORDERS: begin
        if (orders_done) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Main sequential logic
  integer x, y;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset logic
      done      <= 1'b0;
      max_wait  <= 8'd0;
      cur_time  <= 8'd0;
      cur_loc   <= 2'd0;
      order_idx <= 2'd0;
      edge_idx  <= 3'd0;
      fw_k      <= 2'd0;
      fw_i      <= 2'd0;
      fw_j      <= 2'd0;
      n_nodes   <= 2'd0;
      n_orders  <= 2'd0;
      n_edges   <= 3'd0;
      for (x = 0; x < 4; x = x + 1) begin
        for (y = 0; y < 4; y = y + 1) begin
          if (x == y) dist[x][y] <= 8'd0;
          else        dist[x][y] <= INF;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          done      <= 1'b0;
          max_wait  <= 8'd0;
          cur_time  <= 8'd0;
          cur_loc   <= 2'd0; // pizzeria at node 0
          order_idx <= 2'd0;
          edge_idx  <= 3'd0;
          fw_k      <= 2'd0;
          fw_i      <= 2'd0;
          fw_j      <= 2'd0;

          // Initialize distances to INF / 0 on state entry
          if (start) begin
            n_nodes  <= (node_count < 2'd2) ? 2'd2 : ((node_count > 2'd3) ? 2'd4 : node_count + 2'd0);
            n_orders <= order_count;
            n_edges  <= edge_count;
            for (x = 0; x < 4; x = x + 1) begin
              for (y = 0; y < 4; y = y + 1) begin
                if (x == y) dist[x][y] <= 8'd0;
                else        dist[x][y] <= INF;
              end
            end
          end
        end

        LOAD_DATA: begin
          // Load edges sequentially
          if (edge_idx < n_edges) begin
            if (edge_src[edge_idx] < n_nodes && edge_dest[edge_idx] < n_nodes) begin
              dist[edge_src[edge_idx]][edge_dest[edge_idx]] <= edge_weight[edge_idx];
              // Assume directed edges as typical; if undirected required, mirror here
            end
            edge_idx <= edge_idx + 3'd1;
          end
        end

        COMPUTE_GRAPH: begin
          // Scaled Floyd-Warshall over subset [0..n_nodes-1]
          // Perform one (i,j) update per cycle for current k
          if (fw_k < n_nodes) begin
            if (fw_i < n_nodes && fw_j < n_nodes) begin
              d_ik = dist[fw_i][fw_k];
              d_kj = dist[fw_k][fw_j];
              d_ij = dist[fw_i][fw_j];

              if (d_ik != INF && d_kj != INF) begin
                new_d = d_ik + d_kj;
                if (new_d < d_ij) begin
                  dist[fw_i][fw_j] <= new_d;
                end
              end

              // Advance j, i, k indices
              if (fw_j == (n_nodes - 1)) begin
                fw_j <= 2'd0;
                if (fw_i == (n_nodes - 1)) begin
                  fw_i <= 2'd0;
                  fw_k <= fw_k + 2'd1;
                end else begin
                  fw_i <= fw_i + 2'd1;
                end
              end else begin
                fw_j <= fw_j + 2'd1;
              end
            end else begin
              // Safety: if indices out of active range, reset them
              fw_i <= 2'd0;
              fw_j <= 2'd0;
              fw_k <= fw_k + 2'd1;
            end
          end
        end

        PROCESS_ORDERS: begin
          // Process orders in FIFO by ready time; assume inputs are pre-ordered by ready time
          if (order_idx < n_orders) begin
            spawn_t = order_spawn[order_idx];
            loc_t   = order_loc[order_idx];
            ready_t = order_ready[order_idx];

            // Travel time from current location to order location
            // If no path (INF), treat as zero additional (or clamp); here, clamp to INF and saturate
            d_ij = dist[cur_loc][loc_t];
            if (d_ij == INF)
              d_ij = 8'd0; // unreachable => no additional delay; can be adjusted per spec

            // delivery_time = max(cur_time, ready_t) + travel_time
            if (cur_time < ready_t)
              new_d = ready_t + d_ij;
            else
              new_d = cur_time + d_ij;

            // wait_time = delivery_time - spawn_t
            wait_time = new_d - spawn_t;

            // track maximum wait
            if (wait_time > max_wait)
              max_wait <= wait_time;

            // update courier state
            cur_time  <= new_d;
            cur_loc   <= loc_t;

            // next order
            order_idx <= order_idx + 2'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // Hold results until next start deasserted then asserted
        end

        default: begin
          // Should not occur; reset to IDLE-like safe state
          done      <= 1'b0;
          max_wait  <= 8'd0;
          cur_time  <= 8'd0;
          cur_loc   <= 2'd0;
          order_idx <= 2'd0;
          edge_idx  <= 3'd0;
          fw_k      <= 2'd0;
          fw_i      <= 2'd0;
          fw_j      <= 2'd0;
        end
      endcase
    end
  end

endmodule