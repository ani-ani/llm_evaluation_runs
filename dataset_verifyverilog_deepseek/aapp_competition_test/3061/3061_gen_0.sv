module critical_path_analyzer(
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [3:0] edge_count,
  input [139:0] edge_list,
  output reg [3:0] result,
  output reg done
);

typedef enum {
  IDLE,
  COMPUTE_ORIGINAL,
  CHECK_EDGES,
  DONE
} state_t;

typedef enum {
  BUILD_ADJ,
  COMPUTE_IN_DEG,
  TOPOLOGY_INIT,
  TOPOLOGY_LOOP,
  DP_INIT,
  DP_LOOP,
  GET_MAX
} compute_state_t;

// Internal registers
state_t current_state, next_state;
compute_state_t compute_state, compute_next;
reg [2:0] node_count_reg;
reg [3:0] edge_count_reg;
reg [139:0] edge_list_reg;
reg [3:0] original_max_path;
reg [3:0] min_path;
reg [3:0] current_edge_index;
reg [7:0][7:0] adjacency;
reg [3:0] in_degree [0:7];
reg [2:0] topological_order [0:7];
reg [3:0] dp [0:7];
reg [7:0] processed;
reg [2:0] topology_index;
reg [2:0] node_ptr;
reg [3:0] current_max_path;
reg [3:0] edge_loop_counter;
reg [2:0] node_loop_counter;
reg [2:0] dp_index;
reg [3:0] temp_max;
reg [3:0] in_degree_copy [0:7];

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    done <= 0;
    result <= 0;
    compute_state <= BUILD_ADJ;
    for (int i=0; i<8; i++) begin
      in_degree[i] <= 0;
      dp[i] <= 0;
    end
    adjacency <= {64{1'b0}};
    processed <= 8'h00;
    topology_index <= 0;
    node_ptr <= 0;
  end else begin
    current_state <= next_state;
    compute_state <= compute_next;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state <= COMPUTE_ORIGINAL;
          node_count_reg <= node_count;
          edge_count_reg <= edge_count;
          edge_list_reg <= edge_list;
          done <= 0;
          compute_next <= BUILD_ADJ;
        end
      end

      COMPUTE_ORIGINAL: begin
        case (compute_state)
          BUILD_ADJ: begin
            adjacency <= {64{1'b0}};
            edge_loop_counter <= 0;
            compute_next <= BUILD_ADJ;
            if (edge_loop_counter < edge_count_reg) begin
              automatic logic [2:0] u = edge_list_reg[6*edge_loop_counter +:3];
              automatic logic [2:0] v = edge_list_reg[6*edge_loop_counter+3 +:3];
              if (u < node_count_reg && v < node_count_reg) begin
                adjacency[u][v] <= 1'b1;
              end
              edge_loop_counter <= edge_loop_counter + 1;
            end else begin
              compute_next <= COMPUTE_IN_DEG;
            end
          end

          COMPUTE_IN_DEG: begin
            for (int i=0; i<8; i++) begin
              in_degree[i] <= 0;
              for (int j=0; j<8; j++) begin
                if (adjacency[j][i]) in_degree[i] <= in_degree[i] + 1;
              end
            end
            compute_next <= TOPOLOGY_INIT;
          end

          TOPOLOGY_INIT: begin
            processed <= 8'h00;
            topology_index <= 0;
            node_ptr <= 0;
            for (int i=0; i<8; i++) in_degree_copy[i] <= in_degree[i];
            compute_next <= TOPOLOGY_LOOP;
          end

          TOPOLOGY_LOOP: begin
            if (topology_index < node_count_reg) begin
              if (!processed[node_ptr] && (in_degree_copy[node_ptr] == 0) && (node_ptr < node_count_reg)) begin
                topological_order[topology_index] <= node_ptr;
                processed <= processed | (1 << node_ptr);
                for (int k=0; k<8; k++) begin
                  if (adjacency[node_ptr][k] && !processed[k]) begin
                    in_degree_copy[k] <= in_degree_copy[k] - 1;
                  end
                end
                topology_index <= topology_index + 1;
                node_ptr <= 3'b0;
              end else begin
                node_ptr <= (node_ptr == 7) ? 0 : node_ptr + 1;
              end
            end else begin
              compute_next <= DP_INIT;
            end
          end

          DP_INIT: begin
            dp <= '{default:0};
            dp_index <= 0;
            compute_next <= DP_LOOP;
          end

          DP_LOOP: begin
            if (dp_index < node_count_reg) begin
              automatic logic [2:0] idx = topological_order[dp_index];
              automatic logic [3:0] max_val = 0;
              for (int i=0; i<8; i++) begin
                if (i < node_count_reg && adjacency[i][idx] && (dp[i] + 1) > max_val) begin
                  max_val = dp[i] + 1;
                end
              end
              dp[idx] <= max_val;
              dp_index <= dp_index + 1;
            end else begin
              compute_next <= GET_MAX;
            end
          end

          GET_MAX: begin
            current_max_path <= 0;
            for (int i=0; i<8; i++) begin
              if (dp[i] > current_max_path) current_max_path <= dp[i];
            end
            next_state <= CHECK_EDGES;
            current_edge_index <= 0;
            compute_next <= BUILD_ADJ;
          end
        endcase
      end

      CHECK_EDGES: begin
        if (current_edge_index < edge_count_reg) begin
          case (compute_state)
            BUILD_ADJ: begin
              adjacency <= {64{1'b0}};
              edge_loop_counter <= 0;
              compute_next <= BUILD_ADJ;
              if (edge_loop_counter < edge_count_reg) begin
                if (edge_loop_counter != current_edge_index) begin
                  automatic logic [2:0] u = edge_list_reg[6*edge_loop_counter +:3];
                  automatic logic [2:0] v = edge_list_reg[6*edge_loop_counter+3 +:3];
                  if (u < node_count_reg && v < node_count_reg) begin
                    adjacency[u][v] <= 1'b1;
                  end
                end
                edge_loop_counter <= edge_loop_counter + 1;
              end else begin
                compute_next <= COMPUTE_IN_DEG;
              end
            end

            COMPUTE_IN_DEG: begin
              for (int i=0; i<8; i++) begin
                in_degree[i] <= 0;
                for (int j=0; j<8; j++) begin
                  if (adjacency[j][i]) in_degree[i] <= in_degree[i] + 1;
                end
              end
              compute_next <= TOPOLOGY_INIT;
            end

            TOPOLOGY_INIT: begin
              processed <= 8'h00;
              topology_index <= 0;
              node_ptr <= 0;
              for (int i=0; i<8; i++) in_degree_copy[i] <= in_degree[i];
              compute_next <= TOPOLOGY_LOOP;
            end

            TOPOLOGY_LOOP: begin
              if (topology_index < node_count_reg) begin
                if (!processed[node_ptr] && (in_degree_copy[node_ptr] == 0) && (node_ptr < node_count_reg)) begin
                  topological_order[topology_index] <= node_ptr;
                  processed <= processed | (1 << node_ptr);
                  for (int k=0; k<8; k++) begin
                    if (adjacency[node_ptr][k] && !processed[k]) begin
                      in_degree_copy[k] <= in_degree_copy[k] - 1;
                    end
                  end
                  topology_index <= topology_index + 1;
                  node_ptr <= 3'b0;
                end else begin
                  node_ptr <= (node_ptr == 7) ? 0 : node_ptr + 1;
                end
              end else begin
                compute_next <= DP_INIT;
              end
            end

            DP_INIT: begin
              dp <= '{default:0};
              dp_index <= 0;
              compute_next <= DP_LOOP;
            end

            DP_LOOP: begin
              if (dp_index < node_count_reg) begin
                automatic logic [2:0] idx = topological_order[dp_index];
                automatic logic [3:0] max_val = 0;
                for (int i=0; i<8; i++) begin
                  if (i < node_count_reg && adjacency[i][idx] && (dp[i] + 1) > max_val) begin
                    max_val = dp[i] + 1;
                  end
                end
                dp[idx] <= max_val;
                dp_index <= dp_index + 1;
              end else begin
                compute_next <= GET_MAX;
              end
            end

            GET_MAX: begin
              current_max_path <= 0;
              for (int i=0; i<8; i++) begin
                if (dp[i] > current_max_path) current_max_path <= dp[i];
              end
              if (current_max_path < min_path) begin
                min_path <= current_max_path;
              end
              current_edge_index <= current_edge_index + 1;
              compute_next <= BUILD_ADJ;
            end
          endcase
        end else begin
          next_state <= DONE;
        end
      end

      DONE: begin
        done <= 1'b1;
        result <= min_path;
        if (!start) begin
          next_state <= IDLE;
          done <= 1'b0;
        end
      end
    endcase
  end
end

initial begin
  // Initialize all registers
  current_state = IDLE;
  next_state = IDLE;
  compute_state = BUILD_ADJ;
  compute_next = BUILD_ADJ;
end

endmodule