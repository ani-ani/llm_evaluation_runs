module magic_color_counter (
  input clk,
  input rst_n,
  input start,
  input [2:0] node_id,
  input [1:0] cmd_data,
  input [2:0] parents [1:7],
  input [1:0] init_colors [0:7],
  output reg [2:0] magic_count,
  output reg done
);

  enum logic [2:0] {
    IDLE,
    UPDATE_COLOR,
    QUERY_INIT,
    TRAVERSAL,
    CALC_MAGIC,
    DONE
  } state;

  reg [7:0] children [0:7];
  reg [1:0] current_colors [0:7];
  reg [7:0] visited;
  reg [3:0] color_count [0:3];
  reg [2:0] queue [0:7];
  reg [2:0] queue_head, queue_tail;
  reg [2:0] current_node;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      magic_count <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        children[i] <= 8'b0;
        current_colors[i] <= init_colors[i];
      end
      for (int j = 1; j <= 7; j = j + 1)
        children[parents[j]] <= children[parents[j]] | (8'b1 << j);
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            if (cmd_data == 2'b00) begin
              state <= QUERY_INIT;
            end else begin
              current_colors[node_id] <= cmd_data - 1;
              state <= UPDATE_COLOR;
            end
          end
        end
        
        UPDATE_COLOR: begin
          done <= 1;
          state <= DONE;
        end
        
        QUERY_INIT: begin
          visited <= 0;
          for (int i = 0; i < 4; i = i + 1)
            color_count[i] <= 0;
          queue[0] <= node_id;
          visited[node_id] <= 1'b1;
          queue_head <= 0;
          queue_tail <= 1;
          state <= TRAVERSAL;
        end
        
        TRAVERSAL: begin
          if (queue_head != queue_tail) begin
            current_node <= queue[queue_head];
            queue_head <= queue_head + 1;
            color_count[current_colors[current_node]] <= color_count[current_colors[current_node]] + 1;
            
            for (int i = 0; i < 8; i = i + 1) begin
              if ((children[current_node][i]) && (!visited[i])) begin
                queue[queue_tail] <= i;
                queue_tail <= queue_tail + 1;
                visited[i] <= 1'b1;
              end
            end
          end else begin
            state <= CALC_MAGIC;
          end
        end
        
        CALC_MAGIC: begin
          magic_count <= (color_count[0][0] ? 1 : 0) + (color_count[1][0] ? 1 : 0) + 
                         (color_count[2][0] ? 1 : 0) + (color_count[3][0] ? 1 : 0);
          state <= DONE;
        end
        
        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule