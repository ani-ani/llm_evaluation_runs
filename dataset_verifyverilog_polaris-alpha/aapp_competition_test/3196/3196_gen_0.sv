module graph_path_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] N,
  input [2:0] M,
  input [31:0] edges,
  output reg done,
  output reg [31:0] result
);

  // Parameters
  localparam MOD = 32'd1000000000; // 1e9

  // FSM States
  localparam [2:0]
    IDLE          = 3'd0,
    INIT          = 3'd1,
    BUILD_ADJ     = 3'd2,
    CYCLE_DETECT  = 3'd3,
    COUNT_PATHS   = 3'd4,
    DONE_STATE    = 3'd5;

  reg [2:0] state, next_state;

  // Internal registers
  reg [1:0] N_reg;       // number of nodes-1
  reg [2:0] M_reg;       // number of edges
  reg [31:0] edges_reg;  // latched edges

  // adjacency matrix counts: adj[a][b] for nodes 0..3
  reg [3:0] adj00, adj01, adj02, adj03;
  reg [3:0] adj10, adj11, adj12, adj13;
  reg [3:0] adj20, adj21, adj22, adj23;
  reg [3:0] adj30, adj31, adj32, adj33;

  // Edge build index
  reg [2:0] edge_idx;

  // Cycle detection using DFS with explicit stack (max 4 nodes)
  // Stack arrays
  reg [1:0] stack_node [0:3];
  reg [1:0] stack_next_idx [0:3];
  reg [1:0] sp; // stack pointer (depth)

  // visited and on-stack flags
  reg visited0, visited1, visited2, visited3;
  reg instk0, instk1, instk2, instk3;

  // cycle found flag
  reg cycle_found;

  // helper decode for valid nodes
  wire [1:0] max_node_idx = N_reg; // nodes 0..N_reg

  // Function to check node in range
  function automatic is_valid_node;
    input [1:0] n;
    begin
      is_valid_node = (n <= max_node_idx);
    end
  endfunction

  // Get adjacency count for a->b
  function automatic [3:0] get_adj;
    input [1:0] a;
    input [1:0] b;
    begin
      case ({a,b})
        4'b0000: get_adj = adj00;
        4'b0001: get_adj = adj01;
        4'b0010: get_adj = adj02;
        4'b0011: get_adj = adj03;
        4'b0100: get_adj = adj10;
        4'b0101: get_adj = adj11;
        4'b0110: get_adj = adj12;
        4'b0111: get_adj = adj13;
        4'b1000: get_adj = adj20;
        4'b1001: get_adj = adj21;
        4'b1010: get_adj = adj22;
        4'b1011: get_adj = adj23;
        4'b1100: get_adj = adj30;
        4'b1101: get_adj = adj31;
        4'b1110: get_adj = adj32;
        4'b1111: get_adj = adj33;
        default: get_adj = 4'd0;
      endcase
    end
  endfunction

  // Increment adjacency (combinational helper used in seq always)
  task automatic inc_adj;
    input [1:0] a;
    input [1:0] b;
    begin
      case ({a,b})
        4'b0000: adj00 <= adj00 + 4'd1;
        4'b0001: adj01 <= adj01 + 4'd1;
        4'b0010: adj02 <= adj02 + 4'd1;
        4'b0011: adj03 <= adj03 + 4'd1;
        4'b0100: adj10 <= adj10 + 4'd1;
        4'b0101: adj11 <= adj11 + 4'd1;
        4'b0110: adj12 <= adj12 + 4'd1;
        4'b0111: adj13 <= adj13 + 4'd1;
        4'b1000: adj20 <= adj20 + 4'd1;
        4'b1001: adj21 <= adj21 + 4'd1;
        4'b1010: adj22 <= adj22 + 4'd1;
        4'b1011: adj23 <= adj23 + 4'd1;
        4'b1100: adj30 <= adj30 + 4'd1;
        4'b1101: adj31 <= adj31 + 4'd1;
        4'b1110: adj32 <= adj32 + 4'd1;
        4'b1111: adj33 <= adj33 + 4'd1;
        default: ;
      endcase
    end
  endtask

  // Path counting via DFS enumerating simple paths from 0 to 1
  reg [1:0] p_stack_node [0:3];
  reg [1:0] p_stack_next_idx [0:3];
  reg       p_used0, p_used1, p_used2, p_used3;
  reg [1:0] p_sp;
  reg [31:0] path_count;

  // Extract edge A/B based on edge_idx
  function automatic [3:0] get_edge_packed;
    input [2:0] idx;
    begin
      case (idx)
        3'd0: get_edge_packed = edges_reg[3:0];
        3'd1: get_edge_packed = edges_reg[7:4];
        3'd2: get_edge_packed = edges_reg[11:8];
        3'd3: get_edge_packed = edges_reg[15:12];
        3'd4: get_edge_packed = edges_reg[19:16];
        3'd5: get_edge_packed = edges_reg[23:20];
        3'd6: get_edge_packed = edges_reg[27:24];
        3'd7: get_edge_packed = edges_reg[31:28];
        default: get_edge_packed = 4'd0;
      endcase
    end
  endfunction

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 32'd0;
      N_reg <= 2'd0;
      M_reg <= 3'd0;
      edges_reg <= 32'd0;
      edge_idx <= 3'd0;
      // clear adjacency
      adj00 <= 0; adj01 <= 0; adj02 <= 0; adj03 <= 0;
      adj10 <= 0; adj11 <= 0; adj12 <= 0; adj13 <= 0;
      adj20 <= 0; adj21 <= 0; adj22 <= 0; adj23 <= 0;
      adj30 <= 0; adj31 <= 0; adj32 <= 0; adj33 <= 0;
      // cycle detect
      visited0 <= 0; visited1 <= 0; visited2 <= 0; visited3 <= 0;
      instk0 <= 0; instk1 <= 0; instk2 <= 0; instk3 <= 0;
      sp <= 0;
      cycle_found <= 1'b0;
      // paths
      p_used0 <= 1'b0; p_used1 <= 1'b0; p_used2 <= 1'b0; p_used3 <= 1'b0;
      p_sp <= 0;
      path_count <= 32'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          result <= result; // hold
          if (start) begin
            // latch inputs
            N_reg <= N;
            M_reg <= M;
            edges_reg <= edges;
            // clear adjacency
            adj00 <= 0; adj01 <= 0; adj02 <= 0; adj03 <= 0;
            adj10 <= 0; adj11 <= 0; adj12 <= 0; adj13 <= 0;
            adj20 <= 0; adj21 <= 0; adj22 <= 0; adj23 <= 0;
            adj30 <= 0; adj31 <= 0; adj32 <= 0; adj33 <= 0;
            edge_idx <= 3'd0;
            cycle_found <= 1'b0;
            // reset cycle detect flags
            visited0 <= 0; visited1 <= 0; visited2 <= 0; visited3 <= 0;
            instk0 <= 0; instk1 <= 0; instk2 <= 0; instk3 <= 0;
            sp <= 0;
            // reset path count vars
            path_count <= 32'd0;
            p_sp <= 0;
            p_used0 <= 1'b0; p_used1 <= 1'b0; p_used2 <= 1'b0; p_used3 <= 1'b0;
          end
        end

        INIT: begin
          // nothing extra; work done on IDLE->INIT transition
        end

        BUILD_ADJ: begin
          if (edge_idx < M_reg) begin
            // parse current edge
            // format per problem statement assumed:
            // low 2 bits = A, high 2 bits = B of 4-bit slice
            // edge_packed[1:0] = A, [3:2] = B
            reg [3:0] ep;
            reg [1:0] a;
            reg [1:0] b;
            ep = get_edge_packed(edge_idx);
            a = ep[1:0];
            b = ep[3:2];
            if (is_valid_node(a) && is_valid_node(b)) begin
              inc_adj(a,b);
            end
            edge_idx <= edge_idx + 3'd1;
          end
          // else: done in next_state logic
        end

        CYCLE_DETECT: begin
          // Iterative DFS from node 0, looking for cycles reachable from src
          // One DFS step per cycle for simplicity
          if (!cycle_found && (N_reg != 2'd0 || N_reg == 2'd0)) begin
            // treat node 0 as start if valid
            // If stack empty and start not visited, push 0
            if (sp == 0 && !visited0 && (0 <= max_node_idx)) begin
              stack_node[0] <= 2'd0;
              stack_next_idx[0] <= 2'd0;
              sp <= 1;
              visited0 <= 1'b1;
              instk0 <= 1'b1;
            end else if (sp != 0 && !cycle_found) begin
              // top of stack
              reg [1:0] u;
              reg [1:0] idx;
              reg [1:0] v;
              reg [3:0] adj_cnt;
              u = stack_node[sp-1];
              idx = stack_next_idx[sp-1];
              if (idx > max_node_idx) begin
                // pop u
                sp <= sp - 1;
                case (u)
                  2'd0: instk0 <= 1'b0;
                  2'd1: instk1 <= 1'b0;
                  2'd2: instk2 <= 1'b0;
                  2'd3: instk3 <= 1'b0;
                endcase
              end else begin
                v = idx;
                adj_cnt = get_adj(u,v);
                stack_next_idx[sp-1] <= idx + 2'd1;
                if (adj_cnt != 4'd0) begin
                  // edge u->v exists
                  // if v on stack => cycle
                  if ((v==2'd0 && instk0) || (v==2'd1 && instk1) || (v==2'd2 && instk2) || (v==2'd3 && instk3)) begin
                    cycle_found <= 1'b1;
                  end else if ((v==2'd0 && !visited0) || (v==2'd1 && !visited1) || (v==2'd2 && !visited2) || (v==2'd3 && !visited3)) begin
                    // push v
                    stack_node[sp] <= v;
                    stack_next_idx[sp] <= 2'd0;
                    sp <= sp + 1;
                    case (v)
                      2'd0: begin visited0 <= 1'b1; instk0 <= 1'b1; end
                      2'd1: begin visited1 <= 1'b1; instk1 <= 1'b1; end
                      2'd2: begin visited2 <= 1'b1; instk2 <= 1'b1; end
                      2'd3: begin visited3 <= 1'b1; instk3 <= 1'b1; end
                    endcase
                  end
                end
              end
            end
          end
        end

        COUNT_PATHS: begin
          // Non-recursive DFS enumerating simple paths from 0 to 1
          // One step per cycle
          if (p_sp == 0) begin
            // initialize if src valid
            if (0 <= max_node_idx && 1 <= max_node_idx) begin
              p_stack_node[0] <= 2'd0;
              p_stack_next_idx[0] <= 2'd0;
              p_sp <= 1;
              p_used0 <= 1'b1;
              p_used1 <= 1'b0;
              p_used2 <= 1'b0;
              p_used3 <= 1'b0;
              path_count <= 32'd0;
            end else begin
              // invalid src/dst => 0 paths
              path_count <= 32'd0;
            end
          end else begin
            reg [1:0] u;
            reg [1:0] idx;
            reg [1:0] v;
            reg [3:0] c_adj;
            u = p_stack_node[p_sp-1];
            idx = p_stack_next_idx[p_sp-1];
            if (u == 2'd1) begin
              // reached destination, count one path
              if (path_count >= MOD-1) begin
                path_count <= path_count + 32'd1 - MOD;
              end else begin
                path_count <= path_count + 32'd1;
              end
              // backtrack
              // pop top
              if (u==2'd0) p_used0 <= 1'b0;
              else if (u==2'd1) p_used1 <= 1'b0;
              else if (u==2'd2) p_used2 <= 1'b0;
              else if (u==2'd3) p_used3 <= 1'b0;
              p_sp <= p_sp - 1;
            end else if (idx > max_node_idx) begin
              // no more neighbors, backtrack
              if (u==2'd0) p_used0 <= 1'b0;
              else if (u==2'd1) p_used1 <= 1'b0;
              else if (u==2'd2) p_used2 <= 1'b0;
              else if (u==2'd3) p_used3 <= 1'b0;
              p_sp <= p_sp - 1;
            end else begin
              v = idx;
              p_stack_next_idx[p_sp-1] <= idx + 2'd1;
              c_adj = get_adj(u,v);
              if (c_adj != 4'd0) begin
                // consider v if not used (simple path)
                if ((v==2'd0 && !p_used0) ||
                    (v==2'd1 && !p_used1) ||
                    (v==2'd2 && !p_used2) ||
                    (v==2'd3 && !p_used3)) begin
                  // push v
                  p_stack_node[p_sp] <= v;
                  p_stack_next_idx[p_sp] <= 2'd0;
                  p_sp <= p_sp + 1;
                  if (v==2'd0) p_used0 <= 1'b1;
                  else if (v==2'd1) p_used1 <= 1'b1;
                  else if (v==2'd2) p_used2 <= 1'b1;
                  else if (v==2'd3) p_used3 <= 1'b1;
                end
              end
            end
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
          // result set in next_state or when entering DONE_STATE
        end

        default: ;
      endcase
    end
  end

  // FSM combinational next-state and result logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        next_state = BUILD_ADJ;
      end

      BUILD_ADJ: begin
        if (edge_idx >= M_reg)
          next_state = CYCLE_DETECT;
      end

      CYCLE_DETECT: begin
        // if cycle found, we can finish
        if (cycle_found) begin
          next_state = DONE_STATE;
        end else begin
          // termination of DFS: when stack empty and start already visited
          // Using sp==0 and visited0==1 as proxy for completion
          if (sp == 0 && visited0)
            next_state = COUNT_PATHS;
        end
      end

      COUNT_PATHS: begin
        // done when stack empty (search completed)
        if (p_sp == 0) begin
          next_state = DONE_STATE;
        end
      end

      DONE_STATE: begin
        // stay until new start deasserted & asserted again
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Output result update (sequentially in DONE_STATE or when moving there)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 32'd0;
    end else begin
      if (state != DONE_STATE && next_state == DONE_STATE) begin
        if (cycle_found) begin
          // infinite paths reachable due to cycle
          result[31] <= 1'b1;
          result[30:0] <= 31'd0;
        end else begin
          result[31] <= 1'b0;
          result[30:0] <= path_count[30:0];
        end
      end
    end
  end

endmodule