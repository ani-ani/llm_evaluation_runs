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
  reg [7:0] adj0, adj1, adj2, adj3, adj4, adj5, adj6, adj7;
  reg [7:0] visited;
  reg [3:0] gov_component_sizes0, gov_component_sizes1, gov_component_sizes2;
  reg [3:0] total_gov_nodes;
  reg [1:0] index;
  reg [2:0] queue0, queue1, queue2, queue3, queue4, queue5, queue6, queue7;
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
  reg [2:0] gov_node;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      visited <= 0;
      adj0 <= 0; adj1 <= 0; adj2 <= 0; adj3 <= 0;
      adj4 <= 0; adj5 <= 0; adj6 <= 0; adj7 <= 0;
      gov_component_sizes0 <= 0; gov_component_sizes1 <= 0; gov_component_sizes2 <= 0;
      total_gov_nodes <= 0;
      index <= 0;
      head <= 0; tail <= 0; size <= 0; v_counter <= 0;
      i_edge <= 0;
      non_gov_count <= 0; max_gov <= 0; total_edges <= 0; i_calc <= 0;
      current_u <= 0;
      gov_node <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) state <= INIT;
        end
        INIT: begin
          visited <= 0;
          adj0 <= 0; adj1 <= 0; adj2 <= 0; adj3 <= 0;
          adj4 <= 0; adj5 <= 0; adj6 <= 0; adj7 <= 0;
          gov_component_sizes0 <= 0; gov_component_sizes1 <= 0; gov_component_sizes2 <= 0;
          total_gov_nodes <= 0;
          index <= 0;
          i_edge <= 0;
          state <= BUILD_ADJ;
        end
        BUILD_ADJ: begin
          if (i_edge < m) begin
            if (edges[6*i_edge +: 3] < n && edges[6*i_edge + 3 +: 3] < n && edges[6*i_edge +: 3] != edges[6*i_edge + 3 +: 3]) begin
              case (edges[6*i_edge +: 3])
                3'd0: adj0[edges[6*i_edge + 3 +: 3]] <= 1;
                3'd1: adj1[edges[6*i_edge + 3 +: 3]] <= 1;
                3'd2: adj2[edges[6*i_edge + 3 +: 3]] <= 1;
                3'd3: adj3[edges[6*i_edge + 3 +: 3]] <= 1;
                3'd4: adj4[edges[6*i_edge + 3 +: 3]] <= 1;
                3'd5: adj5[edges[6*i_edge + 3 +: 3]] <= 1;
                3'd6: adj6[edges[6*i_edge + 3 +: 3]] <= 1;
                3'd7: adj7[edges[6*i_edge + 3 +: 3]] <= 1;
              endcase
              case (edges[6*i_edge + 3 +: 3])
                3'd0: adj0[edges[6*i_edge +: 3]] <= 1;
                3'd1: adj1[edges[6*i_edge +: 3]] <= 1;
                3'd2: adj2[edges[6*i_edge +: 3]] <= 1;
                3'd3: adj3[edges[6*i_edge +: 3]] <= 1;
                3'd4: adj4[edges[6*i_edge +: 3]] <= 1;
                3'd5: adj5[edges[6*i_edge +: 3]] <= 1;
                3'd6: adj6[edges[6*i_edge +: 3]] <= 1;
                3'd7: adj7[edges[6*i_edge +: 3]] <= 1;
              endcase
            end
            i_edge <= i_edge + 5'd1;
          end
          else state <= PROCESS_GOV_START;
        end
        PROCESS_GOV_START: begin
          if (index < k) begin
            case (index)
              2'd0: gov_node <= gov0;
              2'd1: gov_node <= gov1;
              2'd2: gov_node <= gov2;
            endcase
            if (visited[gov_node] == 0) begin
              queue0 <= gov_node;
              head <= 0;
              tail <= 1;
              visited[gov_node] <= 1;
              size <= 0;
              state <= BFS_LOOP;
            end
            else begin
              if (index == 2'd0) gov_component_sizes0 <= 0;
              if (index == 2'd1) gov_component_sizes1 <= 0;
              if (index == 2'd2) gov_component_sizes2 <= 0;
              index <= index + 2'd1;
              state <= PROCESS_GOV_START;
            end
          end
          else state <= CALCULATE_NON_GOV;
        end
        BFS_LOOP: begin
          if (head < tail) begin
            case (head)
              3'd0: current_u <= queue0;
              3'd1: current_u <= queue1;
              3'd2: current_u <= queue2;
              3'd3: current_u <= queue3;
              3'd4: current_u <= queue4;
              3'd5: current_u <= queue5;
              3'd6: current_u <= queue6;
              3'd7: current_u <= queue7;
            endcase
            head <= head + 3'd1;
            size <= size + 3'd1;
            v_counter <= 0;
            state <= BFS_CHECK_NEIGH;
          end
          else begin
            if (index == 2'd0) gov_component_sizes0 <= size;
            if (index == 2'd1) gov_component_sizes1 <= size;
            if (index == 2'd2) gov_component_sizes2 <= size;
            total_gov_nodes <= total_gov_nodes + size;
            index <= index + 2'd1;
            state <= PROCESS_GOV_START;
          end
        end
        BFS_CHECK_NEIGH: begin
          if (v_counter < n) begin
            case (current_u)
              3'd0: temp1 <= adj0[v_counter +: 1];
              3'd1: temp1 <= adj1[v_counter +: 1];
              3'd2: temp1 <= adj2[v_counter +: 1];
              3'd3: temp1 <= adj3[v_counter +: 1];
              3'd4: temp1 <= adj4[v_counter +: 1];
              3'd5: temp1 <= adj5[v_counter +: 1];
              3'd6: temp1 <= adj6[v_counter +: 1];
              3'd7: temp1 <= adj7[v_counter +: 1];
            endcase
            if (temp1 && !visited[v_counter]) begin
              visited[v_counter] <= 1;
              case (tail)
                3'd0: queue0 <= v_counter;
                3'd1: queue1 <= v_counter;
                3'd2: queue2 <= v_counter;
                3'd3: queue3 <= v_counter;
                3'd4: queue4 <= v_counter;
                3'd5: queue5 <= v_counter;
                3'd6: queue6 <= v_counter;
                3'd7: queue7 <= v_counter;
              endcase
              tail <= tail + 3'd1;
            end
            v_counter <= v_counter + 3'd1;
          end
          else state <= BFS_LOOP;
        end
        CALCULATE_NON_GOV: begin
          non_gov_count <= n - total_gov_nodes;
          max_gov <= gov_component_sizes0;
          if (k > 2'd1 && gov_component_sizes1 > max_gov) max_gov <= gov_component_sizes1;
          if (k > 2'd2 && gov_component_sizes2 > max_gov) max_gov <= gov_component_sizes2;
          total_edges <= 0;
          i_calc <= 0;
          state <= CALCULATE_GOV_EDGES;
        end
        CALCULATE_GOV_EDGES: begin
          if (i_calc < k) begin
            case (i_calc)
              2'd0: temp1 <= gov_component_sizes0;
              2'd1: temp1 <= gov_component_sizes1;
              2'd2: temp1 <= gov_component_sizes2;
            endcase
            if (temp1 != max_gov) begin
              temp2 <= temp1 * (temp1 - 8'd1);
              total_edges <= total_edges + (temp2 >> 1);
            end
            i_calc <= i_calc + 2'd1;
          end
          else begin
            temp2 <= (non_gov_count + max_gov) * (non_gov_count + max_gov - 8'd1);
            total_edges <= total_edges + (temp2 >> 1);
            state <= CALCULATE_RESULT;
          end
        end
        CALCULATE_RESULT: begin
          result <= total_edges - m;
          state <= DONE_STATE;
        end
        DONE_STATE: begin
          done <= 1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule