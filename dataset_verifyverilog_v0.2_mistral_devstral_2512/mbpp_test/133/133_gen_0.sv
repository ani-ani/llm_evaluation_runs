module sum_negative (
  input clk,
  input rst_n,
  input start,
  input [2:0] index,
  input [7:0] data_in,
  output reg [11:0] result,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [2:0] counter = 0;
  reg [11:0] sum = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      sum <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            counter <= 0;
            sum <= 0;
            result <= 0;
            done <= 0;
          end
        end
        PROCESSING: begin
          if (data_in[7]) begin
            sum <= sum + {{4{data_in[7]}}, data_in};
          end
          counter <= counter + 1;
          if (counter == 7) begin
            state <= DONE;
            result <= sum;
            done <= 1;
          end
        end
        DONE: begin
          state <= IDLE;
          done <= 0;
        end
      endcase
    end
  end

endmodule