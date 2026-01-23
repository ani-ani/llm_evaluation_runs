module spanning_tree_check (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [4:0] k,
  input [3:0] m,
  input [3:0] edge_index,
  input edge_valid,
  input [2:0] node_u,
  input [2:0] node_v,
  input edge_color,
  output reg result,
  output reg done
);

  // States
  localparam [3:0] IDLE = 4'b0000;
  localparam [3:0] LOAD_EDGES = 4'b0001;
  localparam [3:0] SORT_EDGES = 4'b0010;
  localparam [3:0] COMPUTE_MIN = 4'b0011;
  localparam [3:0] COMPUTE_MAX = 4'b0100;
  localparam [3:0] CHECK_RESULT = 4'b0101;
  localparam [3:0] DONE = 4'b0110;

  reg [3:0] state = IDLE;
  reg [3:0] edge_count = 0;
  reg [3:0] sort_index = 0;
  reg [3:0] process_index = 0;
  reg [3:0] dsu_parent [0:7];
  reg [3:0] dsu_rank [0:7];
  reg [3:0] min_blue = 0;
  reg [3:0] max_blue = 0;
  reg [3:0] blue_count = 0;
  reg [3:0] union_count = 0;

  // Edge buffer: 16 entries of {color, u, v}
  reg edge_buffer_color [0:15];
  reg [2:0] edge_buffer_u [0:15];
  reg [2:0] edge_buffer_v [0:15];

  // Temporary sorted edge buffers
  reg sorted_min_color [0:15];
  reg [2:0] sorted_min_u [0:15];
  reg [2:0] sorted_min_v [0:15];
  reg sorted_max_color [0:15];
  reg [2:0] sorted_max_u [0:15];
  reg [2:0] sorted_max_v [0:15];

  // DSU find function
  function [3:0] dsu_find;
    input [3:0] x;
    reg [3:0] root;
    integer i;
    begin
      root = x;
      for (i = 0; i < 8; i = i + 1) begin
        if (dsu_parent[root] != root) begin
          root = dsu_parent[root];
        end
      end
      dsu_find = root;
    end
  endfunction

  // DSU union function
  function [3:0] dsu_union;
    input [3:0] x;
    input [3:0] y;
    reg [3:0] root_x;
    reg [3:0] root_y;
    begin
      root_x = dsu_find(x);
      root_y = dsu_find(y);
      if (root_x == root_y) begin
        dsu_union = 0;
      end else begin
        if (dsu_rank[root_x] < dsu_rank[root_y]) begin
          dsu_parent[root_x] = root_y;
        end else if (dsu_rank[root_x] > dsu_rank[root_y]) begin
          dsu_parent[root_y] = root_x;
        end else begin
          dsu_parent[root_y] = root_x;
          dsu_rank[root_x] = dsu_rank[root_x] + 1;
        end
        dsu_union = 1;
      end
    end
  endfunction

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      edge_count <= 0;
      sort_index <= 0;
      process_index <= 0;
      min_blue <= 0;
      max_blue <= 0;
      blue_count <= 0;
      union_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_EDGES;
            edge_count <= 0;
          end
        end

        LOAD_EDGES: begin
          if (edge_valid) begin
            edge_buffer_color[edge_index] <= edge_color;
            edge_buffer_u[edge_index] <= node_u - 1;
            edge_buffer_v[edge_index] <= node_v - 1;
            edge_count <= edge_index + 1;
            if (edge_index == m - 1) begin
              state <= SORT_EDGES;
              sort_index <= 0;
            end
          end
        end

        SORT_EDGES: begin
          // Simple sorting: Red edges first for min_blue, Blue edges first for max_blue
          if (sort_index < m) begin
            // Min_blue sort: Red edges first
            if (edge_buffer_color[sort_index] == 0) begin
              sorted_min_color[sort_index] <= edge_buffer_color[sort_index];
              sorted_min_u[sort_index] <= edge_buffer_u[sort_index];
              sorted_min_v[sort_index] <= edge_buffer_v[sort_index];
            end
            // Max_blue sort: Blue edges first
            if (edge_buffer_color[sort_index] == 1) begin
              sorted_max_color[sort_index] <= edge_buffer_color[sort_index];
              sorted_max_u[sort_index] <= edge_buffer_u[sort_index];
              sorted_max_v[sort_index] <= edge_buffer_v[sort_index];
            end
            sort_index <= sort_index + 1;
          end else begin
            state <= COMPUTE_MIN;
            process_index <= 0;
            blue_count <= 0;
            union_count <= 0;
            // Initialize DSU for min_blue computation
            for (integer i = 0; i < 8; i = i + 1) begin
              dsu_parent[i] <= i;
              dsu_rank[i] <= 0;
            end
          end
        end

        COMPUTE_MIN: begin
          if (process_index < m) begin
            if (dsu_union(sorted_min_u[process_index], sorted_min_v[process_index])) begin
              union_count <= union_count + 1;
              if (sorted_min_color[process_index] == 1) begin
                blue_count <= blue_count + 1;
              end
            end
            process_index <= process_index + 1;
            if (process_index == m) begin
              min_blue <= blue_count;
              state <= COMPUTE_MAX;
              process_index <= 0;
              blue_count <= 0;
              union_count <= 0;
              // Initialize DSU for max_blue computation
              for (integer i = 0; i < 8; i = i + 1) begin
                dsu_parent[i] <= i;
                dsu_rank[i] <= 0;
              end
            end
          end
        end

        COMPUTE_MAX: begin
          if (process_index < m) begin
            if (dsu_union(sorted_max_u[process_index], sorted_max_v[process_index])) begin
              union_count <= union_count + 1;
              if (sorted_max_color[process_index] == 1) begin
                blue_count <= blue_count + 1;
              end
            end
            process_index <= process_index + 1;
            if (process_index == m) begin
              max_blue <= blue_count;
              state <= CHECK_RESULT;
            end
          end
        end

        CHECK_RESULT: begin
          if (k >= min_blue && k <= max_blue) begin
            result <= 1;
          end else begin
            result <= 0;
          end
          state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule