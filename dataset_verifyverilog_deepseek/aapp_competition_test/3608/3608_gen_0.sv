module task_selector(
  input clk,
  input rst_n,
  input start,
  input [7:0][31:0] a,
  input [6:0][31:0] b,
  output reg [31:0] result,
  output reg done
);
  
  localparam M = 32'd1000000007;
  
  enum logic [1:0] { IDLE, PROCESSING, DONE } state;
  
  reg [2:0] index;
  reg [31:0] dp_prev1, dp_prev2;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      index <= 0;
      dp_prev1 <= 0;
      dp_prev2 <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESSING;
            dp_prev2 <= 32'd1;
            index <= 0;
          end
        end
        
        PROCESSING: begin
          if (index == 3'd0) begin
            dp_prev1 <= (a[0] * dp_prev2) % M;
            index <= 3'd1;
            if (3'd1 == 3'd7) state <= DONE;
          end else begin
            dp_prev2 <= dp_prev1;
            dp_prev1 <= (a[index] * dp_prev1 + b[index-1] * dp_prev2) % M;
            index <= index + 3'd1;
            if (index == 3'd7) state <= DONE;
          end
        end
        
        DONE: begin
          result <= dp_prev1;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule