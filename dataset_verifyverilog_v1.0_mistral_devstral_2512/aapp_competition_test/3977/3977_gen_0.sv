module government_graph (
  input clk, rst_n, start,
  input [3:0] n,
  input [1:0] k,
  input [2:0] gov0, gov1, gov2,
  input [4:0] m,
  input [95:0] edges,
  output reg [15:0] result,
  output reg done
);
  
  // State definitions
  localparam [3:0] IDLE = 4'd0;
  localparam [3:0] INIT = 4'd1;
  localparam [3:0] BUILD_ADJ = 4'd2;
  localparam [3:0] PROCESS_GOV_START = 4'd3;
  localparam [3:0] BFS_LOOP = 4'd4;
  localparam [3:0] BFS_CHECK_NEIGH = 4'd5;
  localparam [3:0] CALCULATE_NON_GOV = 4'd6;
  localparam [3:0] CALCULATE_GOV_EDGES = 4'd7;
  localparam [3:0] CALCULATE_RESULT = 4'd8;
  localparam [3:0] DONE_STATE = 4'd9;
  
  reg [3:0] state;
  reg [7:0] adj [0:7];
  reg [7:0] visited;
  reg [3:0] gov_component_sizes [0:2];
  reg [3:0] total_gov_nodes;
  reg [1:0] index;
  reg [2:0] queue [0:7];
  reg [2:0] head, tail;
  reg [3:0] size;
  reg [2:0] current_u;
  reg [2:0] v_counter;
  reg [4:0] i_edge;
  reg [3:0] non_gov_count;
  reg [3:0] max_gov;
  reg [15:0] total_edges;
  reg [1:0] i_calc;
  reg [7:0] temp1, temp2;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 16'd0;
      visited <= 8'd0;
      adj[0] <= 8'd0; adj[1] <= 8'd0; adj[2] <= 8'd0; adj[3] <= 8'd0;
      adj[4] <= 8'd0; adj[5] <= 8'd0; adj[6] <= 8'd0; adj[7] <= 8'd0;
      gov_component_sizes[0] <= 4'd0; gov_component_sizes[1] <= 4'd0; gov_component_sizes[2] <= 4'd0;
      total_gov_nodes <= 4'd0;
      index <= 2'd0;
      head <= 3'd0; tail <= 3'd0; size <= 4'd0; v_counter <= 3'd0;
      i_edge <= 5'd0;
      non_gov_count <= 4'd0; max_gov <= 4'd0; total_edges <= 16'd0; i_calc <= 2'd0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) state <= INIT;
        end
        INIT: begin
          visited <= 8'd0;
          adj[0] <= 8'd0; adj[1] <= 8'd0; adj[2] <= 8'd0; adj[3] <= 8'd0;
          adj[4] <= 8'd0; adj[5] <= 8'd0; adj[6] <= 8'd0; adj[7] <= 8'd0;
          gov_component_sizes[0] <= 4'd0; gov_component_sizes[1] <= 4'd0; gov_component_sizes[2] <= 4'd0;
          total_gov_nodes <= 4'd0;
          index <= 2'd0;
          i_edge <= 5'd0;
          state <= BUILD_ADJ;
        end
        BUILD_ADJ: begin
          if (i_edge < m) begin
            if (edges[6*i_edge +: 3] < n && edges[6*i_edge + 3 +: 3] < n && edges[6*i_edge +: 3] != edges[6*i_edge + 3 +: 3]) begin
              adj[edges[6*i_edge +: 3]][edges[6*i_edge + 3 +: 3]] <= 1'b1;
              adj[edges[6*i_edge + 3 +: 3]][edges[6*i_edge +: 3]] <= 1'b1;
            end
            i_edge <= i_edge + 5'd1;
          end
          else state <= PROCESS_GOV_START;
        end
        PROCESS_GOV_START: begin
          if (index < k) begin
            case (index)
              2'd0: current_u <= gov0;
              2'd1: current_u <= gov1;
              2'd2: current_u <= gov2;
            endcase
            if (visited[current_u] == 1'b0) begin
              queue[0] <= current_u;
              head <= 3'd0;
              tail <= 3'd1;
              visited[current_u] <= 1'b1;
              size <= 4'd0;
              state <= BFS_LOOP;
            end
            else begin
              gov_component_sizes[index] <= 4'd0;
              index <= index + 2'd1;
              state <= PROCESS_GOV_START;
            end
          end
          else state <= CALCULATE_NON_GOV;
        end
        BFS_LOOP: begin
          if (head < tail) begin
            current_u <= queue[head];
            head <= head + 3'd1;
            size <= size + 4'd1;
            v_counter <= 3'd0;
            state <= BFS_CHECK_NEIGH;
          end
          else begin
            gov_component_sizes[index] <= size;
            total_gov_nodes <= total_gov_nodes + size;
            index <= index + 2'd1;
            state <= PROCESS_GOV_START;
          end
        end
        BFS_CHECK_NEIGH: begin
          if (v_counter < n) begin
            if (adj[current_u][v_counter] && !visited[v_counter]) begin
              visited[v_counter] <= 1'b1;
              queue[tail] <= v_counter;
              tail <= tail + 3'd1;
            end
            v_counter <= v_counter + 3'd1;
          end
          else state <= BFS_LOOP;
        end
        CALCULATE_NON_GOV: begin
          non_gov_count <= n - total_gov_nodes;
          max_gov <= gov_component_sizes[0];
          if (k > 1'b0 && gov_component_sizes[1] > max_gov) max_gov <= gov_component_sizes[1];
          if (k > 2'b0 && gov_component_sizes[2] > max_gov) max_gov <= gov_component_sizes[2];
          total_edges <= 16'd0;
          i_calc <= 2'd0;
          state <= CALCULATE_GOV_EDGES;
        end
        CALCULATE_GOV_EDGES: begin
          if (i_calc < k) begin
            if (gov_component_sizes[i_calc] != max_gov) begin
              temp1 = gov_component_sizes[i_calc] * (gov_component_sizes[i_calc] - 4'd1);
              total_edges <= total_edges + (temp1 >> 1);
            end
            i_calc <= i_calc + 2'd1;
          end
          else begin
            temp2 = (non_gov_count + max_gov) * (non_gov_count + max_gov - 4'd1);
            total_edges <= total_edges + (temp2 >> 1);
            state <= CALCULATE_RESULT;
          end
        end
        CALCULATE_RESULT: begin
          result <= total_edges - m;
          state <= DONE_STATE;
        end
        DONE_STATE: begin
          done <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule