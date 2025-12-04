module flight_path_finder (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [2:0] s,
  input [2:0] t,
  input [7:0] adj_types,
  input [7:0][7:0] adj_lists,
  output reg [3:0] hops,
  output reg done,
  output reg impossible
);
  parameter IDLE = 0;
  parameter BUILD_MATRIX = 1;
  parameter BFS = 2;
  parameter DONE = 3;
  
  reg [1:0] state;
  reg [7:0] adj_matrix [0:7];
  reg [2:0] queue_node [0:7];
  reg [3:0] queue_hops [0:7];
  reg [2:0] read_ptr, write_ptr;
  reg [7:0] visited;
  reg [2:0] current_node;
  reg [3:0] current_hops;
  reg [5:0] build_counter;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      impossible <= 0;
      hops <= 0;
      foreach (adj_matrix[i]) adj_matrix[i] <= 0;
      read_ptr <= 0;
      write_ptr <= 0;
      build_counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          impossible <= 0;
          hops <= 0;
          if (start) begin
            state <= BUILD_MATRIX;
            build_counter <= 0;
          end
        end
        
        BUILD_MATRIX: begin
          if (build_counter < 64) begin
            automatic int i = build_counter / 8;
            automatic int j = build_counter % 8;
            if (i < N && j < N) begin
              if (adj_types[i] == 0)
                adj_matrix[i][j] <= adj_lists[i][j];
              else
                adj_matrix[i][j] <= ~adj_lists[i][j];
            end
            build_counter <= build_counter + 1;
          end else begin
            state <= BFS;
            visited <= (1 << s);
            queue_node[0] <= s;
            queue_hops[0] <= 0;
            write_ptr <= 1;
            read_ptr <= 0;
          end
        end
        
        BFS: begin
          if (read_ptr != write_ptr) begin
            current_node <= queue_node[read_ptr];
            current_hops <= queue_hops[read_ptr];
            read_ptr <= read_ptr + 1;
            
            if (current_node == t) begin
              state <= DONE;
              hops <= current_hops;
            end else begin
              for (int j = 0; j < N; j++) begin
                if (adj_matrix[current_node][j] && !(visited[j])) begin
                  visited[j] <= 1;
                  queue_node[write_ptr] <= j;
                  queue_hops[write_ptr] <= current_hops + 1;
                  write_ptr <= write_ptr + 1;
                end
              end
            end
          end else begin
            state <= DONE;
            impossible <= 1;
            hops <= 4'hF;
          end
        end
        
        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule