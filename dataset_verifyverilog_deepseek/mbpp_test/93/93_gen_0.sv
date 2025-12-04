module power_calculator (
  input clk,
  input rst_n,
  input start,
  input [3:0] a,
  input [3:0] b,
  output reg [31:0] result,
  output reg done
);

  typedef enum logic [1:0] {IDLE, MULTIPLY, DONE_ST} state_t;
  state_t state;

  reg [3:0] a_reg;
  reg [3:0] b_reg;
  reg [3:0] counter;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 32'd1;
      done <= 1'b0;
      a_reg <= 4'b0;
      b_reg <= 4'b0;
      counter <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            a_reg <= a;
            b_reg <= b;
            if (b == 4'd0) begin
              result <= 32'd1;
              state <= DONE_ST;
            end else if (a == 4'd0) begin
              result <= 32'd0;
              state <= DONE_ST;
            end else begin
              result <= a;
              counter <= b - 1;
              state <= MULTIPLY;
            end
          end
        end

        MULTIPLY: begin
          if (counter == 4'd0) begin
            state <= DONE_ST;
          end else begin
            result <= result * a_reg;
            counter <= counter - 1;
          end
        end

        DONE_ST: begin
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule