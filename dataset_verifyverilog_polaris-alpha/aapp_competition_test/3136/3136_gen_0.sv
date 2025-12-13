module delivery_distance(
  input clk,
  input rst_n,
  input start,
  input [2:0] warehouse1,
  input [2:0] warehouse2,
  input [2:0] employees [0:7],
  input [2:0] clients [0:7],
  input [7:0] num_deliveries,
  input [7:0] adj_matrix [0:7][0:7],
  output reg [15:0] total_distance,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE          = 3'd0,
    COMPUTE_W1    = 3'd1,
    COMPUTE_W2    = 3'd2,
    MATCH_DELIVERIES = 3'd3,
    DONE          = 3'd4
  } state_t;

  state_t state, next_state;

  // Dijkstra-related storage (8 nodes)
  reg [7:0] dist_w1 [0:7];
  reg [7:0] dist_w2 [0:7];
  reg       visited [0:7];

  reg [2:0] src_node;          // current source node index
  reg [2:0] dijkstra_iter;     // outer iterations counter (0..7)
  reg [2:0] relax_node;        // node index used when relaxing edges

  reg [7:0] cur_min_dist;
  reg [2:0] cur_min_node;

  // Matching-related
  reg [7:0] delivery_idx;          // 0..7
  reg [2:0] best_emp_idx;
  reg [15:0] best_emp_cost;
  reg [2:0] emp_idx_iter;
  reg [15:0] candidate_cost;
  reg [7:0] used_employees;        // bitmask: 1 if employee used

  // Latched parameters
  reg [2:0] warehouse1_r;
  reg [2:0] warehouse2_r;
  reg [2:0] employees_r [0:7];
  reg [2:0] clients_r [0:7];
  reg [7:0] num_deliveries_r;

  // Helper wires for current delivery
  wire [2:0] cur_client_node = clients_r[delivery_idx[2:0]];

  // Next-state logic (simple flow)
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COMPUTE_W1;
      end
      COMPUTE_W1: begin
        if (dijkstra_iter == 3'd7 && relax_node == 3'd7)
          next_state = COMPUTE_W2;
      end
      COMPUTE_W2: begin
        if (dijkstra_iter == 3'd7 && relax_node == 3'd7)
          next_state = MATCH_DELIVERIES;
      end
      MATCH_DELIVERIES: begin
        if (delivery_idx >= num_deliveries_r)
          next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      total_distance <= 16'd0;
      done <= 1'b0;
      dijkstra_iter <= 3'd0;
      relax_node <= 3'd0;
      cur_min_dist <= 8'hff;
      cur_min_node <= 3'd0;
      src_node <= 3'd0;
      delivery_idx <= 8'd0;
      emp_idx_iter <= 3'd0;
      best_emp_idx <= 3'd0;
      best_emp_cost <= 16'hffff;
      used_employees <= 8'd0;
      warehouse1_r <= 3'd0;
      warehouse2_r <= 3'd0;
      num_deliveries_r <= 8'd0;
      for (i = 0; i < 8; i = i + 1) begin
        dist_w1[i] <= 8'hff;
        dist_w2[i] <= 8'hff;
        visited[i] <= 1'b0;
        employees_r[i] <= 3'd0;
        clients_r[i] <= 3'd0;
      end
    end else begin
      state <= next_state;
      done <= 1'b0; // default, asserted only in DONE

      case (state)
        IDLE: begin
          if (start) begin
            // Latch inputs
            warehouse1_r <= warehouse1;
            warehouse2_r <= warehouse2;
            num_deliveries_r <= (num_deliveries > 8) ? 8 : num_deliveries;

            for (i = 0; i < 8; i = i + 1) begin
              employees_r[i] <= employees[i];
              clients_r[i]   <= clients[i];
            end

            // Initialize for Dijkstra from W1
            src_node <= warehouse1;
            for (i = 0; i < 8; i = i + 1) begin
              visited[i] <= 1'b0;
              dist_w1[i] <= 8'hff;
            end
            dist_w1[warehouse1] <= 8'd0;
            dijkstra_iter <= 3'd0;
            relax_node <= 3'd0;
            cur_min_dist <= 8'hff;
            cur_min_node <= 3'd0;

            // Init other controls
            total_distance <= 16'd0;
            used_employees <= 8'd0;
            delivery_idx <= 8'd0;
            emp_idx_iter <= 3'd0;
            best_emp_idx <= 3'd0;
            best_emp_cost <= 16'hffff;
          end
        end

        // Dijkstra for warehouse1
        COMPUTE_W1: begin
          // Step 1: select unvisited node with smallest dist_w1
          if (relax_node == 3'd0) begin
            cur_min_dist <= 8'hff;
            cur_min_node <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
              if (!visited[i] && dist_w1[i] < cur_min_dist) begin
                cur_min_dist <= dist_w1[i];
                cur_min_node <= i[2:0];
              end
            end
            // Mark selected node visited
            visited[cur_min_node] <= 1'b1;
            relax_node <= 3'd0;
          end

          // Step 2: relax neighbors of cur_min_node sequentially across cycles
          if (!visited[relax_node] || relax_node == cur_min_node) begin
            // Use adjacency matrix: adj_matrix[cur_min_node][relax_node]
            if (adj_matrix[cur_min_node][relax_node] != 8'hff) begin
              if (cur_min_dist + adj_matrix[cur_min_node][relax_node] < dist_w1[relax_node]) begin
                dist_w1[relax_node] <= cur_min_dist + adj_matrix[cur_min_node][relax_node];
              end
            end
          end else begin
            // still step through all nodes to keep deterministic timing
          end

          // Advance relax_node
          if (relax_node == 3'd7) begin
            relax_node <= 3'd0;
            if (dijkstra_iter < 3'd7)
              dijkstra_iter <= dijkstra_iter + 3'd1;
          end else begin
            relax_node <= relax_node + 3'd1;
          end

          // When finishing final iteration, prepare for W2 in next_state
          if (next_state == COMPUTE_W2) begin
            // initialize for Dijkstra from W2
            src_node <= warehouse2_r;
            for (i = 0; i < 8; i = i + 1) begin
              visited[i] <= 1'b0;
              dist_w2[i] <= 8'hff;
            end
            dist_w2[warehouse2_r] <= 8'd0;
            dijkstra_iter <= 3'd0;
            relax_node <= 3'd0;
            cur_min_dist <= 8'hff;
            cur_min_node <= 3'd0;
          end
        end

        // Dijkstra for warehouse2
        COMPUTE_W2: begin
          // Step 1: select unvisited node with smallest dist_w2
          if (relax_node == 3'd0) begin
            cur_min_dist <= 8'hff;
            cur_min_node <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
              if (!visited[i] && dist_w2[i] < cur_min_dist) begin
                cur_min_dist <= dist_w2[i];
                cur_min_node <= i[2:0];
              end
            end
            visited[cur_min_node] <= 1'b1;
            relax_node <= 3'd0;
          end

          // Step 2: relax neighbors sequentially
          if (!visited[relax_node] || relax_node == cur_min_node) begin
            if (adj_matrix[cur_min_node][relax_node] != 8'hff) begin
              if (cur_min_dist + adj_matrix[cur_min_node][relax_node] < dist_w2[relax_node]) begin
                dist_w2[relax_node] <= cur_min_dist + adj_matrix[cur_min_node][relax_node];
              end
            end
          end

          if (relax_node == 3'd7) begin
            relax_node <= 3'd0;
            if (dijkstra_iter < 3'd7)
              dijkstra_iter <= dijkstra_iter + 3'd1;
          end else begin
            relax_node <= relax_node + 3'd1;
          end

          // Prepare for matching when transitioning
          if (next_state == MATCH_DELIVERIES) begin
            delivery_idx <= 8'd0;
            used_employees <= 8'd0;
            emp_idx_iter <= 3'd0;
            best_emp_idx <= 3'd0;
            best_emp_cost <= 16'hffff;
          end
        end

        // Greedy matching of deliveries to employees
        MATCH_DELIVERIES: begin
          if (delivery_idx < num_deliveries_r) begin
            // For each delivery, sweep employees to find minimal cost unused employee
            if (emp_idx_iter == 3'd0) begin
              best_emp_cost <= 16'hffff;
              best_emp_idx <= 3'd0;
            end

            if (!used_employees[emp_idx_iter]) begin
              // Compute cost for this employee
              // employee -> warehouse1 -> client
              // employee -> warehouse2 -> client
              // Use dist_w1/dist_w2 for warehouse->client, and dist_w1/dist_w2 from warehouses to employee node
              // For simplicity (and deterministic HW), we approximate:
              // cost_w1 = dist_w1[employee_node] + dist_w1[client_node]
              // cost_w2 = dist_w2[employee_node] + dist_w2[client_node]
              // and choose min(cost_w1, cost_w2)

              reg [2:0] emp_node;
              reg [7:0] d_we1_emp, d_we2_emp;
              reg [7:0] d_we1_cli, d_we2_cli;
              reg [15:0] cost_w1, cost_w2, local_min;

              emp_node = employees_r[emp_idx_iter];
              d_we1_emp = dist_w1[emp_node];
              d_we1_cli = dist_w1[cur_client_node];
              d_we2_emp = dist_w2[emp_node];
              d_we2_cli = dist_w2[cur_client_node];

              cost_w1 = d_we1_emp + d_we1_cli;
              cost_w2 = d_we2_emp + d_we2_cli;
              local_min = (cost_w1 < cost_w2) ? cost_w1 : cost_w2;

              candidate_cost = local_min;

              if (candidate_cost < best_emp_cost) begin
                best_emp_cost <= candidate_cost;
                best_emp_idx <= emp_idx_iter;
              end
            end

            // Advance employee iteration
            if (emp_idx_iter == 3'd7) begin
              // choose best employee for this delivery
              used_employees[best_emp_idx] <= 1'b1;
              total_distance <= total_distance + best_emp_cost;

              // next delivery
              delivery_idx <= delivery_idx + 8'd1;
              emp_idx_iter <= 3'd0;
            end else begin
              emp_idx_iter <= emp_idx_iter + 3'd1;
            end
          end
        end

        DONE: begin
          done <= 1'b1; // assert for one cycle
          // Prepare to go back to IDLE; rest will be reset/latched in IDLE on next start
        end

        default: begin
        end
      endcase
    end
  end

endmodule