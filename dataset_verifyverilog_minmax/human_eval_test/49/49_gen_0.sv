module modp_calculator(
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [15:0] p,
  output reg [15:0] result,
  output reg done
);

  parameter IDLE = 2'b00;
  parameter RUN  = 2'b01;
  parameter DONE = 2'b10;

  reg [1:0] state;
  reg [3:0] bit_index;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 16'h0;
      bit_index <= 4'b0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            result <= 16'h1;
            bit_index <= 4'b0;
            state <= RUN;
          end
        end
        RUN: begin
          if (n[15 - bit_index]) begin
            result <= ( (result * result) * 2 ) % p;
          end
          else begin
            result <= (result * result) % p;
          end

          if (bit_index == 4'b1111) begin
            state <= DONE;
            done <= 1'b1;
          end
          else begin
            bit_index <= bit_index + 1;
          end
        end
        DONE: begin
          done <= 1'b0;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule