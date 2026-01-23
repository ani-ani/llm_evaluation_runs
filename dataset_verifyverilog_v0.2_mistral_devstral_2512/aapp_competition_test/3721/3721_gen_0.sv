module chemical_table(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] m,
  input [3:0] q,
  input valid_in,
  input [3:0] r,
  input [3:0] c,
  output reg [7:0] result,
  output reg done,
  output reg rden
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_INPUTS,
    PROCESS_INPUTS,
    COUNT_COMPONENTS,
    FINALIZE
  } state_t;

  state_t state;
  reg [3:0] input_count;
  reg [3:0] current_r, current_c;
  reg [3:0] parent [0:15];
  reg [3:0] rank [0:15];
  reg [3:0] node;
  reg [3:0] root;
  reg [3:0] component_count;
  reg [3:0] i, j;

  // Initialize DSU
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      input_count <= 0;
      current_r <= 0;
      current_c <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        parent[i] <= i;
        rank[i] <= 0;
      end
      node <= 0;
      root <= 0;
      component_count <= 0;
      result <= 0;
      done <= 0;
      rden <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= READ_INPUTS;
            input_count <= 0;
            rden <= 1;
          end
        end
        READ_INPUTS: begin
          if (valid_in) begin
            current_r <= r;
            current_c <= c;
            input_count <= input_count + 1;
            if (input_count == q) begin
              state <= PROCESS_INPUTS;
              node <= 0;
              rden <= 0;
            end
          end
        end
        PROCESS_INPUTS: begin
          if (node < q) begin
            // Union operation
            root <= find(parent, current_r);
            root <= find(parent, current_c + n);
            if (root != find(parent, current_c + n)) begin
              union_nodes(parent, rank, current_r, current_c + n);
            end
            node <= node + 1;
          end else begin
            state <= COUNT_COMPONENTS;
            component_count <= 0;
            i <= 0;
          end
        end
        COUNT_COMPONENTS: begin
          if (i < n + m) begin
            if (find(parent, i) == i) begin
              component_count <= component_count + 1;
            end
            i <= i + 1;
          end else begin
            state <= FINALIZE;
          end
        end
        FINALIZE: begin
          result <= component_count - 1;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

  // Find function with path compression
  function [3:0] find;
    input [3:0] parent [0:15];
    input [3:0] x;
    reg [3:0] root;
    begin
      root = x;
      while (parent[root] != root) begin
        root = parent[root];
      end
      // Path compression
      while (parent[x] != root) begin
        parent[x] = root;
        x = parent[x];
      end
      find = root;
    end
  endfunction

  // Union function with union by rank
  task union_nodes;
    input [3:0] parent [0:15];
    input [3:0] rank [0:15];
    input [3:0] x;
    input [3:0] y;
    reg [3:0] root_x, root_y;
    begin
      root_x = find(parent, x);
      root_y = find(parent, y);
      if (root_x != root_y) begin
        if (rank[root_x] < rank[root_y]) begin
          parent[root_x] = root_y;
        end else if (rank[root_x] > rank[root_y]) begin
          parent[root_y] = root_x;
        end else begin
          parent[root_y] = root_x;
          rank[root_x] = rank[root_x] + 1;
        end
      end
    end
  endtask

endmodule