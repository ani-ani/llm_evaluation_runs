module escape_network(
  input clk, rst_n, start,
  input [2:0] n, h,
  input [41:0] edges,
  output reg [2:0] m,
  output reg [41:0] added_edges,
  output reg done
);

typedef enum logic [2:0] {IDLE = 0, PARSE_EDGES = 1, DFS_TRAVERSE = 2, CALCULATE = 3, DONE_ST = 4} state_t;

reg [2:0] state, next_state;
reg [2:0] adj_list [0:7][0:6];
reg [2:0] deg[0:7];
reg [5:0] stack[0:7];
reg [3:0] sp;
reg visited[0:7];
reg [2:0] leaves[0:7];
reg [2:0] leaf_count;
reg [2:0] parse_k;
reg [2:0] m_reg;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    m <= 0;
    added_edges <= 42'b0;
    done <= 0;
    for (int i=0; i<8; i=i+1) begin
      deg[i] <= 0;
      visited[i] <= 0;
      leaves[i] <= 0;
      stack[i] <= 0;
      for (int j=0; j<7; j=j+1)
        adj_list[i][j] <= 0;
    end
    sp <= 0;
    leaf_count <= 0;
    parse_k <= 0;
    m_reg <= 0;
  end
  else begin
    case(state)
      IDLE: begin
        done <= 0;
        if (start) begin
          parse_k <= 0;
          for (int i=0; i<8; i=i+1) deg[i] <= 0;
          state <= PARSE_EDGES;
        end
      end

      PARSE_EDGES: begin
        if (parse_k < 7 && parse_k < (n-1)) begin
          if (edges[parse_k*6 +:3] < n && edges[parse_k*6+3 +:3] < n) begin
            integer a = edges[parse_k*6 +:3];
            integer b = edges[parse_k*6+3 +:3];
            adj_list[a][deg[a]] <= b;
            adj_list[b][deg[b]] <= a;
            deg[a] <= deg[a] + 1;
            deg[b] <= deg[b] + 1;
          end
          parse_k <= parse_k + 1;
        end else begin
          for (int i=0; i<8; i=i+1) visited[i] <= 0;
          visited[h] <= 1;
          sp <= 1;
          stack[0] <= {h, 3'b0};
          leaf_count <= 0;
          state <= DFS_TRAVERSE;
        end
      end

      DFS_TRAVERSE: begin
        if (sp > 0) begin
          integer current_node = stack[sp-1][5:3];
          integer next_nbr = stack[sp-1][2:0];
          if (next_nbr < deg[current_node]) begin
            integer child = adj_list[current_node][next_nbr];
            if (!visited[child]) begin
              visited[child] <= 1;
              stack[sp] <= {child[2:0], 3'b0};
              sp <= sp + 1;
            end
            stack[sp-1][2:0] <= next_nbr + 1;
          end else begin
            if (deg[current_node] == 1) begin
              leaves[leaf_count] <= current_node;
              leaf_count <= leaf_count + 1;
            end
            sp <= sp - 1;
          end
        end else begin
          state <= CALCULATE;
        end
      end

      CALCULATE: begin
        m_reg <= (leaf_count[0]) ? (leaf_count >> 1) + 1 : (leaf_count >> 1);
        m <= m_reg;
        added_edges <= 32'b0;
        if (leaf_count > 0) begin
          for (int i=0; i<7; i=i+1) begin
            if (i < m_reg && i < 7) begin
              integer j = (i + m_reg) % leaf_count;
              integer min_node = (leaves[i] < leaves[j]) ? leaves[i] : leaves[j];
              integer max_node = (leaves[i] < leaves[j]) ? leaves[j] : leaves[i];
              added_edges[i*6 +:6] <= {min_node[2:0], max_node[2:0]};
            end
            else
              added_edges[i*6 +:6] <= 6'b0;
          end
        end
        state <= DONE_ST;
      end

      DONE_ST: begin
        done <= 1;
        if (!start)
          state <= IDLE;
      end
    endcase
  end
end

endmodule