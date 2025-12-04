module max_tree_group(
  input clk,
  input rst_n,
  input start,
  input [19:0] h_matrix [0:15],
  input [19:0] v_matrix [0:15],
  output reg [4:0] max_group_size,
  output reg done
);

  localparam IDLE      = 3'b000;
  localparam PRE_COMP  = 3'b001;
  localparam BFS_INIT  = 3'b010;
  localparam CHECK_NODE= 3'b011;
  localparam BFS_LOOP  = 3'b100;
  localparam UPDATE_MAX= 3'b101;
  localparam DONE_ST   = 3'b110;
  
  reg [2:0] state, next_state;
  reg [15:0] adj_matrix [0:15];
  reg [5:0] precomp_cnt;
  reg [4:0] edge_cnt;
  reg [15:0] visited;
  reg [15:0] current_queue;
  reg [15:0] next_queue;
  reg [4:0] curr_size;
  reg [3:0] node_idx;
  
  // Edge computation wires
  wire [3:0] row, col;
  wire [3:0] cell1, cell2;
  wire v_eq, h_eq;
  wire v_gt, h_gt;
  wire can_equal;
  
  // Compute cell indices based on edge_cnt
  assign row = edge_cnt[4] ? (edge_cnt[3:2]) : edge_cnt[3:2];
  assign col = edge_cnt[4] ? (edge_cnt[1:0]) : edge_cnt[1:0];
  assign cell1 = edge_cnt < 12 ? (row * 4) + col :
                 ((edge_cnt - 12) / 3) * 4 + (edge_cnt - 12) % 3;
  assign cell2 = edge_cnt < 12 ? (row * 4) + col + 1 :
                 (((edge_cnt - 12) / 3) + 1) * 4 + (edge_cnt - 12) % 3;
  
  // Adjacency condition logic
  assign v_eq = (v_matrix[cell1] == v_matrix[cell2]);
  assign h_eq = (h_matrix[cell1] == h_matrix[cell2]);
  assign v_gt = (v_matrix[cell1] > v_matrix[cell2]);
  assign h_gt = (h_matrix[cell2] > h_matrix[cell1]);
  assign can_equal = v_eq ? h_eq : (v_gt && h_gt) || (!v_gt && !h_gt);
  
  // Popcount function
  function [4:0] popcount;
    input [15:0] vec;
    begin
      popcount = vec[0] + vec[1] + vec[2] + vec[3] + vec[4] + vec[5] + vec[6] + vec[7] +
                 vec[8] + vec[9] + vec[10] + vec[11] + vec[12] + vec[13] + vec[14] + vec[15];
    end
  endfunction
  
  // Next neighbor calculation
  function [15:0] calc_neighbors;
    input [15:0] current;
    reg [15:0] temp;
    integer i;
    begin
      temp = 16'b0;
      for (i=0; i<16; i++) begin
        if (current[i]) temp = temp | adj_matrix[i];
      end
      calc_neighbors = temp;
    end
  endfunction
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      precomp_cnt <= 0;
      edge_cnt <= 0;
      done <= 0;
      visited <= 16'b0;
      current_queue <= 16'b0;
      next_queue <= 16'b0;
      curr_size <= 0;
      node_idx <= 0;
      max_group_size <= 0;
      for (int i=0; i<16; i++) adj_matrix[i] <= 16'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PRE_COMP;
            precomp_cnt <= 0;
            edge_cnt <= 0;
            max_group_size <= 0;
            done <= 0;
          end
        end
        PRE_COMP: begin
          if (precomp_cnt < 50) begin
            precomp_cnt <= precomp_cnt + 1;
            if (precomp_cnt < 24) begin
              adj_matrix[cell1][cell2] <= can_equal;
              adj_matrix[cell2][cell1] <= can_equal;
              edge_cnt <= edge_cnt + 1;
            end
          end else begin
            state <= BFS_INIT;
          end
        end
        BFS_INIT: begin
          visited <= 16'b0;
          node_idx <= 0;
          max_group_size <= 0;
          state <= CHECK_NODE;
        end
        CHECK_NODE: begin
          if (node_idx < 16) begin
            if (!visited[node_idx]) begin
              visited[node_idx] <= 1'b1;
              current_queue <= (16'b1 << node_idx);
              curr_size <= 5'b1;
              state <= BFS_LOOP;
            end else begin
              node_idx <= node_idx + 1;
            end
          end else begin
            state <= DONE_ST;
          end
        end
        BFS_LOOP: begin
          if (current_queue != 0) begin
            next_queue <= calc_neighbors(current_queue) & ~visited;
            visited <= visited | (calc_neighbors(current_queue) & ~visited);
            curr_size <= curr_size + popcount(calc_neighbors(current_queue) & ~visited);
            current_queue <= next_queue;
          end else begin
            state <= UPDATE_MAX;
          end
        end
        UPDATE_MAX: begin
          if (curr_size > max_group_size) max_group_size <= curr_size;
          node_idx <= node_idx + 1;
          state <= CHECK_NODE;
        end
        DONE_ST: begin
          done <= 1'b1;
          if (!start) state <= IDLE;
        end
      endcase
    end
  end
endmodule