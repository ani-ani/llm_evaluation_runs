module largest_divisor(input clk, input rst_n, input start, input [7:0] n, output reg [7:0] divisor, output reg done);
  typedef enum logic [1:0] {IDLE, CHECKING, DONE} state_t;
  reg [7:0] n_reg;
  reg [7:0] check_value;
  state_t state;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      divisor <= 8'b0;
      done <= 1'b0;
      n_reg <= 8'b0;
      check_value <= 8'b0;
    end
    else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          if (start) begin
            n_reg <= n;
            if (n < 8'd2) begin
              divisor <= 8'b0;
              state <= DONE;
            end
            else begin
              check_value <= n - 8'd1;
              state <= CHECKING;
            end
          end
        end
        
        CHECKING: begin
          if (n_reg % check_value == 0) begin
            divisor <= check_value;
            state <= DONE;
          end
          else begin
            check_value <= check_value - 8'd1;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule