module gcd_calculator(input clk, input rst_n, input start, input [15:0] a, input [15:0] b, output reg [15:0] result, output reg done);
  typedef enum logic {IDLE, COMPUTE} state_t;
  state_t state;
  reg [15:0] a_reg, b_reg;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'd0;
      done <= 1'b1;
      a_reg <= 16'd0;
      b_reg <= 16'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            a_reg <= a;
            b_reg <= b;
            done <= 1'b0;
            state <= COMPUTE;
          end
        end
        COMPUTE: begin
          if (b_reg != 16'd0) begin
            if (b_reg > a_reg) begin
              a_reg <= b_reg;
              b_reg <= a_reg;
            end else begin
              a_reg <= a_reg - b_reg;
            end
          end else begin
            result <= a_reg;
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule