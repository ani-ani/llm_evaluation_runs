module travel_frustration_minimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] target_n,
  input [31:0] flight_table [0:7][0:3], // [a,b,s,e]
  output reg [31:0] min_frustration,
  output reg done
);

  // State encoding
  localparam IDLE    = 2'b00;
  localparam LOAD    = 2'b01;
  localparam PROCESS = 2'b10;
  localparam FINISH  = 2'b11;

  reg [1:0] state, next_state;

  // Node indices: 1..5 (0 unused)
  // dist[node]: minimal accumulated frustration (T^2 sum)
  reg [31:0] dist [0:5];
  reg        visited [0:5];
  reg [31:0] last_arrival [0:5];

  // Iteration / control
  reg [3:0] iter_cnt;         // up to 15
  reg [3:0] flight_idx;       // 0..7
  reg [2:0] current_node;     // node being expanded
  reg       selecting_min;    // 1 while picking next current_node
  reg       relaxing_edges;   // 1 while processing all flights for current_node

  // Temporary for min selection
  reg [2:0]  min_node;
  reg [31:0] min_dist;

  // Combinational helpers
  integer i;

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD;
      end
      LOAD: begin
        next_state = PROCESS;
      end
      PROCESS: begin
        // Termination conditions:
        // - If no reachable unvisited node (min_node==0), or
        // - Target node is visited, or
        // - Iteration count exceeds bound
        if ( (visited[target_n]) || (min_node == 3'd0 && selecting_min == 1'b1) || (iter_cnt >= 4'd14) )
          next_state = FINISH;
        else
          next_state = PROCESS; // keep iterating until one condition to go FINISH
      end
      FINISH: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      min_frustration <= 32'hFFFFFFFF;
      iter_cnt <= 4'd0;
      flight_idx <= 4'd0;
      current_node <= 3'd0;
      selecting_min <= 1'b0;
      relaxing_edges <= 1'b0;
      for (i = 0; i <= 5; i = i + 1) begin
        dist[i] <= 32'hFFFFFFFF;
        visited[i] <= 1'b0;
        last_arrival[i] <= 32'hFFFFFFFF;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          min_frustration <= 32'hFFFFFFFF;
          iter_cnt <= 4'd0;
          flight_idx <= 4'd0;
          current_node <= 3'd0;
          selecting_min <= 1'b0;
          relaxing_edges <= 1'b0;
          if (start) begin
            // Reset arrays in LOAD via next state
          end
        end

        LOAD: begin
          // Initialize distances and visited flags
          for (i = 0; i <= 5; i = i + 1) begin
            dist[i] <= 32'hFFFFFFFF;
            visited[i] <= 1'b0;
            last_arrival[i] <= 32'hFFFFFFFF;
          end
          // Start node = 1
          dist[1] <= 32'd0;
          last_arrival[1] <= 32'd0; // initial arrival time at source assumed 0
          // Setup for PROCESS
          iter_cnt <= 4'd0;
          selecting_min <= 1'b1;
          relaxing_edges <= 1'b0;
          flight_idx <= 4'd0;
          current_node <= 3'd0;
          done <= 1'b0;
          min_frustration <= 32'hFFFFFFFF;
        end

        PROCESS: begin
          if (selecting_min) begin
            // Single-cycle selection of next unvisited node with minimal dist
            min_dist = 32'hFFFFFFFF;
            min_node = 3'd0;
            for (i = 1; i <= 5; i = i + 1) begin
              if (!visited[i] && dist[i] < min_dist) begin
                min_dist = dist[i];
                min_node = i[2:0];
              end
            end

            // If no node found, algorithm will move to FINISH via next_state
            current_node <= min_node;

            if (min_node != 3'd0) begin
              visited[min_node] <= 1'b1;
              // Prepare to relax edges from this node
              selecting_min <= 1'b0;
              relaxing_edges <= 1'b1;
              flight_idx <= 4'd0;
            end else begin
              // No more nodes, stay; next_state will send us to FINISH
              selecting_min <= 1'b1;
              relaxing_edges <= 1'b0;
            end
          end else if (relaxing_edges) begin
            // Process one flight per cycle
            if (flight_idx < 4'd8 && current_node != 3'd0) begin
              // Decode flight entry
              // layout: [a:3b, b:3b, s:7b, e:7b] within 32 bits
              // Assume: bits [31:29]=a, [28:26]=b, [25:19]=s, [18:12]=e (remaining bits ignored)
              // Adjusted for 32 bits: use this fixed mapping
              // Extract fields
              reg [2:0] f_a;
              reg [2:0] f_b;
              reg [6:0] f_s;
              reg [6:0] f_e;
              reg [31:0] wait_time;
              reg [31:0] cost_add;
              reg [31:0] new_dist;

              f_a = flight_table[flight_idx][0][31:29];
              f_b = flight_table[flight_idx][0][28:26];
              f_s = flight_table[flight_idx][0][25:19];
              f_e = flight_table[flight_idx][0][18:12];

              // If flight_table format instead is [a,b,s,e] separate words, use those:
              // Uncomment below and comment above four lines if needed.
              // f_a = flight_table[flight_idx][0][2:0];
              // f_b = flight_table[flight_idx][1][2:0];
              // f_s = flight_table[flight_idx][2][6:0];
              // f_e = flight_table[flight_idx][3][6:0];

              // Relax only if from current_node and time feasible
              if (f_a == current_node && dist[current_node] != 32'hFFFFFFFF) begin
                if (f_s >= last_arrival[current_node]) begin
                  wait_time = f_s - last_arrival[current_node];
                  cost_add = wait_time * wait_time;
                  new_dist = dist[current_node] + cost_add;
                  if (new_dist < dist[f_b]) begin
                    dist[f_b] <= new_dist;
                    last_arrival[f_b] <= f_e;
                  end
                end
              end

              flight_idx <= flight_idx + 4'd1;
            end else begin
              // Finished all flights for this node
              relaxing_edges <= 1'b0;
              selecting_min <= 1'b1;
              flight_idx <= 4'd0;
              iter_cnt <= iter_cnt + 4'd1;
            end
          end

          // Capture running best for target
          if (dist[target_n] < min_frustration)
            min_frustration <= dist[target_n];
        end

        FINISH: begin
          done <= 1'b1;
          // Finalize output: if unreachable, keep 0xFFFFFFFF
          if (dist[target_n] < min_frustration)
            min_frustration <= dist[target_n];
          // Wait for start deassert then new start to exit
        end

        default: begin
          // Safety fallback
          state <= IDLE;
        end
      endcase
    end
  end

endmodule