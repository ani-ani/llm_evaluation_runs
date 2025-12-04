module pizza_delivery_optimizer (
  input clk,
  input rst_n,
  input start,
  input [1:0] node_count,
  input [2:0] edge_count,
  input [3:0][1:0] edge_src,
  input [3:0][1:0] edge_dest,
  input [3:0][7:0] edge_weight,
  input [1:0] order_count,
  input [2:0][7:0] order_spawn,
  input [2:0][1:0] order_loc,
  input [2:0][7:0] order_ready,
  output reg [7:0] max_wait,
  output reg done
);

  // Distance matrix for 4 nodes (indices 0..3). pizzeria is node 0.
  reg [7:0] dist [0:3][0:3];
  reg [7:0] dist_next [0:3][0:3];

  // FSM states
  localparam ST_IDLE = 3'b000;
  localparam ST_LOAD_DATA = 3'b001;
  localparam ST_COMPUTE_GRAPH = 3'b010;
  localparam ST_PROCESS_ORDERS = 3'b011;
  localparam ST_DONE = 3'b100;

  reg [2:0] state, state_next;
  reg [7:0] cycle_cnt, cycle_cnt_next;
  reg [3:0] i, j, k, i_next, j_next, k_next;
  reg [3:0] e_idx, e_idx_next;
  reg [2:0] o_idx, o_idx_next;
  reg [1:0] orders_valid, orders_valid_next;
  reg [7:0] cur_time, cur_time_next;
  reg [1:0] cur_loc, cur_loc_next;
  reg [7:0] max_wait_next;
  reg done_next;

  // Order queue (max 3). Will be sorted by ready time to enforce FIFO by ready times.
  reg [7:0] o_spawn [0:2];
  reg [1:0] o_loc [0:2];
  reg [7:0] o_ready [0:2];

  // Temporary registers for computed travel/delivery
  reg [7:0] travel, travel_next;
  reg [7:0] delivery, delivery_next;

  // Combinational next-state logic
  always @(*) begin
    // defaults
    state_next = state;
    cycle_cnt_next = cycle_cnt;
    i_next = i;
    j_next = j;
    k_next = k;
    e_idx_next = e_idx;
    o_idx_next = o_idx;
    orders_valid_next = orders_valid;
    cur_time_next = cur_time;
    cur_loc_next = cur_loc;
    max_wait_next = max_wait;
    done_next = 1'b0;
    travel_next = travel;
    delivery_next = delivery;

    case (state)
      ST_IDLE: begin
        // Stay in IDLE until start is asserted
        if (start) begin
          state_next = ST_LOAD_DATA;
          cycle_cnt_next = 8'd0;
          e_idx_next = 4'd0;
          // Initialize matrix on entry to LOAD_DATA
        end
      end

      ST_LOAD_DATA: begin
        // Initialize distance matrix in the first cycle of this state
        if (cycle_cnt == 8'd0) begin
          for (i_next = 4'd0; i_next < 4'd4; i_next = i_next + 1) begin
            for (j_next = 4'd0; j_next < 4'd4; j_next = j_next + 1) begin
              dist[i_next][j_next] = (i_next == j_next) ? 8'd0 : 8'd255; // 255 as "infinite" placeholder
              dist_next[i_next][j_next] = (i_next == j_next) ? 8'd0 : 8'd255;
            end
          end
        end

        // Load edges provided by the user
        if (e_idx < edge_count) begin
          if ((edge_src[e_idx] < 4) && (edge_dest[e_idx] < 4)) begin
            dist[edge_src[e_idx]][edge_dest[e_idx]] = edge_weight[e_idx];
          end
          e_idx_next = e_idx + 1;
          cycle_cnt_next = cycle_cnt + 1;
          state_next = ST_LOAD_DATA;
        end else begin
          // Edges loaded, proceed to Floyd-Warshall
          state_next = ST_COMPUTE_GRAPH;
          cycle_cnt_next = cycle_cnt + 1; // this transition consumes a cycle
          i_next = 4'd0;
          j_next = 4'd0;
          k_next = 4'd0;
        end
      end

      ST_COMPUTE_GRAPH: begin
        // Floyd-Warshall on 4x4 matrix: (k-outer, i-middle, j-inner)
        // Each j update is a separate cycle.
        if (k < 4) begin
          if (i < 4) begin
            if (j < 4) begin
              // Compute candidate = dist[i][k] + dist[k][j] with saturation at 255
              // If either operand is 255, treat as INF -> candidate=255
              if ((dist[i][k] == 8'd255) || (dist[k][j] == 8'd255)) begin
                dist_next[i][j] = 8'd255;
              end else begin
                dist_next[i][j] = dist[i][k] + dist[k][j];
                if (dist_next[i][j] > 8'd255) dist_next[i][j] = 8'd255;
              end
              // Choose min(dist[i][j], candidate)
              if (dist_next[i][j] > dist[i][j]) begin
                dist_next[i][j] = dist[i][j];
              end
              // Advance
              j_next = j + 1;
              cycle_cnt_next = cycle_cnt + 1;
            end else begin
              // Finished j-loop for this i,k; commit row and move to next i
              for (j_next = 4'd0; j_next < 4'd4; j_next = j_next + 1) begin
                dist[i][j_next] = dist_next[i][j_next];
              end
              i_next = i + 1;
              j_next = 4'd0;
              cycle_cnt_next = cycle_cnt + 1;
            end
          end else begin
            // Finished i-loop for this k; commit all rows and move to next k
            for (i_next = 4'd0; i_next < 4'd4; i_next = i_next + 1) begin
              for (j_next = 4'd0; j_next < 4'd4; j_next = j_next + 1) begin
                dist[i_next][j_next] = dist_next[i_next][j_next];
              end
            end
            k_next = k + 1;
            i_next = 4'd0;
            j_next = 4'd0;
            cycle_cnt_next = cycle_cnt + 1;
          end
        end else begin
          // FW done, move to processing orders
          state_next = ST_PROCESS_ORDERS;
          cycle_cnt_next = cycle_cnt + 1;
          // Prepare order queue and cursors
          orders_valid_next = order_count;
          // Initialize order arrays; compute FIFO via ready time sorting
          // Simple 3-entry bubble sort by o_ready (ascending)
          // Load raw values first
          o_spawn[0] = order_spawn[0];
          o_loc[0]   = order_loc[0];
          o_ready[0] = order_ready[0];
          o_spawn[1] = (orders_valid > 1) ? order_spawn[1] : 8'd0;
          o_loc[1]   = (orders_valid > 1) ? order_loc[1]   : 2'd0;
          o_ready[1] = (orders_valid > 1) ? order_ready[1] : 8'd0;
          o_spawn[2] = (orders_valid > 2) ? order_spawn[2] : 8'd0;
          o_loc[2]   = (orders_valid > 2) ? order_loc[2]   : 2'd0;
          o_ready[2] = (orders_valid > 2) ? order_ready[2] : 8'd0;

          // Sort only the valid entries by o_ready ascending
          // We know orders_valid is 1..3, but we can just sort up to 2nd index
          // Pass 1
          if (orders_valid > 1) begin
            if (o_ready[0] > o_ready[1]) begin
              // swap 0 and 1
              travel = o_spawn[0]; o_spawn[0] = o_spawn[1]; o_spawn[1] = travel;
              travel = o_loc[0];   o_loc[0]   = o_loc[1];   o_loc[1]   = travel;
              travel = o_ready[0]; o_ready[0] = o_ready[1]; o_ready[1] = travel;
            end
          end
          // Pass 2
          if (orders_valid > 2) begin
            if (o_ready[1] > o_ready[2]) begin
              // swap 1 and 2
              travel = o_spawn[1]; o_spawn[1] = o_spawn[2]; o_spawn[2] = travel;
              travel = o_loc[1];   o_loc[1]   = o_loc[2];   o_loc[2]   = travel;
              travel = o_ready[1]; o_ready[1] = o_ready[2]; o_ready[2] = travel;
            end
            // One more pass for safety if the first swap changed order
            if (o_ready[0] > o_ready[1]) begin
              travel = o_spawn[0]; o_spawn[0] = o_spawn[1]; o_spawn[1] = travel;
              travel = o_loc[0];   o_loc[0]   = o_loc[1];   o_loc[1]   = travel;
              travel = o_ready[0]; o_ready[0] = o_ready[1]; o_ready[1] = travel;
            end
          end

          o_idx_next = 3'd0;
          cur_loc_next = 2'd0; // start at pizzeria (node 0)
          cur_time_next = 8'd0;
          max_wait_next = 8'd0;
        end
      end

      ST_PROCESS_ORDERS: begin
        if (o_idx < orders_valid) begin
          // Compute travel time from current location to this order's location
          if (dist[cur_loc][o_loc[o_idx]] == 8'd255) begin
            travel_next = 8'd255; // unreachable -> saturate
          end else begin
            travel_next = dist[cur_loc][o_loc[o_idx]];
          end
          // Delivery time = max(cur_time, ready_i) + travel
          if (cur_time > o_ready[o_idx]) begin
            delivery_next = cur_time + travel_next;
          end else begin
            delivery_next = o_ready[o_idx] + travel_next;
          end
          if (delivery_next > 8'd255) delivery_next = 8'd255; // saturate

          // Wait time = delivery_time - spawn_i
          if (delivery_next >= o_spawn[o_idx]) begin
            max_wait_next = (delivery_next - o_spawn[o_idx] > max_wait) ? (delivery_next - o_spawn[o_idx]) : max_wait;
          end

          // Update current state
          cur_time_next = delivery_next;
          cur_loc_next = o_loc[o_idx];
          o_idx_next = o_idx + 1;
          cycle_cnt_next = cycle_cnt + 1;
          state_next = ST_PROCESS_ORDERS;
        end else begin
          // All orders processed
          state_next = ST_DONE;
          cycle_cnt_next = cycle_cnt + 1;
          done_next = 1'b1;
        end
      end

      ST_DONE: begin
        // Hold done=1 and final max_wait until rst or a new start
        done_next = 1'b1;
        // Stay in DONE until start is deasserted (return to IDLE) or rst_n resets
        if (!start) begin
          state_next = ST_IDLE;
          done_next = 1'b0;
        end
        cycle_cnt_next = cycle_cnt;
      end

      default: state_next = ST_IDLE;
    endcase
  end

  // Sequential logic with async reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      done <= 1'b0;
      cycle_cnt <= 8'd0;
      i <= 4'd0; j <= 4'd0; k <= 4'd0;
      e_idx <= 4'd0;
      o_idx <= 3'd0;
      orders_valid <= 2'd0;
      cur_time <= 8'd0;
      cur_loc <= 2'd0;
      max_wait <= 8'd0;
      travel <= 8'd0;
      delivery <= 8'd0;
    end else begin
      // commit combinatorial next values
      state <= state_next;
      done <= done_next;
      cycle_cnt <= cycle_cnt_next;
      i <= i_next; j <= j_next; k <= k_next;
      e_idx <= e_idx_next;
      o_idx <= o_idx_next;
      orders_valid <= orders_valid_next;
      cur_time <= cur_time_next;
      cur_loc <= cur_loc_next;
      max_wait <= max_wait_next;
      travel <= travel_next;
      delivery <= delivery_next;
    end
  end

endmodule
