module bell_number(input clk, input rst_n, input [3:0] n, input start, output reg [31:0] result, output reg done);
  
  // States
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    SET_ROW,
    COMPUTE_J,
    DONE
  } state_t;
  
  state_t current_state, next_state;
  
  // Bell triangle (0-8)
  reg [31:0] bell [0:8][0:8];
  reg [3:0] i, j;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 32'd0;
      for (int r = 0; r <= 8; r++) begin
        for (int c = 0; c <= 8; c++) begin
          bell[r][c] <= 32'd0;
        end
      end
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            next_state <= INIT;
          end else begin
            next_state <= IDLE;
          end
        end
        
        INIT: begin
          bell[0][0] <= 32'd1;
          if (n == 4'd0) begin
            result <= bell[0][0];
            next_state <= DONE;
          end else begin
            i <= 4'd1;
            next_state <= SET_ROW;
          end
        end
        
        SET_ROW: begin
          bell[i][0] <= bell[i-1][i-1];
          j <= 4'd1;
          next_state <= COMPUTE_J;
        end
        
        COMPUTE_J: begin
          bell[i][j] <= bell[i-1][j-1] + bell[i][j-1];
          if (j == i) begin
            if (i == n) begin
              result <= bell[i][0];
              next_state <= DONE;
            end else begin
              i <= i + 1;
              next_state <= SET_ROW;
            end
          end else begin
            j <= j + 1;
            next_state <= COMPUTE_J;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          if (start) begin
            next_state <= INIT;
          end else begin
            next_state <= DONE;
          end
        end
        
        default: next_state <= IDLE;
      endcase
    end
  end
endmodule