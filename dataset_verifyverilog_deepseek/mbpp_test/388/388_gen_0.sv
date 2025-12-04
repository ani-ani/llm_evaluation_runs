module highest_power_2(input clk, input rst_n, input start, input [5:0] n_in, output reg [5:0] result, output reg done);
  typedef enum {IDLE, CALCULATE} state_t;
  state_t state;
  reg [5:0] counter;
  wire power_of_two = (counter & (counter - 1)) == 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 6'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            counter <= n_in;
            state <= CALCULATE;
          end
        end
        CALCULATE: begin
          if (power_of_two || counter == 6'b1) begin
            result <= counter;
            done <= 1'b1;
            state <= IDLE;
          end else begin
            counter <= counter - 1;
          end
        end
      endcase
    end
  end
endmodule