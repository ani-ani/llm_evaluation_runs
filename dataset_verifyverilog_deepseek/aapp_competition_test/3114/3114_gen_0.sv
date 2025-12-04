module directed_strong_connect(
  input clk,
  input rst_n,
  input start,
  input [15:0] adj_matrix,
  output reg possible,
  output reg [15:0] directed_graph,
  output reg done
);
  
  typedef enum logic [1:0] {IDLE, PROCESSING, DONE_STATE} state_t;
  state_t state, next_state;
  
  reg [3:0] counter, next_counter;
  reg [15:0] adj_matrix_reg;
  reg possible_reg, next_possible_reg;
  
  function automatic logic is_connected(input [15:0] adj);
    logic [3:0] visited, tmp;
    visited = 4'b0001;
    repeat (3) begin
      tmp = 4'b0;
      for (int i = 0; i < 4; i++) begin
        if (visited[i]) begin
          tmp |= adj[4*i +: 4];
        end
      end
      visited = visited | tmp;
    end
    return (visited == 4'b1111);
  endfunction
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 4'b0;
      possible_reg <= 1'b0;
      adj_matrix_reg <= 16'b0;
      possible <= 1'b0;
      directed_graph <= 16'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      counter <= next_counter;
      possible_reg <= next_possible_reg;
      
      if (state == IDLE && start) begin
        adj_matrix_reg <= adj_matrix;
        possible <= 1'b0;
        directed_graph <= 16'b0;
        done <= 1'b0;
      end
      
      if (next_state == DONE_STATE) begin
        done <= 1'b1;
        possible <= possible_reg;
        
        if (possible_reg) begin
          for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
              if (i == j) begin
                directed_graph[i*4 + j] <= 1'b0;
              end else if (adj_matrix_reg[i*4 + j]) begin
                if (i == 0) begin
                  directed_graph[i*4 + j] <= 1'b1;
                  directed_graph[j*4 + i] <= 1'b0;
                end else if (j == 0) begin
                  directed_graph[i*4 + j] <= 1'b0;
                end else begin
                  directed_graph[i*4 + j] <= (i < j);
                  directed_graph[j*4 + i] <= (i > j);
                end
              end else begin
                directed_graph[i*4 + j] <= 1'b0;
              end
            end
          end
        end else begin
          directed_graph <= 16'b0;
        end
      end
    end
  end
  
  always_comb begin
    next_state = state;
    next_counter = counter;
    next_possible_reg = possible_reg;
    unique case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          next_counter = 4'b0000;
          next_possible_reg = 1'b1;
        end
      end
      
      PROCESSING: begin
        next_counter = counter + 1;
        logic [1:0] i = counter[3:2];
        logic [1:0] j = counter[1:0];
        if (i != j && adj_matrix_reg[i*4 + j]) begin
          logic [15:0] temp_matrix = adj_matrix_reg;
          temp_matrix[i*4 + j] = 1'b0;
          temp_matrix[j*4 + i] = 1'b0;
          if (!is_connected(temp_matrix)) begin
            next_possible_reg = 1'b0;
          end
        end
        
        if (counter == 4'b1111) begin
          next_state = DONE_STATE;
        end
      end
      
      DONE_STATE: begin
        if (start) begin
          next_state = IDLE;
          next_possible_reg = 1'b0;
        end
      end
    endcase
  end
  
endmodule