module ginger_candy_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] n_nodes,
  input [3:0] n_roads,
  input [4:0] alpha,
  input [7:0] road_data_valid,
  input [2:0] u_in,
  input [2:0] v_in,
  input [15:0] c_in,
  output reg [31:0] min_energy,
  output reg no_route,
  output reg done
);

  typedef enum {
    IDLE,
    LOAD_DATA,
    FIND_CYCLES,
    CALC_ENERGY,
    DONE
  } fsm_state_t;

  // Road storage
  reg [2:0] u_mem [0:15];
  reg [2:0] v_mem [0:15];
  reg [15:0] c_mem [0:15];
  reg [3:0] road_count;
  
  // Max candy tracking
  reg [15:0] max_c;
  
  // Graph properties
  reg [3:0] degrees[0:7];
  reg [7:0] visited;
  
  // FSM state and control
  fsm_state_t state;
  reg [20:0] cycle_counter;
  reg [3:0] chk_idx;
  reg [2:0] current_node;
  reg [3:0] bfs_queue [0:7];
  reg [3:0] queue_front;
  reg [3:0] queue_back;
  reg [3:0] bfs_step;
  
  // Degree/cycle checks
  reg all_degrees_even;
  reg graph_connected;
  
  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      road_count <= 0;
      max_c <= 0;
      min_energy <= 0;
      no_route <= 0;
      done <= 0;
      cycle_counter <= 0;
    end else begin
      done <= 0; // Default done to 0 unless in DONE
      
      case (state)
        IDLE: begin
          if (|road_data_valid) begin // Start loading on valid
            state <= LOAD_DATA;
            road_count <= 0;
          end
        end
        
        LOAD_DATA: begin
          if (|road_data_valid && road_count < n_roads) begin
            u_mem[road_count] <= u_in;
            v_mem[road_count] <= v_in;
            c_mem[road_count] <= c_in;
            road_count <= road_count + 1;
            if (c_in > max_c) max_c <= c_in;
          end
          if (start) begin
            state <= FIND_CYCLES;
            cycle_counter <= 0;
          end
        end
        
        FIND_CYCLES: begin
          if (cycle_counter == 0) begin // Initialize checks
            // Reset degrees and visited
            for (int i=0; i<8; i=i+1) begin
              degrees[i] <= 0;
              visited[i] <= 0;
            end
            chk_idx <= 0;
            graph_connected <= 1;
            all_degrees_even <= 1;
            bfs_step <= 0;
          end else if (cycle_counter < n_roads + 1) begin
            // Calculate degrees
            if (chk_idx < n_roads) begin
              degrees[u_mem[chk_idx]] <= degrees[u_mem[chk_idx]] + 1;
              degrees[v_mem[chk_idx]] <= degrees[v_mem[chk_idx]] + 1;
              chk_idx <= chk_idx + 1;
            end
          end else if (cycle_counter == n_roads + 1) begin
            // Check degrees for even
            for (int i=0; i<8; i=i+1) begin
              if (degrees[i] && (degrees[i] % 2)) all_degrees_even <= 0;
            end
            // Initialize BFS
            current_node <= 0;
            visited <= 0;
            queue_front <= 0;
            queue_back <= 0;
            // Find starting node
            for (int i=0; i<8; i=i+1) begin
              if (degrees[i] && !visited[i]) begin
                visited[i] <= 1;
                current_node <= i;
                bfs_queue[0] <= i;
                queue_back <= 1;
                break;
              end
            end
          end else if (cycle_counter < n_roads + 20) begin
            // BFS traversal
            if (queue_front != queue_back) begin
              current_node <= bfs_queue[queue_front];
              queue_front <= queue_front + 1;
              // Find all adjacent nodes
              for (int i=0; i<n_roads; i=i+1) begin
                if (u_mem[i] == current_node && !visited[v_mem[i]]) begin
                  visited[v_mem[i]] <= 1;
                  bfs_queue[queue_back] <= v_mem[i];
                  queue_back <= queue_back + 1;
                end
                if (v_mem[i] == current_node && !visited[u_mem[i]]) begin
                  visited[u_mem[i]] <= 1;
                  bfs_queue[queue_back] <= u_mem[i];
                  queue_back <= queue_back + 1;
                end
              end
            end else begin
              // Check if all non-zero degree nodes visited
              for (int i=0; i<8; i=i+1) begin
                if (degrees[i] && !visited[i]) graph_connected <= 0;
              end
              state <= CALC_ENERGY;
            end
          end
          
          cycle_counter <= cycle_counter + 1;
          // Fixed latency guard
          if (cycle_counter == 1023) begin
            state <= DONE;
            no_route <= 1;
          end
        end
        
        CALC_ENERGY: begin
          if (graph_connected && all_degrees_even) begin
            min_energy <= (max_c * max_c) + (alpha * n_roads);
            no_route <= 0;
          end else begin
            min_energy <= 0;
            no_route <= 1;
          end
          state <= DONE;
        end
        
        DONE: begin
          done <= 1;
          if (start) begin // Reset on new start
            state <= LOAD_DATA;
            road_count <= 0;
            max_c <= 0;
          end
        end
      endcase
    end
  end

endmodule