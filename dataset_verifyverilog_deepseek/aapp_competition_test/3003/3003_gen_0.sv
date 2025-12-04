module graph_color(
  input clk,
  input rst_n,
  input start,
  input [2:0] n_val,
  input [63:0] adjacency,
  output reg [3:0] colors,
  output reg done
);

  localparam MAX_VERTICES = 8;
  
  typedef enum {
    IDLE,
    INIT,
    TEST_COLOR,
    CHECK_CONFLICT,
    NEXT_VERTEX,
    BACKTRACK,
    INCR_LIMIT,
    FINISH
  } state_t;
  
  reg [2:0] adj_matrix [7:0][7:0];
  reg [2:0] color_assign [7:0];
  reg [2:0] vertex;
  reg [3:0] color_limit;
  reg [3:0] best_colors;
  reg [2:0] color;
  reg conflict;
  reg [9:0] cycle_count;
  state_t state;
  integer i, j;
  
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      colors <= 4'b0;
      done <= 1'b0;
      for (i = 0; i < MAX_VERTICES; i = i + 1) begin
        for (j = 0; j < MAX_VERTICES; j = j + 1)
          adj_matrix[i][j] <= 1'b0;
        color_assign[i] <= 3'b0;
      end
      state <= IDLE;
      vertex <= 3'b0;
      color_limit <= 4'd1;
      best_colors <= 4'd0;
      color <= 3'b1;
      cycle_count <= 10'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          cycle_count <= 10'b0;
          if (start) begin
            for (i = 0; i < MAX_VERTICES; i = i + 1) begin
              for (j = 0; j < MAX_VERTICES; j = j + 1)
                adj_matrix[i][j] <= adjacency[i*8 + j];
            end
            best_colors <= 4'd8;
            color_limit <= 4'd1;
            state <= INIT;
          end
        end
        
        INIT: begin
          for (i = 0; i < MAX_VERTICES; i = i + 1)
            color_assign[i] <= 3'b0;
          vertex <= 3'b0;
          color <= 3'b1;
          state <= TEST_COLOR;
        end
        
        TEST_COLOR: begin
          if (color > color_limit) begin
            state <= BACKTRACK;
          end else begin
            color_assign[vertex] <= color;
            state <= CHECK_CONFLICT;
          end
        end
        
        CHECK_CONFLICT: begin
          conflict <= 1'b0;
          for (j = 0; j < vertex; j = j + 1) begin
            if (adj_matrix[vertex][j] && (color_assign[j] == color)) begin
              conflict <= 1'b1;
            end
          end
          if (conflict) begin
            color <= color + 1;
            state <= TEST_COLOR;
          end else begin
            state <= NEXT_VERTEX;
          end
        end
        
        NEXT_VERTEX: begin
          if (vertex == n_val - 1) begin
            best_colors <= color_limit;
            state <= FINISH;
          end else begin
            vertex <= vertex + 1;
            color <= 3'b1;
            state <= TEST_COLOR;
          end
        end
        
        BACKTRACK: begin
          if (vertex == 0) begin
            if (color_limit < (n_val)) begin
              color_limit <= color_limit + 1;
              state <= INIT;
            end else begin
              state <= FINISH;
            end
          end else begin
            vertex <= vertex - 1;
            color <= color_assign[vertex] + 1;
            state <= TEST_COLOR;
          end
        end
        
        FINISH: begin
          colors <= best_colors;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
      
      if (state != IDLE && state != FINISH) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count == 1023)
          state <= FINISH;
      end
    end
  end
endmodule