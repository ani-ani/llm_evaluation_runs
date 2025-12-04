module resistance_calculator(
  input clk,
  input rst_n,
  input start,
  input [15:0] a,
  input [15:0] b,
  output reg [15:0] result,
  output reg done
);

  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] CALC = 2'b01;
  localparam [1:0] DONE = 2'b10;

  reg [15:0] x_reg, y_reg, count_reg;
  reg [1:0] state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      x_reg <= 0;
      y_reg <= 0;
      count_reg <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            x_reg <= a;
            y_reg <= b;
            count_reg <= 0;
            state <= CALC;
          end
        end
        CALC: begin
          done <= 0;
          if (y_reg == 0) begin
            result <= count_reg;
            done <= 1;
            state <= DONE;
          end else begin
            count_reg <= count_reg + (x_reg / y_reg);
            x_reg <= y_reg;
            y_reg <= x_reg % y_reg;
          end
        end
        DONE: begin
          if (start) begin
            x_reg <= a;
            y_reg <= b;
            count_reg <= 0;
            done <= 0;
            state <= CALC;
          end
        end
      endcase
    end
  end

endmodule